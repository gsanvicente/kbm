-- name: InsertAuditLog :exec
-- Ver docs/adr/0015-audit-log-for-login-attempts.md. actor_user_id es
-- NULL solo para el caso "system" (no aplica todavía, ningún llamador lo
-- usa aún) — todo intento de login siempre tiene un usuario real
-- resuelto antes de loguearse (un email que no existe no genera fila,
-- ver el ADR).
INSERT INTO audit_log (actor_user_id, actor_type, action, entity_type, entity_id, metadata)
VALUES ($1, $2, $3, $4, $5, $6);
