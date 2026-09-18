package cardholder

// Cardholder aquí es deliberadamente mínimo — solo lo que el login del
// portal de autoservicio y la resolución de destino de una transferencia
// C2C necesitan (nombre para mostrar, a qué Cliente pertenece, si puede
// operar). El expediente KYC completo (CURP, RFC, domicilio...) sigue
// siendo responsabilidad exclusiva de admin/'s propio repositorio fake —
// nunca migra aquí. Ver
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md.
type Cardholder struct {
	ID       string
	ClientID string
	FullName string
	Email    string
	// Password en texto plano — solo-desarrollo, mismo criterio que el
	// resto del proyecto en esta etapa (ver login-administrativo). Nunca
	// hacer esto en un backend real.
	Password string
	IsActive bool
}
