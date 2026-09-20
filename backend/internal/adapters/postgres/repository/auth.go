package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
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
func (s *Store) Login(ctx context.Context, email, password string) (cardholder.Cardholder, error) {
	row, err := s.q.GetCardholderForLogin(ctx, email)
	if errors.Is(err, pgx.ErrNoRows) {
		return cardholder.Cardholder{}, shared.ErrInvalidCredentials
	}
	if err != nil {
		return cardholder.Cardholder{}, err
	}

	if bcrypt.CompareHashAndPassword([]byte(row.PasswordHash), []byte(password)) != nil || !row.IsActive {
		return cardholder.Cardholder{}, shared.ErrInvalidCredentials
	}

	// El límite de intentos fallidos de transferencia es por sesión,
	// nunca permanente — se reinicia en cada login exitoso, ver
	// docs/security/threat-model.md punto 12.
	s.attemptsMu.Lock()
	delete(s.failedAttempts, row.ID)
	s.attemptsMu.Unlock()

	// cardholder.Cardholder.Password documenta "texto plano, solo
	// desarrollo" (ver internal/domain/cardholder/cardholder.go) — aquí
	// nunca se llena con el hash bcrypt, ya verificado arriba y no usado
	// por ningún llamador después del login (confirmado: no se serializa
	// en ninguna respuesta HTTP).
	return mapper.ToCardholder(row.ID, row.ClientID, row.FullName, row.Email, row.IsActive, ""), nil
}
