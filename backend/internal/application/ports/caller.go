package ports

import "context"

type callerCtxKey struct{}

// CallerIdentity — la identidad ya verificada de quien hizo el request
// HTTP, fijada una sola vez por el middleware de
// internal/adapters/http/handler.Routes() justo después de RequireAuth
// (nunca por un caso de uso o repositorio). El adaptador Postgres la usa
// para dos cosas distintas: ClientID alimenta
// app.accessible_client_ids para Row-Level Security (ver
// docs/adr/0014-row-level-security-policies.md), y UserID/Type atribuyen
// cada escritura de negocio a un actor real en audit_log (ver
// docs/adr/0015-server-side-role-authorization-and-login-audit-log.md).
type CallerIdentity struct {
	// ClientID — nil para alcance global (Super Admin). Nunca se usa
	// para atribuir auditoría, solo para RLS.
	ClientID *string
	// UserID — el id de staff.User o cardholder.Cardholder que hizo la
	// petición (el `sub` del JWT).
	UserID string
	// Type — "staff" o "cardholder", mismos valores que
	// local.SubjectStaff/local.SubjectCardholder.
	Type string
}

// WithCaller guarda la identidad del llamador en el contexto. Un struct
// completo (no un *string suelto) evita a propósito el error clásico de
// Go de no poder distinguir "nunca se fijó" de "se fijó con un campo en
// nil" cuando el valor guardado en el contexto es un puntero crudo.
func WithCaller(ctx context.Context, identity CallerIdentity) context.Context {
	return context.WithValue(ctx, callerCtxKey{}, identity)
}

// CallerFromContext devuelve (identity, true) si el middleware ya fijó
// una identidad para este contexto, o (_, false) si no — el caso de los
// dos endpoints de login, que corren antes de que exista ninguna
// identidad que resolver. El adaptador Postgres trata "no fijada" como
// el alcance más restrictivo posible para RLS (nunca como
// irrestricto) — ver internal/adapters/postgres/repository/rls.go — y
// como un error real (fail loud) si algo intenta escribir en audit_log
// sin una identidad de la que colgar la fila — ver
// internal/adapters/postgres/repository/audit.go.
func CallerFromContext(ctx context.Context) (CallerIdentity, bool) {
	v, ok := ctx.Value(callerCtxKey{}).(CallerIdentity)
	return v, ok
}
