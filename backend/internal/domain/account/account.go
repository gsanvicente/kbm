// Package account holds la Cuenta Individual del Tarjetahabiente — ver
// docs/adr/0020-cuenta-individual-tarjetahabiente.md. El saldo (ledger)
// vive aquí, no en card.Card: una tarjeta es un instrumento de gasto
// desechable sobre una Cuenta, la Cuenta es la relación económica
// duradera con el Tarjetahabiente.
package account

// Account — nace al dar de alta al Tarjetahabiente
// (ports.CardholderManagementRepository.Create), no al asignarle una
// tarjeta. CLABE es nil hasta que se conecte un proveedor SPEI real, ver
// docs/adr/0021-conector-spei.md.
type Account struct {
	ID           string
	ClientID     string
	CardholderID string
	CLABE        *string
}
