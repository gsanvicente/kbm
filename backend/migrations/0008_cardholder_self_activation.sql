-- Email pasa a ser obligatorio y único: es el identificador con el que el
-- Tarjetahabiente activa su cuenta y luego inicia sesión — ver
-- docs/adr/0019-cardholder-self-activation.md. Los Tarjetahabientes de
-- seed ya tienen email, no requiere backfill.
ALTER TABLE cardholders ALTER COLUMN email SET NOT NULL;
ALTER TABLE cardholders ADD CONSTRAINT cardholders_email_key UNIQUE (email);

-- Contador de intentos fallidos de activación — bloqueo permanente tras
-- 5, levantable solo por staff (ResetActivationAttempts). Distinto del
-- límite de intentos de la transferencia C2C (por sesión, en memoria del
-- proceso, nunca persistido).
ALTER TABLE cardholders ADD COLUMN activation_failed_attempts int NOT NULL DEFAULT 0;
