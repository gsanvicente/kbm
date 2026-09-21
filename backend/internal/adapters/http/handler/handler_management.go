package handler

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	authmw "github.com/koons/kbm/backend/internal/adapters/http/middleware"
	"github.com/koons/kbm/backend/internal/domain/approval"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/staff"
)

// splitCSV — varios endpoints reciben una lista de ids como
// ?client_ids=a,b,c (el mismo patrón que admin/'s repositorios HTTP ya
// usan para "varias llamadas combinadas" en otros endpoints, aquí como
// un solo parámetro en vez de N peticiones).
func splitCSV(v string) []string {
	if v == "" {
		return nil
	}
	return strings.Split(v, ",")
}

// --- Staff login ------------------------------------------------------

func (h *Handler) staffLogin(w http.ResponseWriter, r *http.Request) {
	var req dto.StaffLoginRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	u, err := h.StaffAuth.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		writeError(w, err)
		return
	}
	token, err := h.Tokens.IssueStaff(u.ID, string(u.Role), u.ClientID)
	if err != nil {
		writeError(w, err)
		return
	}
	resp := dto.FromStaffUser(u)
	resp.AccessToken = token
	writeJSON(w, http.StatusOK, resp)
}

// --- Clientes ------------------------------------------------------

func (h *Handler) listClients(w http.ResponseWriter, r *http.Request) {
	clients, err := h.Clients.ListAll(r.Context())
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.Client, 0, len(clients))
	for _, c := range clients {
		out = append(out, dto.FromClient(c))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) createClient(w http.ResponseWriter, r *http.Request) {
	var req dto.Client
	if !decodeJSON(w, r, &req) {
		return
	}
	created, err := h.Clients.Create(r.Context(), dto.ToClient(req))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromClient(created))
}

func (h *Handler) updateClient(w http.ResponseWriter, r *http.Request) {
	var req dto.Client
	if !decodeJSON(w, r, &req) {
		return
	}
	req.ID = chi.URLParam(r, "clientID")
	updated, err := h.Clients.Update(r.Context(), dto.ToClient(req))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromClient(updated))
}

func (h *Handler) setClientActive(w http.ResponseWriter, r *http.Request) {
	var req dto.SetActiveRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	updated, err := h.Clients.SetActive(r.Context(), chi.URLParam(r, "clientID"), req.Active)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromClient(updated))
}

func (h *Handler) isClientOperable(w http.ResponseWriter, r *http.Request) {
	operable, err := h.Clients.IsOperable(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.IsOperableResponse{Operable: operable})
}

func (h *Handler) getClientSettings(w http.ResponseWriter, r *http.Request) {
	max, err := h.Cards.MaxActiveCardsPerCardholder(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.ClientSettingsResponse{MaxActiveCardsPerCardholder: max})
}

func (h *Handler) setClientSettings(w http.ResponseWriter, r *http.Request) {
	var req dto.SetClientSettingsRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	max, err := h.Cards.SetMaxActiveCardsPerCardholder(r.Context(), chi.URLParam(r, "clientID"), req.MaxActiveCardsPerCardholder)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.ClientSettingsResponse{MaxActiveCardsPerCardholder: max})
}

func (h *Handler) listApprovalRules(w http.ResponseWriter, r *http.Request) {
	rules, err := h.BalanceOps.ListApprovalRules(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.ApprovalRule, 0, len(rules))
	for _, rule := range rules {
		out = append(out, dto.FromApprovalRule(rule))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) setApprovalRule(w http.ResponseWriter, r *http.Request) {
	var req dto.SetApprovalRuleRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	rule, err := h.BalanceOps.SetApprovalRule(
		r.Context(),
		chi.URLParam(r, "clientID"),
		approval.OperationType(chi.URLParam(r, "operationType")),
		req.RequiresApproval,
		req.MinAmount,
	)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromApprovalRule(rule))
}

func (h *Handler) deleteApprovalRule(w http.ResponseWriter, r *http.Request) {
	err := h.BalanceOps.DeleteApprovalRule(
		r.Context(),
		chi.URLParam(r, "clientID"),
		approval.OperationType(chi.URLParam(r, "operationType")),
	)
	if err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Cardholders (KYC) ------------------------------------------------------

func (h *Handler) listCardholders(w http.ResponseWriter, r *http.Request) {
	clientID := r.URL.Query().Get("client_id")
	clientIDs := splitCSV(r.URL.Query().Get("client_ids"))

	var (
		result []dto.Cardholder
		err    error
	)
	switch {
	case clientID != "":
		cs, e := h.Cardholders.ListByClient(r.Context(), clientID)
		err = e
		for _, c := range cs {
			result = append(result, dto.FromCardholderManagement(c))
		}
	case len(clientIDs) > 0:
		cs, e := h.Cardholders.ListByClients(r.Context(), clientIDs)
		err = e
		for _, c := range cs {
			result = append(result, dto.FromCardholderManagement(c))
		}
	default:
		writeErrorMessage(w, http.StatusBadRequest, "client_id o client_ids es requerido")
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if result == nil {
		result = []dto.Cardholder{}
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) getCardholder(w http.ResponseWriter, r *http.Request) {
	c, err := h.Cardholders.GetByID(r.Context(), chi.URLParam(r, "cardholderID"))
	if err != nil {
		writeError(w, err)
		return
	}
	if c == nil {
		writeErrorMessage(w, http.StatusNotFound, "no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCardholderManagement(*c))
}

func (h *Handler) createCardholder(w http.ResponseWriter, r *http.Request) {
	var req dto.Cardholder
	if !decodeJSON(w, r, &req) {
		return
	}
	created, err := h.Cardholders.Create(r.Context(), dto.ToCardholderManagement(req))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCardholderManagement(created))
}

func (h *Handler) updateCardholder(w http.ResponseWriter, r *http.Request) {
	var req dto.Cardholder
	if !decodeJSON(w, r, &req) {
		return
	}
	req.ID = chi.URLParam(r, "cardholderID")
	updated, err := h.Cardholders.Update(r.Context(), dto.ToCardholderManagement(req))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCardholderManagement(updated))
}

func (h *Handler) setCardholderActive(w http.ResponseWriter, r *http.Request) {
	var req dto.SetActiveRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	updated, err := h.Cardholders.SetActive(r.Context(), chi.URLParam(r, "cardholderID"), req.Active)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCardholderManagement(updated))
}

// --- Tesorería ------------------------------------------------------

func (h *Handler) getConcentratorAccount(w http.ResponseWriter, r *http.Request) {
	account, err := h.Treasury.GetConcentratorAccount(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	if account == nil {
		writeErrorMessage(w, http.StatusNotFound, "no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, dto.FromConcentratorAccount(*account))
}

func (h *Handler) createConcentratorAccount(w http.ResponseWriter, r *http.Request) {
	account, err := h.Treasury.CreateConcentratorAccount(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromConcentratorAccount(account))
}

func (h *Handler) listConcentratorEntries(w http.ResponseWriter, r *http.Request) {
	entries, err := h.Treasury.ListConcentratorEntries(r.Context(), chi.URLParam(r, "accountID"))
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.ConcentratorEntry, 0, len(entries))
	for _, e := range entries {
		out = append(out, dto.FromConcentratorEntry(e))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) postConcentratorEntry(w http.ResponseWriter, r *http.Request) {
	var req dto.PostConcentratorEntryRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	entryType := ledger.EntryCredit
	if req.Type == string(ledger.EntryDebit) {
		entryType = ledger.EntryDebit
	}
	entry, err := h.Treasury.PostConcentratorEntry(r.Context(), chi.URLParam(r, "accountID"), entryType, req.Amount, req.Description)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromConcentratorEntry(entry))
}

func (h *Handler) listCollectorDeposits(w http.ResponseWriter, r *http.Request) {
	deposits, err := h.Treasury.ListCollectorDeposits(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.CollectorDeposit, 0, len(deposits))
	for _, d := range deposits {
		out = append(out, dto.FromCollectorDeposit(d))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) registerDeposit(w http.ResponseWriter, r *http.Request) {
	var req dto.RegisterDepositRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	deposit, err := h.Treasury.RegisterDeposit(r.Context(), chi.URLParam(r, "clientID"), req.Amount, req.Reference, req.RegisteredByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCollectorDeposit(deposit))
}

func (h *Handler) reconcileDeposit(w http.ResponseWriter, r *http.Request) {
	var req dto.ReconcileDepositRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	deposit, err := h.Treasury.ReconcileDeposit(r.Context(), chi.URLParam(r, "depositID"), req.ReconciledByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromCollectorDeposit(deposit))
}

// --- Aprobaciones (Operaciones de saldo) -------------------------------

func (h *Handler) listBalanceOperations(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	ops, err := h.BalanceOps.ListByClients(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.BalanceOperation, 0, len(ops))
	for _, op := range ops {
		out = append(out, dto.FromBalanceOperation(op))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) listPendingBalanceOperations(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	ops, err := h.BalanceOps.ListPendingByClients(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.BalanceOperation, 0, len(ops))
	for _, op := range ops {
		out = append(out, dto.FromBalanceOperation(op))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) weeklyTrend(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("client_ids"))
	trend, err := h.BalanceOps.GetWeeklyTrend(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.WeekVolume, 0, len(trend))
	for _, w2 := range trend {
		out = append(out, dto.FromWeekVolume(w2))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) requestBalanceOperation(w http.ResponseWriter, r *http.Request) {
	var req dto.RequestBalanceOperationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	op, err := h.BalanceOps.Request(r.Context(), req.ClientID, req.CardID, approval.OperationType(req.Type), req.Amount, req.DestinationCardID, req.RequestedByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromBalanceOperation(op))
}

func (h *Handler) approveBalanceOperation(w http.ResponseWriter, r *http.Request) {
	var req dto.ApproveOperationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	op, err := h.BalanceOps.Approve(r.Context(), chi.URLParam(r, "operationID"), req.ApprovedByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromBalanceOperation(op))
}

func (h *Handler) rejectBalanceOperation(w http.ResponseWriter, r *http.Request) {
	var req dto.RejectOperationRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	op, err := h.BalanceOps.Reject(r.Context(), chi.URLParam(r, "operationID"), req.RejectedByEmail, req.Reason)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromBalanceOperation(op))
}

// --- Reclamos ------------------------------------------------------

func (h *Handler) getClaim(w http.ResponseWriter, r *http.Request) {
	claim, err := h.Ledger.GetClaim(r.Context(), chi.URLParam(r, "entryID"))
	if err != nil {
		writeError(w, err)
		return
	}
	if claim == nil {
		writeErrorMessage(w, http.StatusNotFound, "no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, dto.FromMovementClaim(*claim))
}

// listClaims — forma en lote de getClaim, ver
// ports.LedgerRepository.GetClaimsByLedgerEntries: evita una llamada HTTP
// por movimiento en pantallas como el Panel directivo (antes:
// admin/lib/features/ledger/http_ledger_repository.dart hacía
// Future.wait de N getClaim, un patrón N+1 real).
func (h *Handler) listClaims(w http.ResponseWriter, r *http.Request) {
	ids := splitCSV(r.URL.Query().Get("ledger_entry_ids"))
	if len(ids) == 0 {
		writeErrorMessage(w, http.StatusBadRequest, "ledger_entry_ids es requerido")
		return
	}
	claims, err := h.Ledger.GetClaimsByLedgerEntries(r.Context(), ids)
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.MovementClaim, 0, len(claims))
	for _, c := range claims {
		out = append(out, dto.FromMovementClaim(c))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) fileClaim(w http.ResponseWriter, r *http.Request) {
	var req dto.FileClaimRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	claim, err := h.Ledger.FileClaim(r.Context(), chi.URLParam(r, "entryID"), req.Reason, req.RequestedByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromMovementClaim(claim))
}

func (h *Handler) resolveClaim(w http.ResponseWriter, r *http.Request) {
	var req dto.ResolveClaimRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	claim, err := h.Ledger.ResolveClaim(r.Context(), chi.URLParam(r, "claimID"), req.InFavor, req.ResolutionNotes, req.ResolvedByEmail)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromMovementClaim(claim))
}

// --- Gestión de usuarios de staff ---------------------------------------
// Ver docs/feature/gestion-de-usuarios-staff/README.md.

// isAssignableStaffRole — Super Admin nunca es un rol asignable desde
// esta pantalla, sin importar quién lo pida (Super Admin o Admin
// Cliente) — ver docs/business/gestion-de-usuarios-staff.md, "Quién
// puede crear a quién".
func isAssignableStaffRole(role string) bool {
	switch staff.Role(role) {
	case staff.RoleClientAdmin, staff.RoleOperator, staff.RoleAuditor:
		return true
	default:
		return false
	}
}

const minStaffPasswordLength = 8

func (h *Handler) listStaffUsers(w http.ResponseWriter, r *http.Request) {
	users, err := h.StaffManagement.ListByClient(r.Context(), chi.URLParam(r, "clientID"))
	if err != nil {
		writeError(w, err)
		return
	}
	out := make([]dto.StaffUser, 0, len(users))
	for _, u := range users {
		out = append(out, dto.FromStaffUserResource(u))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) createStaffUser(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateStaffUserRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if !isAssignableStaffRole(req.Role) {
		writeErrorMessage(w, http.StatusBadRequest, "rol inválido")
		return
	}
	if req.Password != req.ConfirmPassword {
		writeErrorMessage(w, http.StatusBadRequest, "las contraseñas no coinciden")
		return
	}
	if len(req.Password) < minStaffPasswordLength {
		writeErrorMessage(w, http.StatusBadRequest, "la contraseña debe tener al menos 8 caracteres")
		return
	}
	clientID := chi.URLParam(r, "clientID")
	created, err := h.StaffManagement.Create(r.Context(), staff.User{
		ClientID: &clientID,
		Email:    req.Email,
		FullName: req.FullName,
		Role:     staff.Role(req.Role),
	}, req.Password)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromStaffUserResource(created))
}

func (h *Handler) updateStaffUser(w http.ResponseWriter, r *http.Request) {
	var req dto.UpdateStaffUserRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if !isAssignableStaffRole(req.Role) {
		writeErrorMessage(w, http.StatusBadRequest, "rol inválido")
		return
	}
	updated, err := h.StaffManagement.Update(r.Context(), staff.User{
		ID:       chi.URLParam(r, "userID"),
		FullName: req.FullName,
		Role:     staff.Role(req.Role),
	})
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromStaffUserResource(updated))
}

// setStaffUserActive — nunca permite que alguien se desactive a sí
// mismo (perdería acceso sin forma de revertirlo, mismo criterio que
// "un Admin Cliente no puede desactivar su propia empresa").
func (h *Handler) setStaffUserActive(w http.ResponseWriter, r *http.Request) {
	var req dto.SetActiveRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID := chi.URLParam(r, "userID")
	if !req.Active {
		if claims, ok := authmw.ClaimsFromContext(r.Context()); ok && claims.Subject == userID {
			writeErrorMessage(w, http.StatusBadRequest, "no puedes desactivar tu propia cuenta")
			return
		}
	}
	updated, err := h.StaffManagement.SetActive(r.Context(), userID, req.Active)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto.FromStaffUserResource(updated))
}

func (h *Handler) resetStaffUserPassword(w http.ResponseWriter, r *http.Request) {
	var req dto.ResetStaffUserPasswordRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.Password != req.ConfirmPassword {
		writeErrorMessage(w, http.StatusBadRequest, "las contraseñas no coinciden")
		return
	}
	if len(req.Password) < minStaffPasswordLength {
		writeErrorMessage(w, http.StatusBadRequest, "la contraseña debe tener al menos 8 caracteres")
		return
	}
	if err := h.StaffManagement.ResetPassword(r.Context(), chi.URLParam(r, "userID"), req.Password); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
