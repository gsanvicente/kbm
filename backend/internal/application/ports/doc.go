// Package ports declares the interfaces that connect application use cases
// to the outside world, without depending on any concrete technology.
// Each interface is added when the first use case that needs it is written,
// implemented in internal/adapters/<tech>. Planned ports:
//
//   - ClientRepository, CardholderRepository, CardRepository, LedgerRepository,
//     BalanceOperationRepository, ApprovalRuleRepository, AuditLogRepository
//     (implemented by internal/adapters/postgres)
//   - AuthorizationPort: given an authenticated identity, a target client
//     (tenant) and an action, decides whether it is allowed. Invoked by every
//     use case, not just HTTP handlers, so access control can't be bypassed
//     by adding a new endpoint that forgets the check. Still not built as a
//     port — there is no use-case layer yet for it to sit in front of (see
//     handler.go's package comment). middleware.RequireRole (see
//     docs/adr/0015-server-side-role-authorization-and-login-audit-log.md)
//     covers the same ground today, enforced in Routes() instead.
//   - CardProcessorGateway (internal/adapters/processor)
//   - QueuePort (internal/adapters/queue/local or /sqs)
//   - IdentityProvider (internal/adapters/auth/local or /cognito) — the
//     local half now exists for real, see
//     docs/adr/0013-jwt-session-authentication.md; cognito is still a stub.
//   - NotificationPort
package ports
