// Sin capa de usecase intermedia en esta iteración — a diferencia del
// resto de la arquitectura (ver internal/application/usecase), los
// handlers de este paquete llaman los ports directamente. Es una
// simplificación deliberada y acotada a este backend interino (ver
// docs/tdr/0003-in-memory-repository-adapter.md): la "lógica de negocio"
// de este slice ya vive en el adaptador de memoria (igual que
// cardholder/lib/core/fake_backend.dart del lado Dart), así que una capa
// de usecase intermedia aquí solo reenviaría la llamada sin agregar
// nada. Se reconsidera cuando este backend deje de ser temporal.
package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	"github.com/koons/kbm/backend/internal/application/ports"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

type Handler struct {
	Cards     ports.CardRepository
	Ledger    ports.LedgerRepository
	Auth      ports.CardholderAuthRepository
	Transfers ports.TransferService
}

func New(cards ports.CardRepository, ledgerRepo ports.LedgerRepository, auth ports.CardholderAuthRepository, transfers ports.TransferService) *Handler {
	return &Handler{Cards: cards, Ledger: ledgerRepo, Auth: auth, Transfers: transfers}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/healthz", h.healthz)

	r.Post("/v1/cardholder-sessions", h.login)

	r.Get("/v1/cards", h.listCards)
	r.Get("/v1/cards/{cardID}", h.getCard)
	r.Post("/v1/cards/{cardID}/assign", h.assignCard)
	r.Post("/v1/cards/{cardID}/block-status", h.setBlockStatus)
	r.Get("/v1/cards/{cardID}/ledger", h.getLedger)
	r.Post("/v1/cards/{cardID}/ledger/entries", h.postLedgerEntry)

	r.Post("/v1/cardholders/{cardholderID}/freeze-cards", h.freezeCards)

	r.Post("/v1/transfers/resolve", h.resolveTransfer)
	r.Post("/v1/transfers/execute", h.executeTransfer)

	return r
}

func (h *Handler) healthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var req dto.LoginRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	ch, err := h.Auth.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCardholder(ch))
}

func (h *Handler) listCards(w http.ResponseWriter, r *http.Request) {
	cardholderID := r.URL.Query().Get("cardholder_id")
	clientID := r.URL.Query().Get("client_id")

	var (
		cards []dto.Card
		err   error
	)
	switch {
	case cardholderID != "":
		list, e := h.Cards.ListByCardholder(r.Context(), cardholderID)
		err = e
		for _, c := range list {
			cards = append(cards, dto.FromCard(c))
		}
	case clientID != "":
		list, e := h.Cards.ListByClient(r.Context(), clientID)
		err = e
		for _, c := range list {
			cards = append(cards, dto.FromCard(c))
		}
	default:
		writeErrorMessage(w, http.StatusBadRequest, "cardholder_id o client_id es requerido")
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if cards == nil {
		cards = []dto.Card{}
	}
	writeJSON(w, http.StatusOK, cards)
}

func (h *Handler) getCard(w http.ResponseWriter, r *http.Request) {
	c, err := h.Cards.GetByID(r.Context(), chi.URLParam(r, "cardID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCard(c))
}

func (h *Handler) assignCard(w http.ResponseWriter, r *http.Request) {
	var req dto.AssignRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.Cards.Assign(r.Context(), chi.URLParam(r, "cardID"), req.CardholderID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCard(c))
}

func (h *Handler) setBlockStatus(w http.ResponseWriter, r *http.Request) {
	var req dto.BlockStatusRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	c, err := h.Cards.SetBlocked(r.Context(), chi.URLParam(r, "cardID"), req.Blocked)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCard(c))
}

func (h *Handler) freezeCards(w http.ResponseWriter, r *http.Request) {
	if err := h.Cards.FreezeAllForCardholder(r.Context(), chi.URLParam(r, "cardholderID")); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) getLedger(w http.ResponseWriter, r *http.Request) {
	account, entries, err := h.Ledger.GetByCard(r.Context(), chi.URLParam(r, "cardID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromLedger(account, entries))
}

func (h *Handler) postLedgerEntry(w http.ResponseWriter, r *http.Request) {
	var req dto.PostLedgerEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	entryType := ledger.EntryCredit
	if req.Type == string(ledger.EntryDebit) {
		entryType = ledger.EntryDebit
	}
	entry, err := h.Ledger.PostEntry(r.Context(), chi.URLParam(r, "cardID"), entryType, req.Amount, req.Description)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromLedgerEntry(entry))
}

func (h *Handler) resolveTransfer(w http.ResponseWriter, r *http.Request) {
	var req dto.ResolveTransferRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	resolved, err := h.Transfers.ResolveDestination(r.Context(), req.CardholderID, req.OriginCardID, req.PAN)
	if err != nil {
		writeError(w, err)
		return
	}
	if resolved == nil {
		// Mensaje genérico a propósito — nunca se distingue el motivo de
		// no-match. Ver threat-model punto 12.
		writeErrorMessage(w, http.StatusNotFound, "No se encontró ninguna tarjeta válida para ese número.")
		return
	}
	writeJSON(w, http.StatusOK, dto.ResolveTransferResponse{
		CardID:         resolved.Card.ID,
		MaskedPAN:      resolved.Card.MaskedPAN,
		CardholderName: resolved.CardholderName,
	})
}

func (h *Handler) executeTransfer(w http.ResponseWriter, r *http.Request) {
	var req dto.ExecuteTransferRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if err := h.Transfers.Execute(r.Context(), req.OriginCardID, req.DestinationCardID, req.Amount); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- helpers ------------------------------------------------------

func decodeJSON(w http.ResponseWriter, r *http.Request, v any) bool {
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		writeErrorMessage(w, http.StatusBadRequest, "cuerpo de la petición inválido")
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErrorMessage(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, dto.ErrorResponse{Message: message})
}

// writeError mapea los sentinel errors de internal/domain/shared al
// status HTTP correspondiente — ver backend/api/openapi.yaml para el
// contrato exacto de cada endpoint.
func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, shared.ErrNotFound):
		writeErrorMessage(w, http.StatusNotFound, "no encontrado")
	case errors.Is(err, shared.ErrInvalidCredentials):
		writeErrorMessage(w, http.StatusUnauthorized, "Email o contraseña incorrectos.")
	case errors.Is(err, shared.ErrTooManyFailedAttempts):
		writeErrorMessage(w, http.StatusTooManyRequests, "Demasiados intentos fallidos. Vuelve a iniciar sesión para intentar una transferencia de nuevo.")
	case errors.Is(err, shared.ErrInsufficientFunds):
		writeErrorMessage(w, http.StatusPaymentRequired, "Fondos insuficientes.")
	case errors.Is(err, shared.ErrCardLimitExceeded):
		var limitErr *shared.CardLimitExceededError
		resp := dto.ErrorResponse{Message: err.Error()}
		if errors.As(err, &limitErr) {
			resp.Limit = &limitErr.Limit
		}
		writeJSON(w, http.StatusConflict, resp)
	case errors.Is(err, shared.ErrCardNotAvailable), errors.Is(err, shared.ErrInvalidState):
		writeErrorMessage(w, http.StatusConflict, err.Error())
	case errors.Is(err, shared.ErrValidation):
		writeErrorMessage(w, http.StatusBadRequest, err.Error())
	default:
		writeErrorMessage(w, http.StatusInternalServerError, "error interno")
	}
}
