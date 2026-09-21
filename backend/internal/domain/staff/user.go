// Package staff holds the Usuario administrativo entity — the identity
// plane for admin/ (super_admin/client_admin/operator/auditor), separate
// from cardholder (the self-service portal's own identity plane, see
// internal/domain/cardholder). See docs/business/roles-and-permissions.md.
package staff

// Role mirrors admin/lib/core/models/role.dart.
type Role string

const (
	RoleSuperAdmin  Role = "super_admin"
	RoleClientAdmin Role = "client_admin"
	RoleOperator    Role = "operator"
	RoleAuditor     Role = "auditor"
)

// User — ClientID es nil únicamente para RoleSuperAdmin (alcance
// global) — ver admin/lib/core/models/session.dart.
type User struct {
	ID       string
	ClientID *string
	Email    string
	FullName string
	Role     Role
	IsActive bool
}
