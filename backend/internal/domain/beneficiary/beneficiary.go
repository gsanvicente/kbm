// Package beneficiary holds el Beneficiario de Pago — a quién un
// Tarjetahabiente le puede enviar un pago SPEI. Ver
// docs/adr/0021-conector-spei.md. Nombre deliberadamente distinto de
// domain/client.BeneficiarioControlador (KYB de un Cliente, dueño
// mayoritario) — son conceptos de persona completamente distintos.
package beneficiary

import "time"

// CoolingPeriodMaxAmount — mientras un Beneficiario está en su periodo
// de enfriamiento (ver Beneficiary.IsCooling), ningún pago individual
// puede superar este monto. Mitiga que una cuenta comprometida vacíe el
// saldo al instante de agregar un destino nuevo (ADR-0021, "Seguridad").
// Valor ilustrativo de esta iteración, ajustable sin migración.
const CoolingPeriodMaxAmount = 1000.00

// Beneficiary — nace con CoolingUntil en el futuro (ver la migración que
// crea payment_beneficiaries); nunca se relee ni se resetea, ni siquiera
// si se edita el alias.
type Beneficiary struct {
	ID           string
	ClientID     string
	CardholderID string
	Alias        string
	CLABE        string
	BankName     string
	CoolingUntil time.Time
	CreatedAt    time.Time
}

// IsCooling — true mientras el Beneficiario sigue en su periodo de
// enfriamiento (ver CoolingPeriodMaxAmount).
func (b Beneficiary) IsCooling() bool {
	return time.Now().Before(b.CoolingUntil)
}

// DirectoryEntry — una fila del directorio agregado de Beneficiarios de
// Pago para staff, ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. A
// diferencia de Beneficiary (pensado para "mis propios beneficiarios",
// donde el dueño es implícito), esto trae explícitos a quién le
// pertenece, su actividad real, y la señal de posible cuenta mula.
type DirectoryEntry struct {
	Beneficiary
	ClientID           string
	CardholderID       string
	CardholderFullName string

	// PaymentCount/TotalAmountPaid — solo pagos `executed`, nunca
	// intentos pending/rejected/failed: dinero que de verdad salió.
	PaymentCount    int64
	TotalAmountPaid float64

	// SharedByMultipleCardholders — true si esta misma CLABE está
	// registrada por más de un Tarjetahabiente, calculado GLOBALMENTE
	// (sin respetar el alcance de quien consulta) — ver
	// docs/security/threat-model.md punto 18. Nunca expone quién más la
	// registró, solo el hecho booleano.
	SharedByMultipleCardholders bool
}
