package handler

import "github.com/koons/kbm/backend/internal/domain/staff"

// Los dos conjuntos de rol de docs/business/roles-and-permissions.md,
// espejo exacto de los getters de admin/lib/core/models/role.dart
// (canManageCardholders/canManageClients/canResolveClaims/
// canApproveBalanceOperations/canReconcileDeposits/
// canViewExecutiveDashboard usan manageRoles; canOperateCards/
// canFileClaims/canRequestBalanceOperations/canRegisterCollectorDeposits
// usan operateRoles). Hasta este incremento, el backend solo verificaba
// "es staff" (middleware.RequireStaff) — cualquier rol podía golpear
// cualquier endpoint de staff directamente por HTTP, sin pasar por
// admin/; la UI era la única barrera. RequireRole en Routes() cierra
// ese hueco.
var (
	// manageRoles — Super Admin y Admin Cliente únicamente. Gestión de
	// Clientes/Tarjetahabientes/Tarjetas (asignar), resolución de
	// reclamos y de operaciones de saldo, conciliación de depósitos:
	// siempre separado de quien opera el día a día.
	manageRoles = []staff.Role{staff.RoleSuperAdmin, staff.RoleClientAdmin}

	// operateRoles — todos salvo Auditor. Operación del día a día:
	// bloquear/desbloquear tarjetas, solicitar operaciones de saldo y
	// depósitos, presentar reclamos.
	operateRoles = []staff.Role{staff.RoleSuperAdmin, staff.RoleClientAdmin, staff.RoleOperator}
)

// staffRoleAllowed — para el puñado de endpoints de alcance mixto
// (staff y Tarjetahabiente) que además necesitan restringir el rol de
// staff exacto, ver fileClaim en handler_management.go: al salir del
// grupo de rutas con RequireRole (que exige exclusivamente staff), el
// chequeo de rol para el lado staff se repite aquí a mano.
func staffRoleAllowed(role string, allowed []staff.Role) bool {
	for _, r := range allowed {
		if role == string(r) {
			return true
		}
	}
	return false
}
