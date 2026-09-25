package dto

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/beneficiary"
	"github.com/koons/kbm/backend/internal/domain/speipayment"
)

// CLABEResponse — nil mientras la Cuenta Individual todavía no tiene una
// CLABE asignada, ver docs/adr/0021-conector-spei.md.
type CLABEResponse struct {
	CLABE *string `json:"clabe"`
}

// Beneficiary — ver backend/internal/domain/beneficiary.Beneficiary.
// IsCooling es un campo calculado (nunca se persiste), útil para que
// cardholder/ muestre el aviso de periodo de enfriamiento sin tener que
// recalcular la fecha en Dart.
type Beneficiary struct {
	ID           string    `json:"id"`
	Alias        string    `json:"alias"`
	CLABE        string    `json:"clabe"`
	BankName     string    `json:"bankName"`
	CoolingUntil time.Time `json:"coolingUntil"`
	IsCooling    bool      `json:"isCooling"`
	CreatedAt    time.Time `json:"createdAt"`
}

func FromBeneficiary(b beneficiary.Beneficiary) Beneficiary {
	return Beneficiary{
		ID:           b.ID,
		Alias:        b.Alias,
		CLABE:        b.CLABE,
		BankName:     b.BankName,
		CoolingUntil: b.CoolingUntil,
		IsCooling:    b.IsCooling(),
		CreatedAt:    b.CreatedAt,
	}
}

type RegisterBeneficiaryRequest struct {
	Alias string `json:"alias"`
	CLABE string `json:"clabe"`
}

// SPEIPayment — BeneficiaryAlias/BeneficiaryCLABE/RequestedByFullName
// solo vienen poblados en los listados (ver
// speipayment.Payment) — vacíos en la respuesta de crear/aprobar/rechazar.
type SPEIPayment struct {
	ID                  string    `json:"id"`
	ClientID            string    `json:"clientId"`
	AccountID           string    `json:"accountId"`
	BeneficiaryID       string    `json:"beneficiaryId"`
	Amount              float64   `json:"amount"`
	Status              string    `json:"status"`
	ResolvedByEmail     *string   `json:"resolvedByEmail"`
	ResolutionNotes     *string   `json:"resolutionNotes"`
	ProviderReference   *string   `json:"providerReference"`
	BeneficiaryAlias    string    `json:"beneficiaryAlias,omitempty"`
	BeneficiaryCLABE    string    `json:"beneficiaryClabe,omitempty"`
	RequestedByFullName string    `json:"requestedByFullName,omitempty"`
	CreatedAt           time.Time `json:"createdAt"`
	UpdatedAt           time.Time `json:"updatedAt"`
}

func FromSPEIPayment(p speipayment.Payment) SPEIPayment {
	return SPEIPayment{
		ID:                  p.ID,
		ClientID:            p.ClientID,
		AccountID:           p.AccountID,
		BeneficiaryID:       p.BeneficiaryID,
		Amount:              p.Amount,
		Status:              string(p.Status),
		ResolvedByEmail:     p.ResolvedByEmail,
		ResolutionNotes:     p.ResolutionNotes,
		ProviderReference:   p.ProviderReference,
		BeneficiaryAlias:    p.BeneficiaryAlias,
		BeneficiaryCLABE:    p.BeneficiaryCLABE,
		RequestedByFullName: p.RequestedByFullName,
		CreatedAt:           p.CreatedAt,
		UpdatedAt:           p.UpdatedAt,
	}
}

// FromSPEIPaymentForReport — igual que FromSPEIPayment pero con la CLABE
// enmascarada, para el reporte histórico cross-cliente de staff
// ("Reportes" > "Pagos SPEI", ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 2).
// FromSPEIPayment (sin enmascarar) sigue siendo correcto para la cola de
// aprobaciones (ListPendingPayments) — ahí staff necesita la CLABE real
// para verificarla contra el banco antes de aprobar/rechazar un pago
// puntual, mismo criterio de "per-record" que ya aplica a Beneficiario.
func FromSPEIPaymentForReport(p speipayment.Payment) SPEIPayment {
	out := FromSPEIPayment(p)
	out.BeneficiaryCLABE = maskClabeForDisplay(p.BeneficiaryCLABE)
	return out
}

type CreateSPEIPaymentRequest struct {
	BeneficiaryID string  `json:"beneficiaryId"`
	Amount        float64 `json:"amount"`
}

// SPEIDepositWebhookRequest — el payload que un proveedor SPEI (hoy,
// internal/adapters/spei.Simulator) manda a POST /v1/spei/deposits. Sin
// sesión JWT — se autentica con un secreto compartido, ver
// internal/adapters/http/handler/handler_spei.go.
type SPEIDepositWebhookRequest struct {
	CLABE             string  `json:"clabe"`
	Amount            float64 `json:"amount"`
	ProviderReference string  `json:"providerReference"`
}

// SPEIDeposit — CardholderFullName solo viene poblado en el reporte
// cross-cliente de staff (ADR-0022), vacío en el webhook o en el
// listado self-only del propio Tarjetahabiente.
type SPEIDeposit struct {
	ID                 string    `json:"id"`
	ClientID           string    `json:"clientId"`
	AccountID          string    `json:"accountId"`
	Amount             float64   `json:"amount"`
	ProviderReference  string    `json:"providerReference"`
	CreatedAt          time.Time `json:"createdAt"`
	CardholderFullName string    `json:"cardholderFullName,omitempty"`
}

func FromSPEIDeposit(d speipayment.Deposit) SPEIDeposit {
	return SPEIDeposit{
		ID:                 d.ID,
		ClientID:           d.ClientID,
		AccountID:          d.AccountID,
		Amount:             d.Amount,
		ProviderReference:  d.ProviderReference,
		CreatedAt:          d.CreatedAt,
		CardholderFullName: d.CardholderFullName,
	}
}

// BeneficiaryDirectoryEntry — una fila del reporte agregado de staff, ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. CLABE
// viene enmascarada por default (mismo formato que
// beneficiary.Beneficiary.maskedClabe del lado Dart) — la CLABE completa
// solo se obtiene con POST .../reveal.
type BeneficiaryDirectoryEntry struct {
	ID                          string    `json:"id"`
	Alias                       string    `json:"alias"`
	MaskedCLABE                 string    `json:"maskedClabe"`
	BankName                    string    `json:"bankName"`
	CoolingUntil                time.Time `json:"coolingUntil"`
	IsCooling                   bool      `json:"isCooling"`
	CreatedAt                   time.Time `json:"createdAt"`
	ClientID                    string    `json:"clientId"`
	CardholderID                string    `json:"cardholderId"`
	CardholderFullName          string    `json:"cardholderFullName"`
	PaymentCount                int64     `json:"paymentCount"`
	TotalAmountPaid             float64   `json:"totalAmountPaid"`
	SharedByMultipleCardholders bool      `json:"sharedByMultipleCardholders"`
}

func maskClabeForDisplay(clabeNumber string) string {
	if len(clabeNumber) < 4 {
		return "••••"
	}
	return "••••" + clabeNumber[len(clabeNumber)-4:]
}

func FromBeneficiaryDirectoryEntry(e beneficiary.DirectoryEntry) BeneficiaryDirectoryEntry {
	return BeneficiaryDirectoryEntry{
		ID:                          e.ID,
		Alias:                       e.Alias,
		MaskedCLABE:                 maskClabeForDisplay(e.CLABE),
		BankName:                    e.BankName,
		CoolingUntil:                e.CoolingUntil,
		IsCooling:                   e.IsCooling(),
		CreatedAt:                   e.CreatedAt,
		ClientID:                    e.ClientID,
		CardholderID:                e.CardholderID,
		CardholderFullName:          e.CardholderFullName,
		PaymentCount:                e.PaymentCount,
		TotalAmountPaid:             e.TotalAmountPaid,
		SharedByMultipleCardholders: e.SharedByMultipleCardholders,
	}
}

// RevealClabeResponse — respuesta de POST /v1/spei-beneficiaries/{id}/reveal.
type RevealClabeResponse struct {
	CLABE string `json:"clabe"`
}
