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
func (s *Store) Login(ctx context.Context, email, password string) (cardholder.Cardholder, error) {
	var result cardholder.Cardholder
	err := s.withRLSBypass(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetCardholderForLogin(ctx, email)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrInvalidCredentials
		}
		if err != nil {
			return err
		}

		if bcrypt.CompareHashAndPassword([]byte(row.PasswordHash), []byte(password)) != nil || !row.IsActive {
			return shared.ErrInvalidCredentials
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
	return result, nil
}
