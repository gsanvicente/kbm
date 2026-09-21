package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// Login — mismo criterio que
// internal/adapters/memory/repository/store.go: un solo error genérico
// (ErrInvalidCredentials) tanto para email inexistente, contraseña
// incorrecta o Tarjetahabiente inactivo — ver
// docs/business/desactivacion-de-tarjetahabientes.md, "Enforcement",
// Capa 1. Las contraseñas se verifican con bcrypt (golang.org/x/crypto)
// contra el hash sembrado con pgcrypto's crypt(..., gen_salt('bf')) —
// mismo formato, ver scripts/init-db/001_seed.sql.
//
// GetCardholderForLogin hace JOIN contra cardholders, protegida por RLS
// (ver docs/adr/0014-row-level-security-policies.md) — a esta altura
// todavía no hay ninguna identidad de llamador que resolver (es
// justamente lo que este método determina), así que corre con RLS
// deliberadamente bypaseado (withRLSBypass). Esto nunca filtra una lista
// entre tenants: la query busca por email, columna única, cuando mucho
// una fila.
// Login — la escritura en audit_log de un intento fallido debe
// persistir aunque el login en sí termine en ErrInvalidCredentials, así
// que ese error se captura en [loginErr] y la función pasada a
// withRLSBypass siempre devuelve nil (commit) salvo por un error real de
// base de datos — devolver el error de negocio directamente desde ahí
// haría rollback también de la fila de auditoría que se acababa de
// insertar. Ver docs/adr/0015-audit-log-for-login-attempts.md.
func (s *Store) Login(ctx context.Context, email, password string) (cardholder.Cardholder, error) {
	var result cardholder.Cardholder
	var loginErr error
	err := s.withRLSBypass(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetCardholderForLogin(ctx, email)
		if errors.Is(err, pgx.ErrNoRows) {
			// Email desconocido — no hay una entidad real que auditar
			// todavía.
			loginErr = shared.ErrInvalidCredentials
			return nil
		}
		if err != nil {
			return err
		}

		if bcrypt.CompareHashAndPassword([]byte(row.PasswordHash), []byte(password)) != nil || !row.IsActive {
			reason := "invalid_password"
			if !row.IsActive {
				reason = "inactive"
			}
			if auditErr := logAudit(ctx, q, auditActorCardholder, row.ID, "login_failed", "cardholder", row.ID, map[string]any{"reason": reason}); auditErr != nil {
				return auditErr
			}
			loginErr = shared.ErrInvalidCredentials
			return nil
		}

		if err := logAudit(ctx, q, auditActorCardholder, row.ID, "login_success", "cardholder", row.ID, nil); err != nil {
			return err
		}

		// El límite de intentos fallidos de transferencia es por sesión,
		// nunca permanente — se reinicia en cada login exitoso, ver
		// docs/security/threat-model.md punto 12.
		s.attemptsMu.Lock()
		delete(s.failedAttempts, row.ID)
		s.attemptsMu.Unlock()

		result = mapper.ToCardholderFromLogin(row.ID, row.ClientID, row.FullName, email, row.IsActive)
		return nil
	})
	if err != nil {
		return cardholder.Cardholder{}, err
	}
	if loginErr != nil {
		return cardholder.Cardholder{}, loginErr
	}
	return result, nil
}
