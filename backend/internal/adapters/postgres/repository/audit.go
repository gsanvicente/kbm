// audit_log — ver
// docs/adr/0015-server-side-role-authorization-and-login-audit-log.md
// (intentos de login) y
// docs/adr/0016-business-action-audit-log-and-approval-race-fix.md
// (acciones de negocio). La tabla existe desde migrations/0001_init.sql
// pero, hasta el primero de esos dos incrementos, ningún código escribía
// en ella.
package repository

import (
	"context"
	"encoding/json"
	"fmt"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/application/ports"
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

// logCallerAudit es logAudit para las acciones de negocio normales
// (todo lo que no sea login, que corre antes de que exista ninguna
// identidad de llamador que resolver): toma el actor de
// ports.CallerFromContext en vez de recibirlo explícito. Cada método
// exportado de Store/ManagementStore que escribe algo la llama justo
// antes de retornar éxito, dentro de la misma transacción de la
// escritura que audita — mismo criterio "nunca en silencio" que
// logAudit ya documenta: si esto falla, la escritura de negocio entera
// hace rollback junto con ella.
func logCallerAudit(ctx context.Context, q *sqlcgen.Queries, action, entityType, entityID string, metadata map[string]any) error {
	identity, ok := ports.CallerFromContext(ctx)
	if !ok {
		// No debería pasar en un endpoint autenticado — fail loud en vez
		// de escribir una fila sin actor real al que atribuirla.
		return fmt.Errorf("logCallerAudit: no hay identidad de llamador en el contexto para la acción %q", action)
	}
	return logAudit(ctx, q, auditActorType(identity.Type), identity.UserID, action, entityType, entityID, metadata)
}
