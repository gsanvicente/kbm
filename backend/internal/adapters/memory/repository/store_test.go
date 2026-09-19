package repository

import (
	"context"
	"errors"
	"testing"

	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

const (
	juanCard   = "40000000-0000-0000-0000-000000000001" // Juan Perez, Koons Subsidiaria A
	mariaCard  = "40000000-0000-0000-0000-000000000002" // Maria Gomez, Koons Subsidiaria B
	carlosCard = "40000000-0000-0000-0000-000000000004" // Carlos Ruiz, blocked, Subsidiaria B
	poolCardA1 = "40000000-0000-0000-0000-000000000005" // Subsidiaria A, unassigned
	poolCardA2 = "40000000-0000-0000-0000-000000000006" // Subsidiaria A, unassigned
	poolCardB1 = "40000000-0000-0000-0000-000000000007" // Subsidiaria B, unassigned
	anaCard    = "40000000-0000-0000-0000-000000000010" // Ana Torres, Subsidiaria A

	juanID  = "20000000-0000-0000-0000-000000000001"
	mariaID = "20000000-0000-0000-0000-000000000002"
	anaID   = "20000000-0000-0000-0000-000000000003"

	juanPAN = "4111111111111234"
	anaPAN  = "5500000000005566"
)

func TestAssign_Success(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	// poolCardB1 is in Subsidiaria B, which allows 2 active cards per
	// cardholder — a brand new cardholder ID has room for one.
	const newCardholderID = "20000000-0000-0000-0000-000000000999"
	got, err := s.Assign(ctx, poolCardB1, newCardholderID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Status != card.StatusActive {
		t.Errorf("expected StatusActive, got %v", got.Status)
	}
	if got.CardholderID == nil || *got.CardholderID != newCardholderID {
		t.Errorf("expected cardholderID %s, got %v", newCardholderID, got.CardholderID)
	}

	account, _, err := s.GetByCard(ctx, poolCardB1)
	if err != nil {
		t.Fatalf("expected a ledger account to exist after assignment: %v", err)
	}
	if account.Balance != 0 {
		t.Errorf("expected a freshly assigned card to start at 0 balance, got %v", account.Balance)
	}
}

func TestAssign_RejectsWhenCardLimitReached(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	// Subsidiaria A allows only 1 active card per cardholder, and Juan
	// already has one (juanCard) — assigning a second must be rejected.
	_, err := s.Assign(ctx, poolCardA1, juanID)
	if !errors.Is(err, shared.ErrCardLimitExceeded) {
		t.Fatalf("expected ErrCardLimitExceeded, got %v", err)
	}
	var limitErr *shared.CardLimitExceededError
	if !errors.As(err, &limitErr) || limitErr.Limit != 1 {
		t.Fatalf("expected the error to carry limit=1, got %+v", limitErr)
	}
}

func TestAssign_DefaultLimitAppliesWhenClientHasNoOverride(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	// Cliente sintético, ausente de seedCardLimits() — debe usar
	// defaultMaxActiveCardsPerCardholder (1), no "sin límite".
	const clientC = "00000000-0000-0000-0000-000000000099"
	const cardholderID = "20000000-0000-0000-0000-000000000998"
	const firstCard = "40000000-0000-0000-0000-000000000099"
	const secondCard = "40000000-0000-0000-0000-000000000098"
	s.cards[firstCard] = card.Card{
		ID: firstCard, ClientID: clientC, MaskedPAN: "**** **** **** 9999",
		Network: card.NetworkVisa, ExpiryMonth: 1, ExpiryYear: 2030, Status: card.StatusUnassigned,
	}
	s.cards[secondCard] = card.Card{
		ID: secondCard, ClientID: clientC, MaskedPAN: "**** **** **** 9998",
		Network: card.NetworkVisa, ExpiryMonth: 1, ExpiryYear: 2030, Status: card.StatusUnassigned,
	}

	if _, err := s.Assign(ctx, firstCard, cardholderID); err != nil {
		t.Fatalf("unexpected error assigning the first card: %v", err)
	}
	_, err := s.Assign(ctx, secondCard, cardholderID)
	var limitErr *shared.CardLimitExceededError
	if !errors.As(err, &limitErr) || limitErr.Limit != 1 {
		t.Fatalf("expected the default limit of 1 to reject the second card, got err=%v", err)
	}
}

func TestAssign_RejectsUnavailableCard(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	_, err := s.Assign(ctx, juanCard, anaID) // already assigned to Juan
	if !errors.Is(err, shared.ErrCardNotAvailable) {
		t.Fatalf("expected ErrCardNotAvailable, got %v", err)
	}
}

func TestSetBlocked_ManualReason(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	blocked, err := s.SetBlocked(ctx, juanCard, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if blocked.Status != card.StatusBlocked || blocked.BlockedReason == nil || *blocked.BlockedReason != card.BlockedReasonManual {
		t.Errorf("expected manual block, got status=%v reason=%v", blocked.Status, blocked.BlockedReason)
	}

	unblocked, err := s.SetBlocked(ctx, juanCard, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if unblocked.Status != card.StatusActive || unblocked.BlockedReason != nil {
		t.Errorf("expected active with no reason, got status=%v reason=%v", unblocked.Status, unblocked.BlockedReason)
	}
}

func TestFreezeAllForCardholder_SkipsAlreadyBlocked(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	// Carlos Ruiz's card starts out blocked (manual, from seed data) — it
	// must not be touched by a freeze, per
	// docs/business/desactivacion-de-tarjetahabientes.md.
	err := s.FreezeAllForCardholder(ctx, "20000000-0000-0000-0000-000000000004")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	c, _ := s.GetByID(ctx, carlosCard)
	if c.BlockedReason == nil || *c.BlockedReason != card.BlockedReasonManual {
		t.Errorf("expected the pre-existing manual reason to survive, got %v", c.BlockedReason)
	}

	// Ana Torres's card starts active — freezing must flip it with the
	// cardholder-inactive reason.
	if err := s.FreezeAllForCardholder(ctx, anaID); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	frozen, _ := s.GetByID(ctx, anaCard)
	if frozen.Status != card.StatusBlocked || frozen.BlockedReason == nil || *frozen.BlockedReason != card.BlockedReasonCardholderInactive {
		t.Errorf("expected cardholder_inactive block, got status=%v reason=%v", frozen.Status, frozen.BlockedReason)
	}
}

func TestPostEntry_InsufficientFundsLeavesBalanceUntouched(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	before, _, _ := s.GetByCard(ctx, juanCard)

	_, err := s.PostEntry(ctx, juanCard, ledger.EntryDebit, before.Balance+1, "over the limit")
	if !errors.Is(err, shared.ErrInsufficientFunds) {
		t.Fatalf("expected ErrInsufficientFunds, got %v", err)
	}

	after, _, _ := s.GetByCard(ctx, juanCard)
	if after.Balance != before.Balance {
		t.Errorf("balance changed after a failed debit: before=%v after=%v", before.Balance, after.Balance)
	}
}

func TestPostEntry_CreditThenDebit(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	before, _, _ := s.GetByCard(ctx, anaCard)

	if _, err := s.PostEntry(ctx, anaCard, ledger.EntryCredit, 50, "test credit"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	afterCredit, entries, _ := s.GetByCard(ctx, anaCard)
	if afterCredit.Balance != before.Balance+50 {
		t.Errorf("expected balance %v, got %v", before.Balance+50, afterCredit.Balance)
	}
	if len(entries) == 0 {
		t.Error("expected at least one entry after posting")
	}

	if _, err := s.PostEntry(ctx, anaCard, ledger.EntryDebit, 20, "test debit"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	afterDebit, _, _ := s.GetByCard(ctx, anaCard)
	if afterDebit.Balance != before.Balance+30 {
		t.Errorf("expected balance %v, got %v", before.Balance+30, afterDebit.Balance)
	}
}

func TestLogin_Success(t *testing.T) {
	s := NewStore()
	ch, err := s.Login(context.Background(), "juan.perez@cardholder.test", "LocalDevOnly123!")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ch.ID != juanID {
		t.Errorf("expected cardholder %s, got %s", juanID, ch.ID)
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	s := NewStore()
	_, err := s.Login(context.Background(), "juan.perez@cardholder.test", "wrong")
	if !errors.Is(err, shared.ErrInvalidCredentials) {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestLogin_InactiveCardholderGetsGenericError(t *testing.T) {
	s := NewStore()
	_, err := s.Login(context.Background(), "inactivo@cardholder.test", "LocalDevOnly123!")
	if !errors.Is(err, shared.ErrInvalidCredentials) {
		t.Fatalf("expected the same generic ErrInvalidCredentials as a wrong password, got %v", err)
	}
}

func TestResolveDestination_Success(t *testing.T) {
	s := NewStore()
	resolved, err := s.ResolveDestination(context.Background(), juanID, juanCard, anaPAN)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resolved == nil {
		t.Fatal("expected a match, got nil")
	}
	if resolved.Card.ID != anaCard || resolved.CardholderName != "Ana Torres" {
		t.Errorf("expected Ana Torres's card, got %+v", resolved)
	}
}

func TestResolveDestination_DifferentClientResolvesToNothing(t *testing.T) {
	s := NewStore()
	// mariaCard belongs to Subsidiaria B, juanCard to Subsidiaria A.
	resolved, err := s.ResolveDestination(context.Background(), juanID, juanCard, "5500000000005678")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resolved != nil {
		t.Errorf("expected no match across clients, got %+v", resolved)
	}
}

func TestResolveDestination_OwnCardResolvesToNothing(t *testing.T) {
	s := NewStore()
	resolved, err := s.ResolveDestination(context.Background(), juanID, juanCard, juanPAN)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resolved != nil {
		t.Errorf("expected no match for one's own card, got %+v", resolved)
	}
}

func TestResolveDestination_LocksAfterFiveFailedAttempts(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	for i := 0; i < 4; i++ {
		resolved, err := s.ResolveDestination(ctx, juanID, juanCard, "0000000000000000")
		if err != nil {
			t.Fatalf("attempt %d: unexpected error: %v", i+1, err)
		}
		if resolved != nil {
			t.Fatalf("attempt %d: expected no match", i+1)
		}
	}

	// 5th failed attempt: locked right away, per
	// docs/feature/transferencia-c2c-tarjetahabiente/README.md.
	_, err := s.ResolveDestination(ctx, juanID, juanCard, "0000000000000000")
	if !errors.Is(err, shared.ErrTooManyFailedAttempts) {
		t.Fatalf("expected ErrTooManyFailedAttempts on the 5th failure, got %v", err)
	}

	// A 6th attempt, even with a valid destination, stays locked.
	_, err = s.ResolveDestination(ctx, juanID, juanCard, anaPAN)
	if !errors.Is(err, shared.ErrTooManyFailedAttempts) {
		t.Fatalf("expected the lock to persist for a subsequent attempt, got %v", err)
	}
}

func TestTransferExecute_MovesBothBalances(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	beforeOrigin, _, _ := s.GetByCard(ctx, juanCard)
	beforeDestination, _, _ := s.GetByCard(ctx, anaCard)

	if err := s.Execute(ctx, juanCard, anaCard, 100); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	afterOrigin, _, _ := s.GetByCard(ctx, juanCard)
	afterDestination, _, _ := s.GetByCard(ctx, anaCard)

	if afterOrigin.Balance != beforeOrigin.Balance-100 {
		t.Errorf("expected origin balance %v, got %v", beforeOrigin.Balance-100, afterOrigin.Balance)
	}
	if afterDestination.Balance != beforeDestination.Balance+100 {
		t.Errorf("expected destination balance %v, got %v", beforeDestination.Balance+100, afterDestination.Balance)
	}
}

func TestTransferExecute_InsufficientFundsTouchesNeitherBalance(t *testing.T) {
	s := NewStore()
	ctx := context.Background()

	beforeOrigin, _, _ := s.GetByCard(ctx, juanCard)
	beforeDestination, _, _ := s.GetByCard(ctx, anaCard)

	err := s.Execute(ctx, juanCard, anaCard, beforeOrigin.Balance+1)
	if !errors.Is(err, shared.ErrInsufficientFunds) {
		t.Fatalf("expected ErrInsufficientFunds, got %v", err)
	}

	afterOrigin, _, _ := s.GetByCard(ctx, juanCard)
	afterDestination, _, _ := s.GetByCard(ctx, anaCard)
	if afterOrigin.Balance != beforeOrigin.Balance || afterDestination.Balance != beforeDestination.Balance {
		t.Error("a failed transfer must never touch either balance")
	}
}
