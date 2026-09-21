package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/staff"
)

// StaffAuthStore implementa ports.StaffAuthRepository — tipo distinto de
// Store porque CardholderAuthRepository ya define su propio Login en el
// mismo paquete; Go no permite dos métodos Login en el mismo receptor.
// Envuelve el mismo *pgxpool.Pool, igual que ManagementStore.
type StaffAuthStore struct {
	*Store
}

func NewStaffAuthStore(s *Store) *StaffAuthStore {
	return &StaffAuthStore{Store: s}
}

// Login — mismo criterio de mensaje genérico que
// CardholderAuthRepository: credenciales incorrectas, usuario inactivo, o
// el Cliente del usuario (o alguno de sus ancestros) inactivo, todo
// responde igual — ver docs/business/desactivacion-de-clientes.md,
// "Capa 1". GetStaffUserForLogin solo toca `users`, sin RLS. IsOperable
// ya bypasea RLS por su cuenta (ver client.go) — necesario aquí también,
// no solo por ser pre-autenticación. audit_log tampoco tiene RLS, así
// que sus escrituras (ver docs/adr/0015-audit-log-for-login-attempts.md)
// corren directo contra s.q, sin necesidad de ningún wrapper.
func (s *StaffAuthStore) Login(ctx context.Context, email, password string) (staff.User, error) {
	row, err := s.q.GetStaffUserForLogin(ctx, email)
	if errors.Is(err, pgx.ErrNoRows) {
		// Email desconocido — no hay una entidad real que auditar todavía.
		return staff.User{}, shared.ErrInvalidCredentials
	}
	if err != nil {
		return staff.User{}, err
	}
	if bcrypt.CompareHashAndPassword([]byte(row.PasswordHash), []byte(password)) != nil || !row.IsActive {
		reason := "invalid_password"
		if !row.IsActive {
			reason = "inactive"
		}
		if auditErr := logAudit(ctx, s.q, auditActorStaff, row.ID, "login_failed", "user", row.ID, map[string]any{"reason": reason}); auditErr != nil {
			return staff.User{}, auditErr
		}
		return staff.User{}, shared.ErrInvalidCredentials
	}

	// Super Admin no tiene ClientID (alcance global) — nunca se ve
	// afectado por el estado de ningún Cliente en particular.
	if row.ClientID != nil {
		operable, err := s.IsOperable(ctx, *row.ClientID)
		if err != nil {
			return staff.User{}, err
		}
		if !operable {
			if auditErr := logAudit(ctx, s.q, auditActorStaff, row.ID, "login_failed", "user", row.ID, map[string]any{"reason": "client_inactive"}); auditErr != nil {
				return staff.User{}, auditErr
			}
			return staff.User{}, shared.ErrInvalidCredentials
		}
	}

	if err := logAudit(ctx, s.q, auditActorStaff, row.ID, "login_success", "user", row.ID, nil); err != nil {
		return staff.User{}, err
	}

	return mapper.ToStaffUser(row.ID, row.ClientID, row.Email, row.Role, row.IsActive), nil
}
