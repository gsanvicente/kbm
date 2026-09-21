package handler_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/koons/kbm/backend/internal/adapters/auth/local"
	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	"github.com/koons/kbm/backend/internal/adapters/http/handler"
	memrepo "github.com/koons/kbm/backend/internal/adapters/memory/repository"
)

const testJWTSecret = "test-secret-do-not-use-in-prod"

func newTestServer() http.Handler {
	store := memrepo.NewStore()
	h := handler.New(store, store, store, store, local.NewTokenIssuer(testJWTSecret))
	h.StaffAuth = memrepo.NewStaffAuthStore(store)
	return h.Routes()
}

// cardholderToken loguea al Tarjetahabiente de prueba (Juan Perez, ver
// memory/repository/seed.go) y devuelve su JWT — la mayoría de los
// endpoints de cardholder/ ahora exigen sesión, ver
// docs/adr/0013-jwt-session-authentication.md.
func cardholderToken(t *testing.T, srv http.Handler) string {
	t.Helper()
	rec := postJSON(t, srv, "", "/v1/cardholder-sessions", dto.LoginRequest{
		Email: "juan.perez@cardholder.test", Password: "LocalDevOnly123!",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("cardholder login failed: %d: %s", rec.Code, rec.Body.String())
	}
	var resp dto.LoginResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode login response: %v", err)
	}
	if resp.AccessToken == "" {
		t.Fatalf("expected a non-empty accessToken")
	}
	return resp.AccessToken
}

func postJSON(t *testing.T, srv http.Handler, token, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	b, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	return rec
}

func getJSON(t *testing.T, srv http.Handler, token, path string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	return rec
}

func TestHealthz(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestLogin_SuccessAndFailure(t *testing.T) {
	srv := newTestServer()

	ok := postJSON(t, srv, "", "/v1/cardholder-sessions", dto.LoginRequest{
		Email: "juan.perez@cardholder.test", Password: "LocalDevOnly123!",
	})
	if ok.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", ok.Code, ok.Body.String())
	}
	var resp dto.LoginResponse
	if err := json.Unmarshal(ok.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.FullName != "Juan Perez" {
		t.Errorf("expected Juan Perez, got %q", resp.FullName)
	}
	if resp.AccessToken == "" {
		t.Errorf("expected a non-empty accessToken")
	}

	bad := postJSON(t, srv, "", "/v1/cardholder-sessions", dto.LoginRequest{
		Email: "juan.perez@cardholder.test", Password: "wrong",
	})
	if bad.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", bad.Code)
	}
}

func TestProtectedEndpoint_RequiresToken(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/v1/cards?cardholder_id=20000000-0000-0000-0000-000000000001", nil)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 without a token, got %d", rec.Code)
	}
}

func TestProtectedEndpoint_RejectsBadToken(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/v1/cards?cardholder_id=20000000-0000-0000-0000-000000000001", nil)
	req.Header.Set("Authorization", "Bearer not-a-real-token")
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with a garbage token, got %d", rec.Code)
	}
}

func TestListCards_RequiresAFilter(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	// Sin cardholder_id ni client_id se rechaza con 400 antes de llegar a
	// verificar propiedad — un token de Tarjetahabiente por sí solo no
	// implica ningún filtro implícito.
	req := httptest.NewRequest(http.MethodGet, "/v1/cards", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 without cardholder_id/client_id, got %d", rec.Code)
	}
}

func TestListCards_ByCardholder(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	rec := getJSON(t, srv, token, "/v1/cards?cardholder_id=20000000-0000-0000-0000-000000000001")
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var cards []dto.Card
	if err := json.Unmarshal(rec.Body.Bytes(), &cards); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(cards) != 1 || cards[0].MaskedPAN != "**** **** **** 1234" {
		t.Errorf("expected exactly Juan Perez's one card, got %+v", cards)
	}
}

// TestListCards_RejectsOtherCardholder — un Tarjetahabiente autenticado
// no puede leer las tarjetas de otro simplemente cambiando el
// query-param, ver docs/adr/0013-jwt-session-authentication.md.
func TestListCards_RejectsOtherCardholder(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	rec := getJSON(t, srv, token, "/v1/cards?cardholder_id=20000000-0000-0000-0000-000000000002")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 (generic, never reveals mismatch), got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestTransferFlow_ResolveThenExecute(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	const juanCard = "40000000-0000-0000-0000-000000000001"
	const anaPAN = "5500000000005566"

	resolve := postJSON(t, srv, token, "/v1/transfers/resolve", dto.ResolveTransferRequest{
		CardholderID: "20000000-0000-0000-0000-000000000001",
		OriginCardID: juanCard,
		PAN:          anaPAN,
	})
	if resolve.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", resolve.Code, resolve.Body.String())
	}
	var resolved dto.ResolveTransferResponse
	if err := json.Unmarshal(resolve.Body.Bytes(), &resolved); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resolved.CardholderName != "Ana Torres" {
		t.Fatalf("expected Ana Torres, got %q", resolved.CardholderName)
	}

	execute := postJSON(t, srv, token, "/v1/transfers/execute", dto.ExecuteTransferRequest{
		OriginCardID:      juanCard,
		DestinationCardID: resolved.CardID,
		Amount:            50,
	})
	if execute.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", execute.Code, execute.Body.String())
	}
}

func TestTransferResolve_UnknownPANReturnsGenericNotFound(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	rec := postJSON(t, srv, token, "/v1/transfers/resolve", dto.ResolveTransferRequest{
		CardholderID: "20000000-0000-0000-0000-000000000001",
		OriginCardID: "40000000-0000-0000-0000-000000000001",
		PAN:          "0000000000000000",
	})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestTransferResolve_RejectsOtherCardholdersID(t *testing.T) {
	srv := newTestServer()
	token := cardholderToken(t, srv)
	rec := postJSON(t, srv, token, "/v1/transfers/resolve", dto.ResolveTransferRequest{
		CardholderID: "20000000-0000-0000-0000-000000000002",
		OriginCardID: "40000000-0000-0000-0000-000000000001",
		PAN:          "5500000000005566",
	})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 (generic, never reveals mismatch), got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestStaffLogin_IssuesTokenForStaffOnlyEndpoint(t *testing.T) {
	srv := newTestServer()
	login := postJSON(t, srv, "", "/v1/staff-sessions", dto.StaffLoginRequest{
		Email: "super.admin@koons.test", Password: "LocalDevOnly123!",
	})
	if login.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", login.Code, login.Body.String())
	}
	var resp dto.StaffLoginResponse
	if err := json.Unmarshal(login.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.AccessToken == "" {
		t.Fatalf("expected a non-empty accessToken")
	}

	// Un token de Tarjetahabiente no puede usar un endpoint solo-staff.
	cardholderTok := cardholderToken(t, srv)
	forbidden := postJSON(t, srv, cardholderTok, "/v1/cards/40000000-0000-0000-0000-000000000001/block-status", dto.BlockStatusRequest{Blocked: true})
	if forbidden.Code != http.StatusForbidden {
		t.Fatalf("expected 403 for a cardholder token on a staff-only endpoint, got %d: %s", forbidden.Code, forbidden.Body.String())
	}

	allowed := postJSON(t, srv, resp.AccessToken, "/v1/cards/40000000-0000-0000-0000-000000000001/block-status", dto.BlockStatusRequest{Blocked: true})
	if allowed.Code != http.StatusOK {
		t.Fatalf("expected 200 for a staff token on a staff-only endpoint, got %d: %s", allowed.Code, allowed.Body.String())
	}
}
