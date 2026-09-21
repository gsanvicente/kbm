// DTOs for the 2026-09-20 full-Postgres-migration increment: Clientes
// (KYB), Cardholders (KYC), Tesorería, login administrativo, Aprobaciones
// y Reclamos — ver docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
package dto

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/approval"
	"github.com/koons/kbm/backend/internal/domain/cardholder"
	kbmclient "github.com/koons/kbm/backend/internal/domain/client"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/staff"
	"github.com/koons/kbm/backend/internal/domain/treasury"
)

// --- Staff login ------------------------------------------------------

type StaffLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type StaffLoginResponse struct {
	UserID   string  `json:"userId"`
	Email    string  `json:"email"`
	Role     string  `json:"role"`
	ClientID *string `json:"clientId"`
	// AccessToken — ver LoginResponse.AccessToken en dto.go, mismo
	// criterio (JWT, ver docs/adr/0013-jwt-session-authentication.md).
	AccessToken string `json:"accessToken"`
}

func FromStaffUser(u staff.User) StaffLoginResponse {
	return StaffLoginResponse{UserID: u.ID, Email: u.Email, Role: string(u.Role), ClientID: u.ClientID}
}

// --- Cardholders (KYC, gestión de admin/) ------------------------------

type PersonaFisica struct {
	FullName         string  `json:"fullName"`
	IDDocumentType   string  `json:"idDocumentType"`
	IDDocumentNumber string  `json:"idDocumentNumber"`
	CURP             *string `json:"curp"`
	RFC              *string `json:"rfc"`
}

type Cardholder struct {
	ID                   string     `json:"id"`
	ClientID             string     `json:"clientId"`
	FullName             string     `json:"fullName"`
	IDDocumentType       string     `json:"idDocumentType"`
	IDDocumentNumber     string     `json:"idDocumentNumber"`
	CURP                 *string    `json:"curp"`
	RFC                  *string    `json:"rfc"`
	DateOfBirth          *time.Time `json:"dateOfBirth"`
	Nationality          string     `json:"nationality"`
	AddressStreet        *string    `json:"addressStreet"`
	AddressNeighborhood  *string    `json:"addressNeighborhood"`
	AddressCity          *string    `json:"addressCity"`
	AddressState         *string    `json:"addressState"`
	AddressPostalCode    *string    `json:"addressPostalCode"`
	AddressCountry       string     `json:"addressCountry"`
	IsPoliticallyExposed bool       `json:"isPoliticallyExposed"`
	Email                *string    `json:"email"`
	Phone                *string    `json:"phone"`
	IsActive             bool       `json:"isActive"`
}

func FromCardholderManagement(c cardholder.Cardholder) Cardholder {
	return Cardholder{
		ID:                   c.ID,
		ClientID:             c.ClientID,
		FullName:             c.FullName,
		IDDocumentType:       string(c.IDDocumentType),
		IDDocumentNumber:     c.IDDocumentNumber,
		CURP:                 c.CURP,
		RFC:                  c.RFC,
		DateOfBirth:          c.DateOfBirth,
		Nationality:          c.Nationality,
		AddressStreet:        c.AddressStreet,
		AddressNeighborhood:  c.AddressNeighborhood,
		AddressCity:          c.AddressCity,
		AddressState:         c.AddressState,
		AddressPostalCode:    c.AddressPostalCode,
		AddressCountry:       c.AddressCountry,
		IsPoliticallyExposed: c.IsPoliticallyExposed,
		Email:                c.Email,
		Phone:                c.Phone,
		IsActive:             c.IsActive,
	}
}

func ToCardholderManagement(c Cardholder) cardholder.Cardholder {
	return cardholder.Cardholder{
		ID:                   c.ID,
		ClientID:             c.ClientID,
		FullName:             c.FullName,
		IDDocumentType:       shared.IDDocumentType(c.IDDocumentType),
		IDDocumentNumber:     c.IDDocumentNumber,
		CURP:                 c.CURP,
		RFC:                  c.RFC,
		DateOfBirth:          c.DateOfBirth,
		Nationality:          c.Nationality,
		AddressStreet:        c.AddressStreet,
		AddressNeighborhood:  c.AddressNeighborhood,
		AddressCity:          c.AddressCity,
		AddressState:         c.AddressState,
		AddressPostalCode:    c.AddressPostalCode,
		AddressCountry:       c.AddressCountry,
		IsPoliticallyExposed: c.IsPoliticallyExposed,
		Email:                c.Email,
		Phone:                c.Phone,
		IsActive:             c.IsActive,
	}
}

type SetActiveRequest struct {
	Active bool `json:"active"`
}

// --- Clientes (KYB) -----------------------------------------------------

type ActaConstitutiva struct {
	NumeroEscritura string    `json:"numeroEscritura"`
	Notario         string    `json:"notario"`
	Plaza           string    `json:"plaza"`
	Fecha           time.Time `json:"fecha"`
	FolioRPC        string    `json:"folioRPC"`
}

type ApoderadoLegal struct {
	ID                       string        `json:"id"`
	Persona                  PersonaFisica `json:"persona"`
	TipoPoder                string        `json:"tipoPoder"`
	DescripcionPoderEspecial *string       `json:"descripcionPoderEspecial"`
	NumeroEscritura          string        `json:"numeroEscritura"`
	Notario                  string        `json:"notario"`
	FechaInstrumento         time.Time     `json:"fechaInstrumento"`
	Vigencia                 *time.Time    `json:"vigencia"`
	EsPrincipal              bool          `json:"esPrincipal"`
}

type BeneficiarioControlador struct {
	ID                      string        `json:"id"`
	Persona                 PersonaFisica `json:"persona"`
	PorcentajeParticipacion float64       `json:"porcentajeParticipacion"`
	IsPoliticallyExposed    bool          `json:"isPoliticallyExposed"`
	EsMayoritario           bool          `json:"esMayoritario"`
}

type Client struct {
	ID                         string                    `json:"id"`
	Name                       string                    `json:"name"`
	ParentClientID             *string                   `json:"parentClientId"`
	IsActive                   bool                      `json:"isActive"`
	RazonSocial                *string                   `json:"razonSocial"`
	NombreComercial            *string                   `json:"nombreComercial"`
	RFC                        *string                   `json:"rfc"`
	FechaConstitucion          *time.Time                `json:"fechaConstitucion"`
	ObjetoSocial               *string                   `json:"objetoSocial"`
	ActaConstitutiva           *ActaConstitutiva         `json:"actaConstitutiva"`
	AddressStreet              *string                   `json:"addressStreet"`
	AddressNeighborhood        *string                   `json:"addressNeighborhood"`
	AddressCity                *string                   `json:"addressCity"`
	AddressState               *string                   `json:"addressState"`
	AddressPostalCode          *string                   `json:"addressPostalCode"`
	AddressCountry             string                    `json:"addressCountry"`
	Apoderados                 []ApoderadoLegal          `json:"apoderados"`
	BeneficiariosControladores []BeneficiarioControlador `json:"beneficiariosControladores"`
}

func fromPersonaFisica(p shared.PersonaFisica) PersonaFisica {
	return PersonaFisica{
		FullName:         p.FullName,
		IDDocumentType:   string(p.IDDocumentType),
		IDDocumentNumber: p.IDDocumentNumber,
		CURP:             p.CURP,
		RFC:              p.RFC,
	}
}

func toPersonaFisica(p PersonaFisica) shared.PersonaFisica {
	return shared.PersonaFisica{
		FullName:         p.FullName,
		IDDocumentType:   shared.IDDocumentType(p.IDDocumentType),
		IDDocumentNumber: p.IDDocumentNumber,
		CURP:             p.CURP,
		RFC:              p.RFC,
	}
}

func FromClient(c kbmclient.Client) Client {
	out := Client{
		ID:                         c.ID,
		Name:                       c.Name,
		ParentClientID:             c.ParentClientID,
		IsActive:                   c.IsActive,
		RazonSocial:                c.RazonSocial,
		NombreComercial:            c.NombreComercial,
		RFC:                        c.RFC,
		FechaConstitucion:          c.FechaConstitucion,
		ObjetoSocial:               c.ObjetoSocial,
		AddressStreet:              c.AddressStreet,
		AddressNeighborhood:        c.AddressNeighborhood,
		AddressCity:                c.AddressCity,
		AddressState:               c.AddressState,
		AddressPostalCode:          c.AddressPostalCode,
		AddressCountry:             c.AddressCountry,
		Apoderados:                 []ApoderadoLegal{},
		BeneficiariosControladores: []BeneficiarioControlador{},
	}
	if c.ActaConstitutiva != nil {
		out.ActaConstitutiva = &ActaConstitutiva{
			NumeroEscritura: c.ActaConstitutiva.NumeroEscritura,
			Notario:         c.ActaConstitutiva.Notario,
			Plaza:           c.ActaConstitutiva.Plaza,
			Fecha:           c.ActaConstitutiva.Fecha,
			FolioRPC:        c.ActaConstitutiva.FolioRPC,
		}
	}
	for _, a := range c.Apoderados {
		out.Apoderados = append(out.Apoderados, ApoderadoLegal{
			ID:                       a.ID,
			Persona:                  fromPersonaFisica(a.Persona),
			TipoPoder:                string(a.TipoPoder),
			DescripcionPoderEspecial: a.DescripcionPoderEspecial,
			NumeroEscritura:          a.NumeroEscritura,
			Notario:                  a.Notario,
			FechaInstrumento:         a.FechaInstrumento,
			Vigencia:                 a.Vigencia,
			EsPrincipal:              a.EsPrincipal,
		})
	}
	for _, b := range c.BeneficiariosControladores {
		out.BeneficiariosControladores = append(out.BeneficiariosControladores, BeneficiarioControlador{
			ID:                      b.ID,
			Persona:                 fromPersonaFisica(b.Persona),
			PorcentajeParticipacion: b.PorcentajeParticipacion,
			IsPoliticallyExposed:    b.IsPoliticallyExposed,
			EsMayoritario:           b.EsMayoritario,
		})
	}
	return out
}

func ToClient(c Client) kbmclient.Client {
	out := kbmclient.Client{
		ID:                  c.ID,
		Name:                c.Name,
		ParentClientID:      c.ParentClientID,
		RazonSocial:         c.RazonSocial,
		NombreComercial:     c.NombreComercial,
		RFC:                 c.RFC,
		FechaConstitucion:   c.FechaConstitucion,
		ObjetoSocial:        c.ObjetoSocial,
		AddressStreet:       c.AddressStreet,
		AddressNeighborhood: c.AddressNeighborhood,
		AddressCity:         c.AddressCity,
		AddressState:        c.AddressState,
		AddressPostalCode:   c.AddressPostalCode,
		AddressCountry:      c.AddressCountry,
	}
	if c.ActaConstitutiva != nil {
		out.ActaConstitutiva = &kbmclient.ActaConstitutiva{
			NumeroEscritura: c.ActaConstitutiva.NumeroEscritura,
			Notario:         c.ActaConstitutiva.Notario,
			Plaza:           c.ActaConstitutiva.Plaza,
			Fecha:           c.ActaConstitutiva.Fecha,
			FolioRPC:        c.ActaConstitutiva.FolioRPC,
		}
	}
	for _, a := range c.Apoderados {
		out.Apoderados = append(out.Apoderados, kbmclient.ApoderadoLegal{
			Persona:                  toPersonaFisica(a.Persona),
			TipoPoder:                kbmclient.TipoPoder(a.TipoPoder),
			DescripcionPoderEspecial: a.DescripcionPoderEspecial,
			NumeroEscritura:          a.NumeroEscritura,
			Notario:                  a.Notario,
			FechaInstrumento:         a.FechaInstrumento,
			Vigencia:                 a.Vigencia,
			EsPrincipal:              a.EsPrincipal,
		})
	}
	for _, b := range c.BeneficiariosControladores {
		out.BeneficiariosControladores = append(out.BeneficiariosControladores, kbmclient.BeneficiarioControlador{
			Persona:                 toPersonaFisica(b.Persona),
			PorcentajeParticipacion: b.PorcentajeParticipacion,
			IsPoliticallyExposed:    b.IsPoliticallyExposed,
			EsMayoritario:           b.EsMayoritario,
		})
	}
	return out
}

type IsOperableResponse struct {
	Operable bool `json:"operable"`
}

type ClientSettingsResponse struct {
	MaxActiveCardsPerCardholder *int `json:"maxActiveCardsPerCardholder"`
}

type SetClientSettingsRequest struct {
	// nil borra el override (vuelve al default de la aplicación) — ver
	// docs/feature/configuracion-de-cliente/README.md.
	MaxActiveCardsPerCardholder *int `json:"maxActiveCardsPerCardholder"`
}

type ApprovalRule struct {
	ClientID         string   `json:"clientId"`
	OperationType    string   `json:"operationType"`
	RequiresApproval bool     `json:"requiresApproval"`
	MinAmount        *float64 `json:"minAmount"`
}

func FromApprovalRule(r approval.Rule) ApprovalRule {
	return ApprovalRule{
		ClientID:         r.ClientID,
		OperationType:    string(r.OperationType),
		RequiresApproval: r.RequiresApproval,
		MinAmount:        r.MinAmount,
	}
}

type SetApprovalRuleRequest struct {
	RequiresApproval bool     `json:"requiresApproval"`
	MinAmount        *float64 `json:"minAmount"`
}

// --- Tesorería ------------------------------------------------------

type ConcentratorAccount struct {
	ID       string  `json:"id"`
	ClientID string  `json:"clientId"`
	Currency string  `json:"currency"`
	Balance  float64 `json:"balance"`
}

func FromConcentratorAccount(a treasury.ConcentratorAccount) ConcentratorAccount {
	return ConcentratorAccount{ID: a.ID, ClientID: a.ClientID, Currency: a.Currency, Balance: a.Balance}
}

type ConcentratorEntry struct {
	ID                    string    `json:"id"`
	ConcentratorAccountID string    `json:"concentratorAccountId"`
	Type                  string    `json:"type"`
	Amount                float64   `json:"amount"`
	BalanceAfter          float64   `json:"balanceAfter"`
	Description           string    `json:"description"`
	CreatedAt             time.Time `json:"createdAt"`
}

func FromConcentratorEntry(e treasury.ConcentratorEntry) ConcentratorEntry {
	return ConcentratorEntry{
		ID:                    e.ID,
		ConcentratorAccountID: e.ConcentratorAccountID,
		Type:                  string(e.Type),
		Amount:                e.Amount,
		BalanceAfter:          e.BalanceAfter,
		Description:           e.Description,
		CreatedAt:             e.CreatedAt,
	}
}

type PostConcentratorEntryRequest struct {
	Type        string  `json:"type"`
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
}

type CollectorDeposit struct {
	ID                string     `json:"id"`
	ClientID          string     `json:"clientId"`
	Amount            float64    `json:"amount"`
	Reference         string     `json:"reference"`
	Status            string     `json:"status"`
	RegisteredByEmail string     `json:"registeredByEmail"`
	ReconciledByEmail *string    `json:"reconciledByEmail"`
	CreatedAt         time.Time  `json:"createdAt"`
	ReconciledAt      *time.Time `json:"reconciledAt"`
}

func FromCollectorDeposit(d treasury.CollectorDeposit) CollectorDeposit {
	return CollectorDeposit{
		ID:                d.ID,
		ClientID:          d.ClientID,
		Amount:            d.Amount,
		Reference:         d.Reference,
		Status:            string(d.Status),
		RegisteredByEmail: d.RegisteredByEmail,
		ReconciledByEmail: d.ReconciledByEmail,
		CreatedAt:         d.CreatedAt,
		ReconciledAt:      d.ReconciledAt,
	}
}

type RegisterDepositRequest struct {
	Amount            float64 `json:"amount"`
	Reference         string  `json:"reference"`
	RegisteredByEmail string  `json:"registeredByEmail"`
}

type ReconcileDepositRequest struct {
	ReconciledByEmail string `json:"reconciledByEmail"`
}

// --- Aprobaciones (Operaciones de saldo) -------------------------------

type BalanceOperation struct {
	ID                string    `json:"id"`
	ClientID          string    `json:"clientId"`
	CardID            string    `json:"cardId"`
	Type              string    `json:"type"`
	Amount            float64   `json:"amount"`
	DestinationCardID *string   `json:"destinationCardId"`
	Status            string    `json:"status"`
	RequestedByEmail  string    `json:"requestedByEmail"`
	ResolvedByEmail   *string   `json:"resolvedByEmail"`
	ResolutionNotes   *string   `json:"resolutionNotes"`
	CreatedAt         time.Time `json:"createdAt"`
	UpdatedAt         time.Time `json:"updatedAt"`
}

func FromBalanceOperation(op approval.Operation) BalanceOperation {
	return BalanceOperation{
		ID:                op.ID,
		ClientID:          op.ClientID,
		CardID:            op.CardID,
		Type:              string(op.Type),
		Amount:            op.Amount,
		DestinationCardID: op.DestinationCardID,
		Status:            string(op.Status),
		RequestedByEmail:  op.RequestedByEmail,
		ResolvedByEmail:   op.ResolvedByEmail,
		ResolutionNotes:   op.ResolutionNotes,
		CreatedAt:         op.CreatedAt,
		UpdatedAt:         op.UpdatedAt,
	}
}

type RequestBalanceOperationRequest struct {
	ClientID          string  `json:"clientId"`
	CardID            string  `json:"cardId"`
	Type              string  `json:"type"`
	Amount            float64 `json:"amount"`
	DestinationCardID *string `json:"destinationCardId"`
	RequestedByEmail  string  `json:"requestedByEmail"`
}

type ApproveOperationRequest struct {
	ApprovedByEmail string `json:"approvedByEmail"`
}

type RejectOperationRequest struct {
	RejectedByEmail string `json:"rejectedByEmail"`
	Reason          string `json:"reason"`
}

type WeekVolume struct {
	WeekStart     time.Time `json:"weekStart"`
	Dispersion    float64   `json:"dispersion"`
	Deduccion     float64   `json:"deduccion"`
	Transferencia float64   `json:"transferencia"`
}

func FromWeekVolume(w approval.WeekVolume) WeekVolume {
	return WeekVolume{
		WeekStart:     w.WeekStart,
		Dispersion:    w.Dispersion,
		Deduccion:     w.Deduccion,
		Transferencia: w.Transferencia,
	}
}

// --- Reclamos ------------------------------------------------------

type MovementClaim struct {
	ID               string     `json:"id"`
	LedgerEntryID    string     `json:"ledgerEntryId"`
	Reason           string     `json:"reason"`
	Status           string     `json:"status"`
	RequestedByEmail string     `json:"requestedByEmail"`
	ResolvedByEmail  *string    `json:"resolvedByEmail"`
	ResolutionNotes  *string    `json:"resolutionNotes"`
	CreatedAt        time.Time  `json:"createdAt"`
	ResolvedAt       *time.Time `json:"resolvedAt"`
}

func FromMovementClaim(c ledger.MovementClaim) MovementClaim {
	return MovementClaim{
		ID:               c.ID,
		LedgerEntryID:    c.LedgerEntryID,
		Reason:           c.Reason,
		Status:           string(c.Status),
		RequestedByEmail: c.RequestedByEmail,
		ResolvedByEmail:  c.ResolvedByEmail,
		ResolutionNotes:  c.ResolutionNotes,
		CreatedAt:        c.CreatedAt,
		ResolvedAt:       c.ResolvedAt,
	}
}

type FileClaimRequest struct {
	Reason           string `json:"reason"`
	RequestedByEmail string `json:"requestedByEmail"`
}

type ResolveClaimRequest struct {
	InFavor         bool   `json:"inFavor"`
	ResolutionNotes string `json:"resolutionNotes"`
	ResolvedByEmail string `json:"resolvedByEmail"`
}
