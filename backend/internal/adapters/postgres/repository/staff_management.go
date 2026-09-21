package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/staff"
)

// StaffManagementStore implementa ports.StaffManagementRepository — tipo
// distinto de Store/StaffAuthStore por la misma razón que ManagementStore:
// evitar ambigüedad de métodos en el mismo receptor. Envuelve el mismo
// *pgxpool.Pool. Ver docs/adr/0017-staff-user-management-and-rls-on-users.md.
type StaffManagementStore struct {
	*Store
}

func NewStaffManagementStore(s *Store) *StaffManagementStore {
	return &StaffManagementStore{Store: s}
}

// isUniqueViolation — users.email es citext UNIQUE; un alta con un email
// ya existente falla con este código de Postgres.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func (s *StaffManagementStore) ListByClient(ctx context.Context, clientID string) ([]staff.User, error) {
	var out []staff.User
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListStaffUsersByClient(ctx, &clientID)
		if err != nil {
			return err
		}
		out = make([]staff.User, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToStaffUser(mapper.StaffUserRow(r)))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *StaffManagementStore) GetByID(ctx context.Context, userID string) (*staff.User, error) {
	var result *staff.User
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetStaffUserByID(ctx, userID)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		u := mapper.ToStaffUser(mapper.StaffUserRow(row))
		result = &u
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// Create — nunca acepta staff.RoleSuperAdmin (ver
// docs/business/gestion-de-usuarios-staff.md, "Quién puede crear a
// quién"); esa validación ya ocurre también en el handler HTTP
// (defensa en profundidad, mismo criterio que el resto del proyecto),
// pero se repite aquí porque este repositorio es el único que sabe
// hashear la contraseña y no debería confiar ciegamente en el llamador.
func (s *StaffManagementStore) Create(ctx context.Context, draft staff.User, password string) (staff.User, error) {
	if draft.Role == staff.RoleSuperAdmin {
		return staff.User{}, shared.ErrValidation
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return staff.User{}, err
	}
	var result staff.User
	err = s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.CreateStaffUser(ctx, sqlcgen.CreateStaffUserParams{
			ClientID:     draft.ClientID,
			Email:        draft.Email,
			FullName:     draft.FullName,
			PasswordHash: string(hash),
			Role:         sqlcgen.UserRole(draft.Role),
		})
		if isUniqueViolation(err) {
			return shared.ErrEmailAlreadyExists
		}
		if err != nil {
			return err
		}
		result = mapper.ToStaffUser(mapper.StaffUserRow(row))
		return logCallerAudit(ctx, q, "staff_user_created", "user", row.ID, map[string]any{
			"email": draft.Email, "role": draft.Role, "client_id": draft.ClientID,
		})
	})
	if err != nil {
		return staff.User{}, err
	}
	return result, nil
}

func (s *StaffManagementStore) Update(ctx context.Context, updated staff.User) (staff.User, error) {
	if updated.Role == staff.RoleSuperAdmin {
		return staff.User{}, shared.ErrValidation
	}
	var result staff.User
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.UpdateStaffUser(ctx, sqlcgen.UpdateStaffUserParams{
			ID:       updated.ID,
			FullName: updated.FullName,
			Role:     sqlcgen.UserRole(updated.Role),
		})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		result = mapper.ToStaffUser(mapper.StaffUserRow(row))
		return logCallerAudit(ctx, q, "staff_user_updated", "user", updated.ID, map[string]any{"role": updated.Role})
	})
	if err != nil {
		return staff.User{}, err
	}
	return result, nil
}

func (s *StaffManagementStore) SetActive(ctx context.Context, userID string, active bool) (staff.User, error) {
	var result staff.User
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.SetStaffUserActive(ctx, sqlcgen.SetStaffUserActiveParams{ID: userID, IsActive: active})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		result = mapper.ToStaffUser(mapper.StaffUserRow(row))
		action := "staff_user_deactivated"
		if active {
			action = "staff_user_reactivated"
		}
		return logCallerAudit(ctx, q, action, "user", userID, nil)
	})
	if err != nil {
		return staff.User{}, err
	}
	return result, nil
}

func (s *StaffManagementStore) ResetPassword(ctx context.Context, userID, newPassword string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		if err := q.ResetStaffUserPassword(ctx, sqlcgen.ResetStaffUserPasswordParams{ID: userID, PasswordHash: string(hash)}); err != nil {
			return err
		}
		return logCallerAudit(ctx, q, "staff_user_password_reset", "user", userID, nil)
	})
}
