package repository

import (
	"fmt"
	"time"

	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	"github.com/koons/kbm/backend/internal/domain/ledger"
)

// IDs y valores sembrados aquí coinciden, donde ya existían, con
// admin/lib/features/cards/fake_card_repository.dart y
// admin/lib/features/ledger/fake_ledger_repository.dart — puramente por
// continuidad narrativa del demo (ver
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md), no hay
// ninguna relación técnica real entre esos repositorios Dart y este
// backend. Reconciliar completamente ambos universos de datos (y
// actualizar las pruebas de admin/cardholder que dependan de valores
// exactos) es el siguiente paso, cuando esas apps se conecten aquí.
const (
	clientA = "00000000-0000-0000-0000-000000000002" // Koons Subsidiaria A
	clientB = "00000000-0000-0000-0000-000000000003" // Koons Subsidiaria B
)

func strPtr(s string) *string { return &s }

func seedCards() map[string]card.Card {
	juan := "20000000-0000-0000-0000-000000000001"
	maria := "20000000-0000-0000-0000-000000000002"
	anaTorres := "20000000-0000-0000-0000-000000000003"
	carlos := "20000000-0000-0000-0000-000000000004"

	manual := card.BlockedReasonManual
	assignedJuan := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	assignedMaria := time.Date(2026, 1, 12, 0, 0, 0, 0, time.UTC)
	assignedCarlos := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	assignedAna := time.Date(2026, 1, 22, 0, 0, 0, 0, time.UTC)

	cards := []card.Card{
		{
			ID: "40000000-0000-0000-0000-000000000001", ClientID: clientA, CardholderID: strPtr(juan),
			MaskedPAN: "**** **** **** 1234", Network: card.NetworkVisa, ExpiryMonth: 8, ExpiryYear: 2027,
			Status: card.StatusActive, AssignedAt: &assignedJuan,
		},
		{
			ID: "40000000-0000-0000-0000-000000000002", ClientID: clientB, CardholderID: strPtr(maria),
			MaskedPAN: "**** **** **** 5678", Network: card.NetworkMastercard, ExpiryMonth: 3, ExpiryYear: 2026,
			Status: card.StatusActive, AssignedAt: &assignedMaria,
		},
		{
			ID: "40000000-0000-0000-0000-000000000004", ClientID: clientB, CardholderID: strPtr(carlos),
			MaskedPAN: "**** **** **** 7890", Network: card.NetworkVisa, ExpiryMonth: 11, ExpiryYear: 2026,
			Status: card.StatusBlocked, BlockedReason: &manual, AssignedAt: &assignedCarlos,
		},
		// Pool disponible.
		{
			ID: "40000000-0000-0000-0000-000000000005", ClientID: clientA,
			MaskedPAN: "**** **** **** 2001", Network: card.NetworkVisa, ExpiryMonth: 5, ExpiryYear: 2028,
			Status: card.StatusUnassigned,
		},
		{
			ID: "40000000-0000-0000-0000-000000000006", ClientID: clientA,
			MaskedPAN: "**** **** **** 2002", Network: card.NetworkMastercard, ExpiryMonth: 9, ExpiryYear: 2028,
			Status: card.StatusUnassigned,
		},
		{
			ID: "40000000-0000-0000-0000-000000000007", ClientID: clientB,
			MaskedPAN: "**** **** **** 3001", Network: card.NetworkVisa, ExpiryMonth: 1, ExpiryYear: 2029,
			Status: card.StatusUnassigned,
		},
		{
			ID: "40000000-0000-0000-0000-000000000008", ClientID: clientB,
			MaskedPAN: "**** **** **** 3002", Network: card.NetworkMastercard, ExpiryMonth: 7, ExpiryYear: 2027,
			Status: card.StatusUnassigned,
		},
		// Nueva — necesaria para que Juan Perez tenga un destino válido de
		// transferencia C2C dentro de su mismo Cliente (Koons Subsidiaria
		// A). admin/'s fixture de "Ana Torres sin tarjetas" (pensada para
		// probar el estado vacío del pool) queda desactualizada por esto
		// — se corrige cuando admin/ se conecte a este backend.
		{
			ID: "40000000-0000-0000-0000-000000000010", ClientID: clientA, CardholderID: strPtr(anaTorres),
			MaskedPAN: "**** **** **** 5566", Network: card.NetworkMastercard, ExpiryMonth: 2, ExpiryYear: 2028,
			Status: card.StatusActive, AssignedAt: &assignedAna,
		},
	}

	out := make(map[string]card.Card, len(cards))
	for _, c := range cards {
		out[c.ID] = c
	}
	return out
}

// fullPANByCardID — PAN completo sintético por tarjeta, solo para
// calcular su hash al arrancar. Nunca se expone fuera de este paquete —
// ver docs/adr/0009-pan-hash-transit-for-c2c-transfers.md.
var fullPANByCardID = map[string]string{
	"40000000-0000-0000-0000-000000000001": "4111111111111234",
	"40000000-0000-0000-0000-000000000002": "5500000000005678",
	"40000000-0000-0000-0000-000000000004": "4111111111117890",
	"40000000-0000-0000-0000-000000000010": "5500000000005566",
}

func (s *Store) seedPANHashes() {
	for id, pan := range fullPANByCardID {
		s.panHashByCardID[id] = hashPAN(pan)
	}
}

func seedCardholders() map[string]cardholder.Cardholder {
	const devPassword = "LocalDevOnly123!"
	cardholders := []cardholder.Cardholder{
		{
			ID: "20000000-0000-0000-0000-000000000001", ClientID: clientA,
			FullName: "Juan Perez", Email: "juan.perez@cardholder.test", Password: devPassword, IsActive: true,
		},
		{
			ID: "20000000-0000-0000-0000-000000000002", ClientID: clientB,
			FullName: "Maria Gomez", Email: "maria.gomez@cardholder.test", Password: devPassword, IsActive: true,
		},
		{
			ID: "20000000-0000-0000-0000-000000000003", ClientID: clientA,
			FullName: "Ana Torres", Email: "ana.torres@cardholder.test", Password: devPassword, IsActive: true,
		},
		{
			ID: "20000000-0000-0000-0000-000000000004", ClientID: clientB,
			FullName: "Carlos Ruiz", Email: "carlos.ruiz@cardholder.test", Password: devPassword, IsActive: true,
		},
		// Cuenta de demo dedicada a ejercer la Capa 1 de
		// docs/business/desactivacion-de-tarjetahabientes.md.
		{
			ID: "20000000-0000-0000-0000-000000000099", ClientID: clientA,
			FullName: "Tarjetahabiente Inactivo (demo)", Email: "inactivo@cardholder.test",
			Password: devPassword, IsActive: false,
		},
	}
	out := make(map[string]cardholder.Cardholder, len(cardholders))
	for _, c := range cardholders {
		out[c.ID] = c
	}
	return out
}

// Solo overrides explícitos — cualquier Cliente ausente de este mapa usa
// defaultMaxActiveCardsPerCardholder (1, ver store.go Assign()).
// Subsidiaria A no necesita entrada, ya está al default; Subsidiaria B
// tiene espacio (2) a propósito, para demostrar que sí varía por Cliente
// — mismo criterio que admin/lib/features/cards/fake_card_repository.dart.
func seedCardLimits() map[string]int {
	return map[string]int{
		clientB: 2,
	}
}

func (s *Store) seedLedger() {
	type seededEntry struct {
		cardID      string
		entryType   ledger.EntryType
		amount      float64
		description string
		createdAt   time.Time
	}

	seeds := []seededEntry{
		{"40000000-0000-0000-0000-000000000001", ledger.EntryCredit, 1000.00, "Carga inicial", time.Date(2026, 1, 10, 9, 0, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000001", ledger.EntryDebit, 150.00, "Compra en restaurante", time.Date(2026, 1, 15, 14, 30, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000001", ledger.EntryCredit, 400.00, "Carga de fondos", time.Date(2026, 1, 20, 10, 0, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000002", ledger.EntryCredit, 500.00, "Carga inicial", time.Date(2026, 1, 12, 9, 0, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000002", ledger.EntryDebit, 159.50, "Compra en línea", time.Date(2026, 1, 18, 16, 45, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000004", ledger.EntryCredit, 75.00, "Carga inicial", time.Date(2026, 1, 15, 9, 0, 0, 0, time.UTC)},
		{"40000000-0000-0000-0000-000000000010", ledger.EntryCredit, 300.00, "Carga inicial", time.Date(2026, 1, 22, 9, 0, 0, 0, time.UTC)},
	}

	for i, seed := range seeds {
		account, ok := s.accounts[seed.cardID]
		if !ok {
			account = ledger.Account{CardID: seed.cardID, Currency: "MXN"}
		}
		if seed.entryType == ledger.EntryCredit {
			account.Balance += seed.amount
		} else {
			account.Balance -= seed.amount
		}
		s.accounts[seed.cardID] = account
		s.entries[seed.cardID] = append(s.entries[seed.cardID], ledger.Entry{
			ID:           seedEntryID(i),
			CardID:       seed.cardID,
			Type:         seed.entryType,
			Amount:       seed.amount,
			BalanceAfter: account.Balance,
			Description:  seed.description,
			CreatedAt:    seed.createdAt,
		})
	}
}

func seedEntryID(i int) string {
	return fmt.Sprintf("60000000-0000-0000-0000-%012d", i+1)
}
