package ports

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/staff"
)

// StaffManagementRepository — alta, edición, activar/desactivar y
// restablecer contraseña de un usuario de staff (admin/), distinto de
// StaffAuthRepository (solo login). Ver
// docs/feature/gestion-de-usuarios-staff/README.md.
type StaffManagementRepository interface {
	// ListByClient — nunca incluye Super Admin (ClientID nil), ver
	// docs/business/gestion-de-usuarios-staff.md.
	ListByClient(ctx context.Context, clientID string) ([]staff.User, error)

	GetByID(ctx context.Context, userID string) (*staff.User, error)

	// Create ignora draft.ID/draft.IsActive (nace activo) — nunca acepta
	// staff.RoleSuperAdmin como draft.Role, ver "Quién puede crear a
	// quién" en docs/business/gestion-de-usuarios-staff.md. [password] en
	// texto plano, se hashea antes de persistir. Devuelve
	// shared.ErrEmailAlreadyExists si el email ya está en uso.
	Create(ctx context.Context, draft staff.User, password string) (staff.User, error)

	// Update solo cambia FullName y Role — Email y ClientID quedan fijos
	// desde la creación. Nunca acepta staff.RoleSuperAdmin.
	Update(ctx context.Context, updated staff.User) (staff.User, error)

	SetActive(ctx context.Context, userID string, active bool) (staff.User, error)

	// ResetPassword — [newPassword] en texto plano, se hashea antes de
	// persistir. No cambia ningún otro campo.
	ResetPassword(ctx context.Context, userID, newPassword string) error
}
