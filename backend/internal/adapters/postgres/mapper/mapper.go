// Package mapper translates between sqlc-generated row structs and domain
// entities in both directions. Domain types never depend on generated SQL
// structs — see docs/tdr/0001-sqlc-pgx-over-orm.md.
package mapper

import (
	"time"

	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/domain/account"
	"github.com/koons/kbm/backend/internal/domain/approval"
	"github.com/koons/kbm/backend/internal/domain/beneficiary"
	"github.com/koons/kbm/backend/internal/domain/card"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	kbmclient "github.com/koons/kbm/backend/internal/domain/client"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/speipayment"
	"github.com/koons/kbm/backend/internal/domain/staff"
	"github.com/koons/kbm/backend/internal/domain/treasury"
)

func strOrDefault(s *string, def string) string {
	if s == nil {
		return def
	}
	return *s
}

func floatOrZero(f *float64) float64 {
	if f == nil {
		return 0
	}
	return *f
}

// CardRow mirrors the exact column list every query in
// internal/adapters/postgres/sqlc/queries/cards.sql selects (same names,
// types and order). sqlc generates one distinct (but structurally
// identical) Row struct per query rather than reusing one — callers
// convert their query's *Row type to this one with a plain Go struct
// conversion (valid because the underlying layouts match) before calling
// ToCard, instead of this package depending on every generated type.
type CardRow struct {
	ID              string
	ClientID        string
	CardholderID    *string
	AccountID       *string
	MaskedPan       string
	Network         sqlcgen.CardNetwork
	ExpiryMonth     int16
	ExpiryYear      int16
	Status          sqlcgen.CardStatus
	BlockedReason   sqlcgen.NullCardBlockedReason
	CancelledReason *string
	AssignedAt      *time.Time
}

func ToCard(r CardRow) card.Card {
	c := card.Card{
		ID:           r.ID,
		ClientID:     r.ClientID,
		CardholderID: r.CardholderID,
		AccountID:    r.AccountID,
		MaskedPAN:    r.MaskedPan,
		Network:      card.Network(r.Network),
		ExpiryMonth:  int(r.ExpiryMonth),
		ExpiryYear:   int(r.ExpiryYear),
		Status:       card.Status(r.Status),
		AssignedAt:   r.AssignedAt,
	}
	if r.BlockedReason.Valid {
		reason := card.BlockedReason(r.BlockedReason.CardBlockedReason)
		c.BlockedReason = &reason
	}
	if r.CancelledReason != nil {
		reason := card.CancelledReason(*r.CancelledReason)
		c.CancelledReason = &reason
	}
	return c
}

// ToAccount toma sqlcgen.IndividualAccount directamente (no un "Row"
// intermedio, a diferencia de CardRow): todo query en
// internal/adapters/postgres/sqlc/queries/accounts.sql hace
// RETURNING/SELECT de la fila completa, así que sqlc ya reusa ese único
// tipo generado en vez de emitir uno distinto por query. Clabe es
// pgtype.Text (no el override de *string, que solo aplica a columnas
// `text` — esta es `char(18)`), de ahí la conversión explícita.
func ToAccount(r sqlcgen.IndividualAccount) account.Account {
	a := account.Account{
		ID:           r.ID,
		ClientID:     r.ClientID,
		CardholderID: r.CardholderID,
	}
	if r.Clabe.Valid {
		a.CLABE = &r.Clabe.String
	}
	return a
}

// ToCardholderFromLogin — la fila de GetCardholderForLogin trae solo lo
// mínimo para verificar credenciales; Email se llena con el correo de
// login usado (email), no con el contacto KYC nullable de la fila (que
// podría estar vacío o no coincidir) — ver
// internal/adapters/postgres/repository/auth.go.
func ToCardholderFromLogin(id, clientID, fullName, email string, isActive bool) cardholder.Cardholder {
	return cardholder.Cardholder{
		ID:       id,
		ClientID: clientID,
		FullName: fullName,
		Email:    &email,
		IsActive: isActive,
	}
}

// CardholderRow mirrors the exact column list every cardholder-management
// query in cardholders.sql selects — same reasoning as CardRow above.
// Email is a plain string (not *string) since
// docs/adr/0019-cardholder-self-activation.md made cardholders.email
// NOT NULL — sqlc regenerates it that way for every query selecting the
// column, so this must match exactly for the raw struct conversion below
// to compile.
type CardholderRow struct {
	ID                   string
	ClientID             string
	FullName             string
	IDDocumentType       sqlcgen.IDDocumentType
	IDDocumentNumber     string
	Curp                 *string
	Rfc                  *string
	DateOfBirth          *time.Time
	Nationality          *string
	AddressStreet        *string
	AddressNeighborhood  *string
	AddressCity          *string
	AddressState         *string
	AddressPostalCode    *string
	AddressCountry       *string
	IsPoliticallyExposed bool
	Email                string
	Phone                *string
	IsActive             bool
}

func ToCardholder(r CardholderRow) cardholder.Cardholder {
	return cardholder.Cardholder{
		ID:                   r.ID,
		ClientID:             r.ClientID,
		FullName:             r.FullName,
		IDDocumentType:       shared.IDDocumentType(r.IDDocumentType),
		IDDocumentNumber:     r.IDDocumentNumber,
		CURP:                 r.Curp,
		RFC:                  r.Rfc,
		DateOfBirth:          r.DateOfBirth,
		Nationality:          strOrDefault(r.Nationality, "Mexicana"),
		AddressStreet:        r.AddressStreet,
		AddressNeighborhood:  r.AddressNeighborhood,
		AddressCity:          r.AddressCity,
		AddressState:         r.AddressState,
		AddressPostalCode:    r.AddressPostalCode,
		AddressCountry:       strOrDefault(r.AddressCountry, "México"),
		IsPoliticallyExposed: r.IsPoliticallyExposed,
		Email:                &r.Email,
		Phone:                r.Phone,
		IsActive:             r.IsActive,
	}
}

// ClientRow mirrors the exact column list every query in clients.sql
// selects for the base Client row (without Apoderados/Beneficiarios,
// attached separately by the caller — see repository/client.go).
type ClientRow struct {
	ID                  string
	Name                string
	ParentClientID      *string
	IsActive            bool
	RazonSocial         *string
	NombreComercial     *string
	Rfc                 *string
	FechaConstitucion   *time.Time
	ObjetoSocial        *string
	ActaNumeroEscritura *string
	ActaNotario         *string
	ActaPlaza           *string
	ActaFecha           *time.Time
	ActaFolioRpc        *string
	AddressStreet       *string
	AddressNeighborhood *string
	AddressCity         *string
	AddressState        *string
	AddressPostalCode   *string
	AddressCountry      *string
}

func ToClient(r ClientRow, apoderados []kbmclient.ApoderadoLegal, beneficiarios []kbmclient.BeneficiarioControlador) kbmclient.Client {
	c := kbmclient.Client{
		ID:                         r.ID,
		Name:                       r.Name,
		ParentClientID:             r.ParentClientID,
		IsActive:                   r.IsActive,
		RazonSocial:                r.RazonSocial,
		NombreComercial:            r.NombreComercial,
		RFC:                        r.Rfc,
		FechaConstitucion:          r.FechaConstitucion,
		ObjetoSocial:               r.ObjetoSocial,
		AddressStreet:              r.AddressStreet,
		AddressNeighborhood:        r.AddressNeighborhood,
		AddressCity:                r.AddressCity,
		AddressState:               r.AddressState,
		AddressPostalCode:          r.AddressPostalCode,
		AddressCountry:             strOrDefault(r.AddressCountry, "México"),
		Apoderados:                 apoderados,
		BeneficiariosControladores: beneficiarios,
	}
	if r.ActaNumeroEscritura != nil && r.ActaNotario != nil && r.ActaPlaza != nil && r.ActaFecha != nil && r.ActaFolioRpc != nil {
		c.ActaConstitutiva = &kbmclient.ActaConstitutiva{
			NumeroEscritura: *r.ActaNumeroEscritura,
			Notario:         *r.ActaNotario,
			Plaza:           *r.ActaPlaza,
			Fecha:           *r.ActaFecha,
			FolioRPC:        *r.ActaFolioRpc,
		}
	}
	return c
}

// ApoderadoRow mirrors ListApoderadosByClientRow / CreateApoderadoRow.
type ApoderadoRow struct {
	ID                       string
	ClientID                 string
	FullName                 string
	IDDocumentType           sqlcgen.IDDocumentType
	IDDocumentNumber         string
	Curp                     *string
	Rfc                      *string
	TipoPoder                sqlcgen.ClientTipoPoder
	DescripcionPoderEspecial *string
	NumeroEscritura          string
	Notario                  string
	FechaInstrumento         time.Time
	Vigencia                 *time.Time
	EsPrincipal              bool
}

func ToApoderado(r ApoderadoRow) kbmclient.ApoderadoLegal {
	return kbmclient.ApoderadoLegal{
		ID: r.ID,
		Persona: shared.PersonaFisica{
			FullName:         r.FullName,
			IDDocumentType:   shared.IDDocumentType(r.IDDocumentType),
			IDDocumentNumber: r.IDDocumentNumber,
			CURP:             r.Curp,
			RFC:              r.Rfc,
		},
		TipoPoder:                kbmclient.TipoPoder(r.TipoPoder),
		DescripcionPoderEspecial: r.DescripcionPoderEspecial,
		NumeroEscritura:          r.NumeroEscritura,
		Notario:                  r.Notario,
		FechaInstrumento:         r.FechaInstrumento,
		Vigencia:                 r.Vigencia,
		EsPrincipal:              r.EsPrincipal,
	}
}

// BeneficiarioRow mirrors ListBeneficiariosByClientRow / CreateBeneficiarioRow.
type BeneficiarioRow struct {
	ID                      string
	ClientID                string
	FullName                string
	IDDocumentType          sqlcgen.IDDocumentType
	IDDocumentNumber        string
	Curp                    *string
	Rfc                     *string
	PorcentajeParticipacion float64
	IsPoliticallyExposed    bool
	EsMayoritario           bool
}

func ToBeneficiario(r BeneficiarioRow) kbmclient.BeneficiarioControlador {
	return kbmclient.BeneficiarioControlador{
		ID: r.ID,
		Persona: shared.PersonaFisica{
			FullName:         r.FullName,
			IDDocumentType:   shared.IDDocumentType(r.IDDocumentType),
			IDDocumentNumber: r.IDDocumentNumber,
			CURP:             r.Curp,
			RFC:              r.Rfc,
		},
		PorcentajeParticipacion: r.PorcentajeParticipacion,
		IsPoliticallyExposed:    r.IsPoliticallyExposed,
		EsMayoritario:           r.EsMayoritario,
	}
}

func ToConcentratorAccount(id, clientID, currency string, balance float64) treasury.ConcentratorAccount {
	return treasury.ConcentratorAccount{ID: id, ClientID: clientID, Currency: currency, Balance: balance}
}

// ConcentratorEntryRow mirrors ListConcentratorEntriesRow / InsertConcentratorEntryRow.
type ConcentratorEntryRow struct {
	ID                    string
	ConcentratorAccountID string
	EntryType             sqlcgen.LedgerEntryType
	Amount                float64
	BalanceAfter          float64
	Description           *string
	CreatedAt             time.Time
}

func ToConcentratorEntry(r ConcentratorEntryRow) treasury.ConcentratorEntry {
	return treasury.ConcentratorEntry{
		ID:                    r.ID,
		ConcentratorAccountID: r.ConcentratorAccountID,
		Type:                  ledger.EntryType(r.EntryType),
		Amount:                r.Amount,
		BalanceAfter:          r.BalanceAfter,
		Description:           strOrDefault(r.Description, ""),
		CreatedAt:             r.CreatedAt,
	}
}

// CollectorDepositRow mirrors ListCollectorDepositsByClientRow / GetCollectorDepositForUpdateRow.
type CollectorDepositRow struct {
	ID                string
	ClientID          string
	Amount            float64
	Reference         string
	Status            sqlcgen.CollectorDepositStatus
	RegisteredByEmail string
	ReconciledByEmail *string
	CreatedAt         time.Time
	ReconciledAt      *time.Time
}

func ToCollectorDeposit(r CollectorDepositRow) treasury.CollectorDeposit {
	return treasury.CollectorDeposit{
		ID:                r.ID,
		ClientID:          r.ClientID,
		Amount:            r.Amount,
		Reference:         r.Reference,
		Status:            treasury.CollectorDepositStatus(r.Status),
		RegisteredByEmail: r.RegisteredByEmail,
		ReconciledByEmail: r.ReconciledByEmail,
		CreatedAt:         r.CreatedAt,
		ReconciledAt:      r.ReconciledAt,
	}
}

// StaffUserRow mirrors ListStaffUsersByClientRow / GetStaffUserByIDRow /
// CreateStaffUserRow / UpdateStaffUserRow / SetStaffUserActiveRow — all
// five share the exact same five columns.
type StaffUserRow struct {
	ID       string
	ClientID *string
	Email    string
	FullName string
	Role     sqlcgen.UserRole
	IsActive bool
}

func ToStaffUser(r StaffUserRow) staff.User {
	return staff.User{ID: r.ID, ClientID: r.ClientID, Email: r.Email, FullName: r.FullName, Role: staff.Role(r.Role), IsActive: r.IsActive}
}

// BalanceOperationRow mirrors ListBalanceOperationsByClientsRow / GetBalanceOperationForUpdateRow.
type BalanceOperationRow struct {
	ID                string
	ClientID          string
	CardID            string
	OperationType     sqlcgen.OperationType
	Amount            *float64
	DestinationCardID *string
	Status            sqlcgen.OperationStatus
	RequestedByEmail  string
	ResolvedByEmail   *string
	ResolutionNotes   *string
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

func ToBalanceOperation(r BalanceOperationRow) approval.Operation {
	return approval.Operation{
		ID:                r.ID,
		ClientID:          r.ClientID,
		CardID:            r.CardID,
		Type:              approval.OperationType(r.OperationType),
		Amount:            floatOrZero(r.Amount),
		DestinationCardID: r.DestinationCardID,
		Status:            approval.OperationStatus(r.Status),
		RequestedByEmail:  r.RequestedByEmail,
		ResolvedByEmail:   r.ResolvedByEmail,
		ResolutionNotes:   r.ResolutionNotes,
		CreatedAt:         r.CreatedAt,
		UpdatedAt:         r.UpdatedAt,
	}
}

// MovementClaimRow mirrors GetClaimByLedgerEntryRow / ListClaimsByLedgerEntriesRow.
type MovementClaimRow struct {
	ID               string
	LedgerEntryID    string
	Reason           string
	Status           sqlcgen.ClaimStatus
	RequestedByEmail string
	ResolvedByEmail  *string
	ResolutionNotes  *string
	CreatedAt        time.Time
	ResolvedAt       *time.Time
}

func ToMovementClaim(r MovementClaimRow) ledger.MovementClaim {
	return ledger.MovementClaim{
		ID:               r.ID,
		LedgerEntryID:    r.LedgerEntryID,
		Reason:           r.Reason,
		Status:           ledger.ClaimStatus(r.Status),
		RequestedByEmail: r.RequestedByEmail,
		ResolvedByEmail:  r.ResolvedByEmail,
		ResolutionNotes:  r.ResolutionNotes,
		CreatedAt:        r.CreatedAt,
		ResolvedAt:       r.ResolvedAt,
	}
}

func ToLedgerAccount(cardID string, balance float64, currency string) ledger.Account {
	return ledger.Account{CardID: cardID, Balance: balance, Currency: currency}
}

// LedgerEntryRow mirrors ListLedgerEntriesByAccountIDRow /
// InsertLedgerEntryRow — same reasoning as CardRow above.
type LedgerEntryRow struct {
	ID              string
	ClientID        string
	LedgerAccountID string
	EntryType       sqlcgen.LedgerEntryType
	Amount          float64
	BalanceAfter    float64
	Description     *string
	CreatedAt       time.Time
}

// cardID viene del llamador (internal/adapters/postgres/repository), que
// ya lo sabe por contexto — la fila solo trae ledger_account_id, no el id
// de la tarjeta (ver ledger.Account, "1:1 con una Card... aquí el CardID
// hace también de identificador de la cuenta" no aplica en Postgres,
// donde ledger_accounts sí tiene su propio id — internal/domain/ledger/ledger.go).
func ToLedgerEntry(cardID string, r LedgerEntryRow) ledger.Entry {
	desc := ""
	if r.Description != nil {
		desc = *r.Description
	}
	return ledger.Entry{
		ID:           r.ID,
		CardID:       cardID,
		Type:         ledger.EntryType(r.EntryType),
		Amount:       r.Amount,
		BalanceAfter: r.BalanceAfter,
		Description:  desc,
		CreatedAt:    r.CreatedAt,
	}
}

// ToBeneficiary — igual criterio que ToAccount: sqlc reusa
// sqlcgen.PaymentBeneficiary para todo query de payment_beneficiaries.sql
// que trae la fila completa, así que no hace falta un "Row" intermedio.
func ToBeneficiary(r sqlcgen.PaymentBeneficiary) beneficiary.Beneficiary {
	return beneficiary.Beneficiary{
		ID:           r.ID,
		ClientID:     r.ClientID,
		CardholderID: r.CardholderID,
		Alias:        r.Alias,
		CLABE:        r.Clabe,
		BankName:     r.BankName,
		CoolingUntil: r.CoolingUntil,
		CreatedAt:    r.CreatedAt,
	}
}

// ToSPEIPayment toma sqlcgen.SpeiPayment directamente — resultado de
// CreateSPEIPayment/GetSPEIPaymentForUpdate, sin los campos de join
// (alias/CLABE del beneficiario, nombre del solicitante) que solo traen
// los queries de listado; ver speipayment.Payment para por qué esos
// quedan vacíos aquí (el llamador los llena aparte cuando sí los tiene).
func ToSPEIPayment(r sqlcgen.SpeiPayment) speipayment.Payment {
	return speipayment.Payment{
		ID:                      r.ID,
		ClientID:                r.ClientID,
		AccountID:               r.AccountID,
		BeneficiaryID:           r.BeneficiaryID,
		Amount:                  r.Amount,
		Status:                  approval.OperationStatus(r.Status),
		RequestedByCardholderID: r.RequestedByCardholderID,
		ResolutionNotes:         r.ResolutionNotes,
		ProviderReference:       r.ProviderReference,
		CreatedAt:               r.CreatedAt,
		UpdatedAt:               r.UpdatedAt,
	}
}

// ToSPEIDeposit toma sqlcgen.SpeiDeposit directamente — mismo criterio
// que ToBeneficiary.
func ToSPEIDeposit(r sqlcgen.SpeiDeposit) speipayment.Deposit {
	return speipayment.Deposit{
		ID:                r.ID,
		ClientID:          r.ClientID,
		AccountID:         r.AccountID,
		Amount:            r.Amount,
		ProviderReference: r.ProviderReference,
		CreatedAt:         r.CreatedAt,
	}
}
