// audit_log — ver docs/adr/0015-audit-log-for-login-attempts.md. La
// tabla existe desde migrations/0001_init.sql pero, hasta este
// incremento, ningún código escribía en ella a pesar de que
// docs/feature/login-administrativo/README.md ya prometía "todo intento
// (éxito o fallo) queda registrado en audit_log".
package repository

import (
	"context"
	"encoding/json"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
)

type auditActorType string

const (
	auditActorStaff      auditActorType = "staff"
	auditActorCardholder auditActorType = "cardholder"
)

// logAudit escribe una fila de audit_log — nunca falla en silencio:
// el error se propaga al llamador, que en los dos logins (ver auth.go,
// staff_auth.go) lo trata como un fallo del login mismo. La alternativa
// (best-effort, ignorar el error) se descartó a propósito — un fallo
// silencioso de auditoría en un sistema con estas obligaciones de
// cumplimiento sería peor que bloquear el login, ver
// docs/security/compliance-notes.md.
func logAudit(ctx context.Context, q *sqlcgen.Queries, actorType auditActorType, actorUserID, action, entityType, entityID string, metadata map[string]any) error {
	var metaBytes []byte
	if metadata != nil {
		b, err := json.Marshal(metadata)
		if err != nil {
			return err
		}
		metaBytes = b
	}
	return q.InsertAuditLog(ctx, sqlcgen.InsertAuditLogParams{
		ActorUserID: &actorUserID,
		ActorType:   string(actorType),
		Action:      action,
		EntityType:  entityType,
		EntityID:    entityID,
		Metadata:    metaBytes,
	})
}
