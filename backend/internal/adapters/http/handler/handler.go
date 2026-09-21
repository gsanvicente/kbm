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

	"github.com/koons/kbm/backend/internal/adapters/auth/local"
	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	authmw "github.com/koons/kbm/backend/internal/adapters/http/middleware"
	"github.com/koons/kbm/backend/internal/application/ports"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

type Handler struct {
	Cards     ports.CardRepository
	Ledger    ports.LedgerRepository
	Auth      ports.CardholderAuthRepository
	Transfers ports.TransferService
	Tokens    *local.TokenIssuer

	// Nil en modo memoria (STORAGE_BACKEND=memory) — esos ports nunca
	// formaron parte del alcance del adaptador en memoria (ver
	// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md);
	// solo el adaptador Postgres los implementa. Routes() solo registra
	// las rutas correspondientes cuando el campo no es nil.
	Clients     ports.ClientRepository
	Treasury    ports.TreasuryRepository
	StaffAuth   ports.StaffAuthRepository
	BalanceOps  ports.BalanceOperationRepository
	Cardholders ports.CardholderManagementRepository
}

func New(cards ports.CardRepository, ledgerRepo ports.LedgerRepository, auth ports.CardholderAuthRepository, transfers ports.TransferService, tokens *local.TokenIssuer) *Handler {
	return &Handler{Cards: cards, Ledger: ledgerRepo, Auth: auth, Transfers: transfers, Tokens: tokens}
}

// Routes — ver docs/adr/0013-jwt-session-authentication.md. Solo los dos
// endpoints de login (y /healthz) quedan fuera de RequireAuth; todo lo
// demás exige un token verificado, y las rutas que solo administra
// staff (todo lo de handler_management.go salvo el propio login) además
// exigen RequireStaff.
func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()

	r.Get("/healthz", h.healthz)

	r.Post("/v1/cardholder-sessions", h.login)
	if h.StaffAuth != nil {
		r.Post("/v1/staff-sessions", h.staffLogin)
	}

	r.Group(func(r chi.Router) {
		r.Use(authmw.RequireAuth(h.Tokens))
		// Traduce las claims JWT ya verificadas a lo que el adaptador
		// Postgres necesita para fijar app.accessible_client_ids (Row-Level
		// Security, ver docs/adr/0014-row-level-security-policies.md) — un
		// nil aquí significa alcance global (Super Admin), nunca "no
		// establecido" (eso lo distingue ports.WithCallerClientID).
		r.Use(func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				claims, _ := authmw.ClaimsFromContext(r.Context())
				var clientID *string
				if claims != nil {
					clientID = claims.ClientID
				}
				next.ServeHTTP(w, r.WithContext(ports.WithCallerClientID(r.Context(), clientID)))
			})
		})

		// Cards/Ledger/Transferencias — alcance mixto (staff y
		// Tarjetahabiente, cada handler decide qué le corresponde a
		// quién; ver los comentarios de cada uno).
		r.Get("/v1/cards", h.listCards)
		r.Get("/v1/cards/{cardID}", h.getCard)
		r.Get("/v1/cards/{cardID}/ledger", h.getLedger)

		r.Post("/v1/cards/{cardID}/self-freeze", h.setSelfFrozen)
		r.Post("/v1/transfers/resolve", h.resolveTransfer)
		r.Post("/v1/transfers/execute", h.executeTransfer)

		r.Group(func(r chi.Router) {
			r.Use(authmw.RequireStaff)

			// Lecturas — cualquier rol de staff dentro de su alcance (RLS
			// ya lo acota), incluido Auditor. Ver
			// docs/business/roles-and-permissions.md: "ver" nunca requiere
			// más que ser staff.
			if h.Clients != nil {
				r.Get("/v1/clients", h.listClients)
				r.Get("/v1/clients/{clientID}/operable", h.isClientOperable)
			}
			if h.Cards != nil {
				r.Get("/v1/clients/{clientID}/settings", h.getClientSettings)
			}
			if h.BalanceOps != nil {
				r.Get("/v1/clients/{clientID}/approval-rules", h.listApprovalRules)
				r.Get("/v1/balance-operations", h.listBalanceOperations)
				r.Get("/v1/balance-operations/pending", h.listPendingBalanceOperations)
				r.Get("/v1/balance-operations/weekly-trend", h.weeklyTrend)
			}
			if h.Treasury != nil {
				r.Get("/v1/clients/{clientID}/treasury/concentrator", h.getConcentratorAccount)
				r.Get("/v1/concentrator-accounts/{accountID}/entries", h.listConcentratorEntries)
				r.Get("/v1/clients/{clientID}/treasury/collector-deposits", h.listCollectorDeposits)
			}
			if h.Cardholders != nil {
				r.Get("/v1/cardholders", h.listCardholders)
				r.Get("/v1/cardholders/{cardholderID}", h.getCardholder)
			}
			if h.Ledger != nil {
				r.Get("/v1/ledger-entries/{entryID}/claim", h.getClaim)
				r.Get("/v1/claims", h.listClaims)
			}

			// manageRoles — Super Admin/Admin Cliente, ver authz.go.
			r.Group(func(r chi.Router) {
				r.Use(authmw.RequireRole(manageRoles...))
				r.Post("/v1/cards/{cardID}/assign", h.assignCard)
				r.Post("/v1/cardholders/{cardholderID}/freeze-cards", h.freezeCards)

				if h.Clients != nil {
					r.Post("/v1/clients", h.createClient)
					r.Put("/v1/clients/{clientID}", h.updateClient)
					r.Post("/v1/clients/{clientID}/active-status", h.setClientActive)
				}
				if h.Cards != nil {
					r.Put("/v1/clients/{clientID}/settings", h.setClientSettings)
				}
				if h.BalanceOps != nil {
					r.Put("/v1/clients/{clientID}/approval-rules/{operationType}", h.setApprovalRule)
					r.Delete("/v1/clients/{clientID}/approval-rules/{operationType}", h.deleteApprovalRule)
					r.Post("/v1/balance-operations/{operationID}/approve", h.approveBalanceOperation)
					r.Post("/v1/balance-operations/{operationID}/reject", h.rejectBalanceOperation)
				}
				if h.Treasury != nil {
					r.Post("/v1/clients/{clientID}/treasury/concentrator", h.createConcentratorAccount)
					r.Post("/v1/collector-deposits/{depositID}/reconcile", h.reconcileDeposit)
				}
				if h.Cardholders != nil {
					r.Post("/v1/cardholders", h.createCardholder)
					r.Put("/v1/cardholders/{cardholderID}", h.updateCardholder)
					r.Post("/v1/cardholders/{cardholderID}/active-status", h.setCardholderActive)
				}
				if h.Ledger != nil {
					r.Post("/v1/claims/{claimID}/resolve", h.resolveClaim)
				}
			})

			// operateRoles — todos salvo Auditor, ver authz.go.
			r.Group(func(r chi.Router) {
				r.Use(authmw.RequireRole(operateRoles...))
				r.Post("/v1/cards/{cardID}/block-status", h.setBlockStatus)
				r.Post("/v1/cards/{cardID}/ledger/entries", h.postLedgerEntry)

				if h.Treasury != nil {
					r.Post("/v1/concentrator-accounts/{accountID}/entries", h.postConcentratorEntry)
					r.Post("/v1/clients/{clientID}/treasury/collector-deposits", h.registerDeposit)
				}
				if h.BalanceOps != nil {
					r.Post("/v1/balance-operations", h.requestBalanceOperation)
				}
				if h.Ledger != nil {
					r.Post("/v1/ledger-entries/{entryID}/claim", h.fileClaim)
				}
			})
		})
	})

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
	token, err := h.Tokens.IssueCardholder(ch.ID, ch.ClientID)
	if err != nil {
		writeError(w, err)
		return
	}
	resp := dto.FromCardholder(ch)
	resp.AccessToken = token
	writeJSON(w, http.StatusOK, resp)
}

// listCards — GET /v1/cards?cardholder_id=X viene tanto de admin/ (staff,
// cualquier cardholder_id) como de cardholder/ (el propio, ver
// docs/adr/0013-jwt-session-authentication.md); client_id solo lo usa
// admin/. Un token de Tarjetahabiente pidiendo el cardholder_id de otro
// se rechaza como si no existiera (mismo criterio "nunca revelar" que ya
// usa SetFrozen).
func (h *Handler) listCards(w http.ResponseWriter, r *http.Request) {
	cardholderID := r.URL.Query().Get("cardholder_id")
	clientID := r.URL.Query().Get("client_id")

	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims.Type == local.SubjectCardholder && (cardholderID != "" || clientID != "") {
		if clientID != "" || cardholderID != claims.CardholderID {
			writeError(w, shared.ErrNotFound)
			return
		}
	}

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
	// Un Tarjetahabiente solo puede ver sus propias tarjetas por id
	// directo — igual criterio que listCards. admin/ (staff) puede ver
	// cualquiera.
	if claims, _ := authmw.ClaimsFromContext(r.Context()); claims.Type == local.SubjectCardholder {
		if c.CardholderID == nil || *c.CardholderID != claims.CardholderID {
			writeError(w, shared.ErrNotFound)
			return
		}
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

// setSelfFrozen — solo el propio Tarjetahabiente, nunca admin/ (bloqueo
// de staff usa setBlockStatus). req.CardholderID debe coincidir con el
// token — ver docs/adr/0013-jwt-session-authentication.md.
func (h *Handler) setSelfFrozen(w http.ResponseWriter, r *http.Request) {
	var req dto.SelfFreezeRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims.Type != local.SubjectCardholder || claims.CardholderID != req.CardholderID {
		writeError(w, shared.ErrNotFound)
		return
	}
	c, err := h.Cards.SetFrozen(r.Context(), chi.URLParam(r, "cardID"), req.CardholderID, req.Frozen)
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

// getLedger — mismo criterio que getCard: un Tarjetahabiente solo ve el
// ledger de sus propias tarjetas.
func (h *Handler) getLedger(w http.ResponseWriter, r *http.Request) {
	cardID := chi.URLParam(r, "cardID")
	if claims, _ := authmw.ClaimsFromContext(r.Context()); claims.Type == local.SubjectCardholder {
		c, err := h.Cards.GetByID(r.Context(), cardID)
		if err != nil {
			writeError(w, err)
			return
		}
		if c.CardholderID == nil || *c.CardholderID != claims.CardholderID {
			writeError(w, shared.ErrNotFound)
			return
		}
	}
	account, entries, err := h.Ledger.GetByCard(r.Context(), cardID)
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

// resolveTransfer/executeTransfer — solo el propio Tarjetahabiente.
// req.CardholderID (resolve) debe coincidir con el token; execute no
// lleva cardholderId en el cuerpo (ver dto.ExecuteTransferRequest), así
// que se verifica que la tarjeta de origen sea suya.
func (h *Handler) resolveTransfer(w http.ResponseWriter, r *http.Request) {
	var req dto.ResolveTransferRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims.Type != local.SubjectCardholder || claims.CardholderID != req.CardholderID {
		writeError(w, shared.ErrNotFound)
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
	claims, _ := authmw.ClaimsFromContext(r.Context())
	if claims.Type != local.SubjectCardholder {
		writeError(w, shared.ErrNotFound)
		return
	}
	origin, err := h.Cards.GetByID(r.Context(), req.OriginCardID)
	if err != nil {
		writeError(w, err)
		return
	}
	if origin.CardholderID == nil || *origin.CardholderID != claims.CardholderID {
		writeError(w, shared.ErrNotFound)
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
	case errors.Is(err, shared.ErrForbidden):
		// El Cliente (o Tarjetahabiente) involucrado está inactivo — admin/
		// remapea 403 a su propia excepción tipada
		// (ClientInactiveException/CardholderInactiveException) con el
		// mensaje exacto que espera mostrar, no usa este texto tal cual.
		writeErrorMessage(w, http.StatusForbidden, "esta empresa o tarjetahabiente está inactivo y no puede operar")
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
