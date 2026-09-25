// Conector SPEI — ver docs/adr/0021-conector-spei.md.
package handler

import (
	"crypto/subtle"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/koons/kbm/backend/internal/adapters/auth/local"
	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	authmw "github.com/koons/kbm/backend/internal/adapters/http/middleware"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

// requireSelfCardholder — mismo criterio que setSelfFrozen: solo el
// propio Tarjetahabiente (nunca staff, nunca otro Tarjetahabiente) puede
// **escribir** su CLABE, sus Beneficiarios de Pago o iniciar un pago
// SPEI — ver docs/adr/0021-conector-spei.md, punto 5 ("quién origina un
// pago"), sin cambio por ADR-0022. Devuelve false (y ya escribió la
// respuesta de error) si no aplica.
func requireSelfCardholder(w http.ResponseWriter, r *http.Request, cardholderID string) bool {
	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims == nil || claims.Type != local.SubjectCardholder || claims.CardholderID != cardholderID {
		writeError(w, shared.ErrNotFound)
		return false
	}
	return true
}

// requireSelfOrStaff — ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md,
// punto 1: los endpoints de **lectura** de SPEI (CLABE, Beneficiarios,
// pagos, depósitos, saldo de Cuenta) los puede ver tanto el propio
// Tarjetahabiente como cualquier staff — mismo criterio exacto que ya
// usan getCard/getLedger para tarjetas. El alcance real de qué
// Tarjetahabiente puede ver un staff en particular lo sigue acotando RLS
// (withRLS, vía app.accessible_client_ids), no este chequeo — esto solo
// descarta al caso que nunca debe pasar: otro Tarjetahabiente que no sea
// el dueño.
func requireSelfOrStaff(w http.ResponseWriter, r *http.Request, cardholderID string) bool {
	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims == nil {
		writeError(w, shared.ErrNotFound)
		return false
	}
	if claims.Type == local.SubjectCardholder && claims.CardholderID != cardholderID {
		writeError(w, shared.ErrNotFound)
		return false
	}
	return true
}

func (h *Handler) getCLABE(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfOrStaff(w, r, cardholderID) {
		return
	}
	clabeNumber, err := h.SPEI.GetCLABE(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.CLABEResponse{CLABE: clabeNumber})
}

func (h *Handler) ensureCLABE(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfCardholder(w, r, cardholderID) {
		return
	}
	clabeNumber, err := h.SPEI.EnsureCLABE(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.CLABEResponse{CLABE: &clabeNumber})
}

// getAccountLedger — saldo y movimientos de la Cuenta Individual,
// disponible incluso sin ninguna tarjeta asignada (ver
// docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3). Reusa
// dto.LedgerView/dto.FromLedger — mismo shape que GET
// /v1/cards/{cardID}/ledger, para que cardholder/ pueda usar el mismo
// modelo de datos en ambos casos.
func (h *Handler) getAccountLedger(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfOrStaff(w, r, cardholderID) {
		return
	}
	account, entries, err := h.SPEI.GetAccountLedger(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromLedger(account, entries))
}

func (h *Handler) listBeneficiaries(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfOrStaff(w, r, cardholderID) {
		return
	}
	list, err := h.SPEI.ListBeneficiaries(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.Beneficiary, 0, len(list))
	for _, b := range list {
		out = append(out, dto.FromBeneficiary(b))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) registerBeneficiary(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfCardholder(w, r, cardholderID) {
		return
	}
	var req dto.RegisterBeneficiaryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	b, err := h.SPEI.RegisterBeneficiary(r.Context(), cardholderID, req.Alias, req.CLABE)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromBeneficiary(b))
}

func (h *Handler) listSPEIPayments(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfOrStaff(w, r, cardholderID) {
		return
	}
	list, err := h.SPEI.ListPayments(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.SPEIPayment, 0, len(list))
	for _, p := range list {
		out = append(out, dto.FromSPEIPayment(p))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) createSPEIPayment(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfCardholder(w, r, cardholderID) {
		return
	}
	var req dto.CreateSPEIPaymentRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.SPEI.CreatePayment(r.Context(), cardholderID, req.BeneficiaryID, req.Amount)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromSPEIPayment(p))
}

// listSPEIDeposits — mis depósitos SPEI entrantes, base del comprobante
// propio de un depósito (ADR-0021, punto 9).
func (h *Handler) listSPEIDeposits(w http.ResponseWriter, r *http.Request) {
	cardholderID := chi.URLParam(r, "cardholderID")
	if !requireSelfOrStaff(w, r, cardholderID) {
		return
	}
	list, err := h.SPEI.ListDeposits(r.Context(), cardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.SPEIDeposit, 0, len(list))
	for _, d := range list {
		out = append(out, dto.FromSPEIDeposit(d))
	}
	writeJSON(w, http.StatusOK, out)
}

// listPendingSPEIPayments — cola de aprobación para staff, mismo criterio
// que listPendingBalanceOperations (client_ids por query string, RLS
// filtra lo que cada quien puede ver de verdad).
func (h *Handler) listPendingSPEIPayments(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	list, err := h.SPEI.ListPendingPayments(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.SPEIPayment, 0, len(list))
	for _, p := range list {
		out = append(out, dto.FromSPEIPayment(p))
	}
	writeJSON(w, http.StatusOK, out)
}

// listAllSPEIPayments — historial completo (cualquier estatus) para el
// reporte de staff, ver docs/feature/reportes-admin/README.md. Mismo
// criterio de client_ids que listPendingSPEIPayments.
func (h *Handler) listAllSPEIPayments(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	list, err := h.SPEI.ListPaymentsByClients(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.SPEIPayment, 0, len(list))
	for _, p := range list {
		out = append(out, dto.FromSPEIPaymentForReport(p))
	}
	writeJSON(w, http.StatusOK, out)
}

// listAllSPEIDeposits — reporte de depósitos SPEI cross-cliente para
// staff, ver docs/feature/reportes-admin/README.md.
func (h *Handler) listAllSPEIDeposits(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	list, err := h.SPEI.ListDepositsByClients(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.SPEIDeposit, 0, len(list))
	for _, d := range list {
		out = append(out, dto.FromSPEIDeposit(d))
	}
	writeJSON(w, http.StatusOK, out)
}

// listSPEIBeneficiaries — el directorio agregado de Beneficiarios de
// Pago para staff, ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md.
func (h *Handler) listSPEIBeneficiaries(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	list, err := h.SPEI.ListBeneficiaryDirectory(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.BeneficiaryDirectoryEntry, 0, len(list))
	for _, e := range list {
		out = append(out, dto.FromBeneficiaryDirectoryEntry(e))
	}
	writeJSON(w, http.StatusOK, out)
}

// revealBeneficiaryCLABE — staff-only (manageRoles, ver Routes()), ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 2.
// Queda auditada (ver SPEIStore.RevealBeneficiaryCLABE).
func (h *Handler) revealBeneficiaryCLABE(w http.ResponseWriter, r *http.Request) {
	clabeNumber, err := h.SPEI.RevealBeneficiaryCLABE(r.Context(), chi.URLParam(r, "beneficiaryID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.RevealClabeResponse{CLABE: clabeNumber})
}

func (h *Handler) approveSPEIPayment(w http.ResponseWriter, r *http.Request) {
	var req dto.ApproveOperationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.SPEI.ApprovePayment(r.Context(), chi.URLParam(r, "paymentID"), req.ApprovedByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromSPEIPayment(p))
}

func (h *Handler) rejectSPEIPayment(w http.ResponseWriter, r *http.Request) {
	var req dto.RejectOperationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	p, err := h.SPEI.RejectPayment(r.Context(), chi.URLParam(r, "paymentID"), req.RejectedByEmail, req.Reason)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromSPEIPayment(p))
}

// handleSPEIDepositWebhook — sin sesión JWT (lo llama un proveedor
// externo, ver docs/adr/0021-conector-spei.md): se autentica comparando
// [h.SPEIWebhookSecret] contra el header X-SPEI-Webhook-Secret, en tiempo
// constante (subtle.ConstantTimeCompare) para no filtrar el secreto por
// temporización. Registrada en Routes() solo si el secreto no está vacío.
func (h *Handler) handleSPEIDepositWebhook(w http.ResponseWriter, r *http.Request) {
	got := r.Header.Get("X-SPEI-Webhook-Secret")
	if subtle.ConstantTimeCompare([]byte(got), []byte(h.SPEIWebhookSecret)) != 1 {
		writeErrorMessage(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req dto.SPEIDepositWebhookRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	d, err := h.SPEI.HandleDeposit(r.Context(), req.CLABE, req.Amount, req.ProviderReference)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromSPEIDeposit(d))
}
