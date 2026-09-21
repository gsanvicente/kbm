package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
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
// "Capa 1". `users` ganó RLS en
// docs/adr/0017-staff-user-management-and-rls-on-users.md — igual que
// auth.go's Login, corre bajo withRLSBypass porque a esta altura
// todavía no hay ninguna identidad de llamador que resolver (es
// justamente lo que este método determina). El error de negocio se
// captura en [loginErr] (no se retorna directo desde el closure) para
// que la fila de audit_log de un intento fallido siga haciendo commit —
// ver el mismo patrón en auth.go.
func (s *StaffAuthStore) Login(ctx context.Context, email, password string) (staff.User, error) {
	var result staff.User
	var loginErr error
	err := s.withRLSBypass(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetStaffUserForLogin(ctx, email)
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
			if auditErr := logAudit(ctx, q, auditActorStaff, row.ID, "login_failed", "user", row.ID, map[string]any{"reason": reason}); auditErr != nil {
				return auditErr
			}
			loginErr = shared.ErrInvalidCredentials
			return nil
		}

		// Super Admin no tiene ClientID (alcance global) — nunca se ve
		// afectado por el estado de ningún Cliente en particular.
		if row.ClientID != nil {
			operable, err := s.IsOperable(ctx, *row.ClientID)
			if err != nil {
				return err
			}
			if !operable {
				if auditErr := logAudit(ctx, q, auditActorStaff, row.ID, "login_failed", "user", row.ID, map[string]any{"reason": "client_inactive"}); auditErr != nil {
					return auditErr
				}
				loginErr = shared.ErrInvalidCredentials
				return nil
			}
		}

		if err := logAudit(ctx, q, auditActorStaff, row.ID, "login_success", "user", row.ID, nil); err != nil {
			return err
		}

		result = mapper.ToStaffUser(mapper.StaffUserRow{
			ID: row.ID, ClientID: row.ClientID, Email: row.Email, FullName: row.FullName, Role: row.Role, IsActive: row.IsActive,
		})
		return nil
	})
	if err != nil {
		return staff.User{}, err
	}
	if loginErr != nil {
		return staff.User{}, loginErr
	}
	return result, nil
}
