package ports

import "context"

type callerClientIDKey struct{}

// callerScope wraps the resolved client_id so a caller with global scope
// (a nil client_id, e.g. Super Admin) is distinguishable in the context
// from "never set" — a bare *string would make both cases look like a
// nil interface value.
type callerScope struct {
	clientID *string
}

// WithCallerClientID stores the authenticated caller's own client_id —
// nil for a caller with unrestricted/global scope (Super Admin) — so the
// Postgres adapter can compute app.accessible_client_ids for Row-Level
// Security. Set once by the HTTP layer right after RequireAuth verifies
// the token (see internal/adapters/http/handler.Routes), never by a use
// case or repository itself. See
// docs/adr/0014-row-level-security-policies.md.
func WithCallerClientID(ctx context.Context, clientID *string) context.Context {
	return context.WithValue(ctx, callerClientIDKey{}, callerScope{clientID: clientID})
}

// CallerClientIDFromContext returns (nil, true) for a caller with global
// scope, (ptr, true) for one scoped to a single client, or (nil, false)
// if no caller scope was ever established for this context — e.g. the
// two login endpoints, which run before any identity is known. The
// Postgres adapter treats the "not set" case as the most restrictive
// scope (matches nothing), never as unrestricted — see
// internal/adapters/postgres/repository/rls.go.
func CallerClientIDFromContext(ctx context.Context) (*string, bool) {
	v, ok := ctx.Value(callerClientIDKey{}).(callerScope)
	if !ok {
		return nil, false
	}
	return v.clientID, true
}
