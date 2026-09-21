// Row-Level Security wiring — see
// docs/adr/0014-row-level-security-policies.md. The app connects as
// kbm_app, a non-owner Postgres role (see migrations/0005_row_level_security_policies.sql)
// subject to the RLS policies defined there; a superuser or table owner
// would silently bypass every policy regardless of what this file does.
//
// Every Store/ManagementStore/StaffAuthStore method that touches an
// RLS-protected table must run its queries through withRLS (or beginRLS,
// for methods that already need their own transaction for other
// reasons) instead of calling s.q directly — a method that forgets this
// still works today (Postgres allows the query), it just silently
// returns zero rows once RLS is enforced, since app.accessible_client_ids
// would be unset for that connection.
package repository

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/application/ports"
)

// rlsGUCAll is the sentinel that the RLS policies treat as "every
// client" — used for Super Admin / globally-scoped staff, and for the
// handful of pre-authentication queries (login) that must find a row
// before any caller scope exists.
const rlsGUCAll = "*"

// resolveAccessibleClientIDs computes the value for the
// app.accessible_client_ids GUC from the caller identity already
// resolved by the HTTP layer (see ports.WithCaller): the caller's own
// client_id plus every descendant in client_hierarchy (staff inherit
// scope over their subsidiaries — see
// docs/business/roles-and-permissions.md, "Herencia sobre la jerarquía
// padre/hija"). client_hierarchy itself carries no RLS, so this query
// runs unscoped, on the shared pool, before any transaction opens.
func (s *Store) resolveAccessibleClientIDs(ctx context.Context) (string, error) {
	identity, ok := ports.CallerFromContext(ctx)
	if !ok {
		// Fail closed: a code path that forgot to establish caller scope
		// (or a context that legitimately never goes through auth, like
		// login) gets zero visibility, never unrestricted.
		return "", nil
	}
	if identity.ClientID == nil {
		return rlsGUCAll, nil
	}
	rows, err := s.pool.Query(ctx, `SELECT descendant_id FROM client_hierarchy WHERE ancestor_id = $1`, *identity.ClientID)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return "", err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return "", err
	}
	return strings.Join(ids, ","), nil
}

// beginRLS opens a transaction with app.accessible_client_ids already
// set (via SET LOCAL — transaction-scoped, so it can never leak to
// whichever unrelated request next borrows this pooled connection).
// Callers that need their own transaction for other reasons (e.g. a
// multi-statement write) should call this instead of s.pool.Begin
// directly; everyone else should prefer withRLS below.
func (s *Store) beginRLS(ctx context.Context) (pgx.Tx, error) {
	guc, err := s.resolveAccessibleClientIDs(ctx)
	if err != nil {
		return nil, err
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `SELECT set_config('app.accessible_client_ids', $1, true)`, guc); err != nil {
		tx.Rollback(ctx)
		return nil, err
	}
	return tx, nil
}

// beginRLSBypass is the same as beginRLS but always sets '*' — reserved
// for the pre-authentication login lookups, which must find a row by
// unique email/username before any caller scope exists (see auth.go,
// staff_auth.go). Bypassing here never leaks a list of cross-tenant
// data: both queries are keyed by a globally-unique column and return at
// most one row.
func (s *Store) beginRLSBypass(ctx context.Context) (pgx.Tx, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `SELECT set_config('app.accessible_client_ids', $1, true)`, rlsGUCAll); err != nil {
		tx.Rollback(ctx)
		return nil, err
	}
	return tx, nil
}

// withRLS runs fn against a transaction scoped to the calling identity's
// accessible clients, committing on success and rolling back on any
// error (including one returned by fn itself).
func (s *Store) withRLS(ctx context.Context, fn func(q *sqlcgen.Queries) error) error {
	tx, err := s.beginRLS(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// withRLSBypass is withRLS's counterpart for the login-time exceptions —
// see beginRLSBypass.
func (s *Store) withRLSBypass(ctx context.Context, fn func(q *sqlcgen.Queries) error) error {
	tx, err := s.beginRLSBypass(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
