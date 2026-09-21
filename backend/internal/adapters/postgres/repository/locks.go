// Advisory locks — ver
// docs/adr/0016-business-action-audit-log-and-approval-race-fix.md.
package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
)

// withAdvisoryLock serializa cualquier código que corra bajo la misma
// [key] entre TODAS las conexiones del pool (a diferencia de un lock de
// fila dentro de una sola transacción, un advisory lock de Postgres es
// visible server-wide) — necesario para Approve/Reject en approval.go,
// que ya componen varias transacciones cortas separadas (una por cada
// paso del ledger vía tryExecute), no una sola que pudiera sostener un
// FOR UPDATE de principio a fin.
//
// Usa una conexión propia, fuera del pool compartido (pgx.ConnectConfig,
// no s.pool.Acquire) — a propósito: [fn] llama a métodos como tryExecute
// que a su vez abren transacciones nuevas contra el pool (withRLS). Con
// una conexión sacada DEL MISMO pool sostenida durante todo [fn], un
// pool con capacidad limitada bajo concurrencia real se autobloquea: N
// llamadas concurrentes agotan el pool esperando el advisory lock,
// mientras la única que sí lo tiene no consigue una conexión adicional
// para las transacciones que [fn] necesita — un deadlock real,
// encontrado en vivo al probar 10 Approve() concurrentes sobre la misma
// operación antes de cerrar este incremento.
func (s *Store) withAdvisoryLock(ctx context.Context, key string, fn func() error) error {
	conn, err := pgx.ConnectConfig(ctx, s.pool.Config().ConnConfig)
	if err != nil {
		return err
	}
	defer conn.Close(context.WithoutCancel(ctx))

	var lockKey int64
	if err := conn.QueryRow(ctx, `SELECT hashtextextended($1, 0)`, key).Scan(&lockKey); err != nil {
		return err
	}
	if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock($1)`, lockKey); err != nil {
		return err
	}
	defer conn.Exec(context.WithoutCancel(ctx), `SELECT pg_advisory_unlock($1)`, lockKey)

	return fn()
}
