package repository

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/staff"
)

// Staff login nunca formó parte del alcance original de este adaptador
// (docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md — el
// login administrativo era 100% de admin/'s FakeAuthRepository, sin
// backend). Se agrega aquí solo porque
// docs/adr/0013-jwt-session-authentication.md exige un token de staff
// verificado por el servidor para las acciones de Cards/Ledger que este
// adaptador sí implementa (asignar, bloquear...) — sin esto, el modo
// demo hubiera quedado inutilizable en cuanto esas rutas empezaran a
// exigir sesión. Mismos usuarios/contraseña que
// admin/lib/features/auth/fake_auth_repository.dart, por continuidad de
// demo — sin relación técnica real entre ambas listas.
var devStaffUsers = []staff.User{
	{ID: "10000000-0000-0000-0000-000000000001", Email: "super.admin@koons.test", Role: staff.RoleSuperAdmin, IsActive: true},
	{ID: "10000000-0000-0000-0000-000000000002", Email: "admin.holding@koons.test", Role: staff.RoleClientAdmin, ClientID: strPtr(clientA), IsActive: true},
	{ID: "10000000-0000-0000-0000-000000000003", Email: "admin.subA@koons.test", Role: staff.RoleClientAdmin, ClientID: strPtr(clientA), IsActive: true},
	{ID: "10000000-0000-0000-0000-000000000004", Email: "operador.subA@koons.test", Role: staff.RoleOperator, ClientID: strPtr(clientA), IsActive: true},
	{ID: "10000000-0000-0000-0000-000000000005", Email: "auditor.subA@koons.test", Role: staff.RoleAuditor, ClientID: strPtr(clientA), IsActive: true},
}

const devStaffPassword = "LocalDevOnly123!"

// StaffAuthStore implementa ports.StaffAuthRepository para el modo
// demo — tipo distinto de Store por la misma razón que
// internal/adapters/postgres/repository/staff_auth.go: Go no permite dos
// métodos Login en el mismo receptor
// (CardholderAuthRepository.Login ya existe en Store).
type StaffAuthStore struct {
	*Store
}

func NewStaffAuthStore(s *Store) *StaffAuthStore {
	return &StaffAuthStore{Store: s}
}

func (s *StaffAuthStore) Login(_ context.Context, email, password string) (staff.User, error) {
	for _, u := range devStaffUsers {
		if u.Email == email {
			if password != devStaffPassword || !u.IsActive {
				return staff.User{}, shared.ErrInvalidCredentials
			}
			return u, nil
		}
	}
	return staff.User{}, shared.ErrInvalidCredentials
}
