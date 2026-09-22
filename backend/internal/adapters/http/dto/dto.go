package dto

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/ledger"
)

// Card — ver backend/api/openapi.yaml, components.schemas.Card.
type Card struct {
	ID            string     `json:"id"`
	ClientID      string     `json:"clientId"`
	CardholderID  *string    `json:"cardholderId"`
	MaskedPAN     string     `json:"maskedPan"`
	Network       string     `json:"network"`
	ExpiryMonth   int        `json:"expiryMonth"`
	ExpiryYear    int        `json:"expiryYear"`
	Status        string     `json:"status"`
	BlockedReason *string    `json:"blockedReason"`
	AssignedAt    *time.Time `json:"assignedAt"`
}

func FromCard(c card.Card) Card {
	out := Card{
		ID:           c.ID,
		ClientID:     c.ClientID,
		CardholderID: c.CardholderID,
		MaskedPAN:    c.MaskedPAN,
		Network:      string(c.Network),
		ExpiryMonth:  c.ExpiryMonth,
		ExpiryYear:   c.ExpiryYear,
		Status:       string(c.Status),
		AssignedAt:   c.AssignedAt,
	}
	if c.BlockedReason != nil {
		reason := string(*c.BlockedReason)
		out.BlockedReason = &reason
	}
	return out
}

type LedgerEntry struct {
	ID           string    `json:"id"`
	Type         string    `json:"type"`
	Amount       float64   `json:"amount"`
	BalanceAfter float64   `json:"balanceAfter"`
	Description  string    `json:"description"`
	CreatedAt    time.Time `json:"createdAt"`
}

func FromLedgerEntry(e ledger.Entry) LedgerEntry {
	return LedgerEntry{
		ID:           e.ID,
		Type:         string(e.Type),
		Amount:       e.Amount,
		BalanceAfter: e.BalanceAfter,
		Description:  e.Description,
		CreatedAt:    e.CreatedAt,
	}
}

type LedgerView struct {
	Balance  float64       `json:"balance"`
	Currency string        `json:"currency"`
	Entries  []LedgerEntry `json:"entries"`
}

func FromLedger(account ledger.Account, entries []ledger.Entry) LedgerView {
	out := LedgerView{Balance: account.Balance, Currency: account.Currency, Entries: []LedgerEntry{}}
	for _, e := range entries {
		out.Entries = append(out.Entries, FromLedgerEntry(e))
	}
	return out
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// ActivationRequest — ver docs/adr/0019-cardholder-self-activation.md.
type ActivationRequest struct {
	Email            string `json:"email"`
	IDDocumentNumber string `json:"idDocumentNumber"`
	Password         string `json:"password"`
}

type LoginResponse struct {
	CardholderID string `json:"cardholderId"`
	Email        string `json:"email"`
	FullName     string `json:"fullName"`
	// AccessToken — JWT que cardholder/ debe mandar como
	// `Authorization: Bearer <token>` en cada petición posterior, ver
	// docs/adr/0013-jwt-session-authentication.md. Se llena en el
	// handler (dto.FromCardholder no conoce el emisor de tokens).
	AccessToken string `json:"accessToken"`
}

func FromCardholder(c cardholder.Cardholder) LoginResponse {
	email := ""
	if c.Email != nil {
		email = *c.Email
	}
	return LoginResponse{CardholderID: c.ID, Email: email, FullName: c.FullName}
}

type AssignRequest struct {
	CardholderID string `json:"cardholderId"`
}

type BlockStatusRequest struct {
	Blocked bool `json:"blocked"`
}

type SelfFreezeRequest struct {
	CardholderID string `json:"cardholderId"`
	Frozen       bool   `json:"frozen"`
}

type PostLedgerEntryRequest struct {
	Type        string  `json:"type"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
}

type ResolveTransferRequest struct {
	CardholderID string `json:"cardholderId"`
	OriginCardID string `json:"originCardId"`
	PAN          string `json:"pan"`
}

type ResolveTransferResponse struct {
	CardID         string `json:"cardId"`
	MaskedPAN      string `json:"maskedPan"`
	CardholderName string `json:"cardholderName"`
}

type ExecuteTransferRequest struct {
	OriginCardID      string  `json:"originCardId"`
	DestinationCardID string  `json:"destinationCardId"`
	Amount            float64 `json:"amount"`
}

type ErrorResponse struct {
	Message string `json:"message"`
	// Limit solo se llena para el error de límite de tarjetas activas —
	// el mensaje final que ve el usuario
	// (admin/lib/core/models/shared/card_limit_exceeded_exception.dart)
	// necesita el número exacto.
	Limit *int `json:"limit,omitempty"`
}
