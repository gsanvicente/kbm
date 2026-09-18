package handler_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/koons/kbm/backend/internal/adapters/http/dto"
	"github.com/koons/kbm/backend/internal/adapters/http/handler"
	memrepo "github.com/koons/kbm/backend/internal/adapters/memory/repository"
)

func newTestServer() http.Handler {
	store := memrepo.NewStore()
	return handler.New(store, store, store, store).Routes()
}

func postJSON(t *testing.T, srv http.Handler, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	b, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
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

	ok := postJSON(t, srv, "/v1/cardholder-sessions", dto.LoginRequest{
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

	bad := postJSON(t, srv, "/v1/cardholder-sessions", dto.LoginRequest{
		Email: "juan.perez@cardholder.test", Password: "wrong",
	})
	if bad.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", bad.Code)
	}
}

func TestListCards_RequiresAFilter(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/v1/cards", nil)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 without cardholder_id/client_id, got %d", rec.Code)
	}
}

func TestListCards_ByCardholder(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/v1/cards?cardholder_id=20000000-0000-0000-0000-000000000001", nil)
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
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

func TestTransferFlow_ResolveThenExecute(t *testing.T) {
	srv := newTestServer()
	const juanCard = "40000000-0000-0000-0000-000000000001"
	const anaPAN = "5500000000005566"

	resolve := postJSON(t, srv, "/v1/transfers/resolve", dto.ResolveTransferRequest{
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

	execute := postJSON(t, srv, "/v1/transfers/execute", dto.ExecuteTransferRequest{
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
	rec := postJSON(t, srv, "/v1/transfers/resolve", dto.ResolveTransferRequest{
		CardholderID: "20000000-0000-0000-0000-000000000001",
		OriginCardID: "40000000-0000-0000-0000-000000000001",
		PAN:          "0000000000000000",
	})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}
