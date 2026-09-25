// Conector SPEI — ver docs/adr/0021-conector-spei.md. SPEIStore envuelve
// *Store (mismo criterio que ManagementStore) para poder inyectarle un
// ports.SPEIGateway — ningún otro método de Store necesita una
// dependencia externa además del pool de Postgres.
package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	"github.com/koons/kbm/backend/internal/application/ports"
	"github.com/koons/kbm/backend/internal/domain/approval"
	"github.com/koons/kbm/backend/internal/domain/beneficiary"
	"github.com/koons/kbm/backend/internal/domain/clabe"
	"github.com/koons/kbm/backend/internal/domain/ledger"
	"github.com/koons/kbm/backend/internal/domain/shared"
	"github.com/koons/kbm/backend/internal/domain/speipayment"
)

type SPEIStore struct {
	*Store
	gateway ports.SPEIGateway
}

func NewSPEIStore(s *Store, gateway ports.SPEIGateway) *SPEIStore {
	return &SPEIStore{Store: s, gateway: gateway}
}

func (s *SPEIStore) GetCLABE(ctx context.Context, cardholderID string) (*string, error) {
	var result *string
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		if acct.Clabe.Valid {
			result = &acct.Clabe.String
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (s *SPEIStore) EnsureCLABE(ctx context.Context, cardholderID string) (string, error) {
	var result string
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		if acct.Clabe.Valid {
			result = acct.Clabe.String
			return nil
		}
		// Capa 2 de docs/business/desactivacion-de-clientes.md — provisionar
		// una CLABE es una acción que cambia estado, así que se verifica
		// aunque el login del Tarjetahabiente haya sido antes de que su
		// Cliente se desactivara (ver auth.go's Login para la Capa 1).
		operable, err := s.IsOperable(ctx, acct.ClientID)
		if err != nil {
			return err
		}
		if !operable {
			return shared.ErrForbidden
		}

		generated, err := s.gateway.ProvisionCLABE(ctx, acct.ID)
		if err != nil {
			return err
		}
		updated, err := q.SetIndividualAccountCLABE(ctx, sqlcgen.SetIndividualAccountCLABEParams{
			ID:    acct.ID,
			Clabe: pgtype.Text{String: generated, Valid: true},
		})
		if err != nil {
			return err
		}
		result = updated.Clabe.String
		return logCallerAudit(ctx, q, "individual_account_clabe_provisioned", "individual_account", acct.ID, nil)
	})
	if err != nil {
		return "", err
	}
	return result, nil
}

// GetAccountLedger — saldo y movimientos de la Cuenta Individual de
// [cardholderID], sin pasar por ninguna tarjeta. Necesario para que un
// Tarjetahabiente sin ninguna tarjeta asignada (caso real desde
// ADR-0020, punto 3: "la Cuenta puede recibir SPEI desde el día del
// alta") pueda ver su saldo/depósitos — antes de esto, GetByCard exigía
// una tarjeta y no había forma equivalente a nivel Cuenta.
func (s *SPEIStore) GetAccountLedger(ctx context.Context, cardholderID string) (ledger.Account, []ledger.Entry, error) {
	var (
		outAccount ledger.Account
		outEntries []ledger.Entry
	)
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		account, err := q.GetLedgerAccountByAccountID(ctx, acct.ID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}

		balance, err := q.GetLatestLedgerBalance(ctx, account.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		// pgx.ErrNoRows — Cuenta recién creada, sin movimientos todavía:
		// nace en 0, igual que GetByCard con una tarjeta.

		rows, err := q.ListLedgerEntriesByAccountID(ctx, account.ID)
		if err != nil {
			return err
		}
		outEntries = make([]ledger.Entry, 0, len(rows))
		for _, r := range rows {
			// cardID vacío a propósito — este movimiento vive a nivel Cuenta,
			// nunca de una tarjeta específica; ni ToLedgerEntry ni el DTO
			// (dto.FromLedgerEntry) serializan CardID, así que esto es seguro.
			outEntries = append(outEntries, mapper.ToLedgerEntry("", mapper.LedgerEntryRow(r)))
		}
		outAccount = mapper.ToLedgerAccount("", balance, account.Currency)
		return nil
	})
	if err != nil {
		return ledger.Account{}, nil, err
	}
	return outAccount, outEntries, nil
}

func (s *SPEIStore) ListBeneficiaries(ctx context.Context, cardholderID string) ([]beneficiary.Beneficiary, error) {
	var out []beneficiary.Beneficiary
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListBeneficiariesByCardholder(ctx, cardholderID)
		if err != nil {
			return err
		}
		out = make([]beneficiary.Beneficiary, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToBeneficiary(r))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ListBeneficiaryDirectory — el reporte agregado de staff, ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, puntos 2 y
// 3. Dos consultas separadas a propósito: la primera (withRLS) respeta
// el alcance normal de [clientIDs]; la segunda (withRLSBypass) calcula
// la bandera de CLABE compartida SIN ese filtro — RLS en
// payment_beneficiaries se aplicaría también dentro de una subconsulta
// correlacionada si ambas corrieran en la misma transacción con alcance
// normal, así que la señal cross-tenant necesita su propia consulta sin
// alcance. Nunca se combina en una sola query.
func (s *SPEIStore) ListBeneficiaryDirectory(ctx context.Context, clientIDs []string) ([]beneficiary.DirectoryEntry, error) {
	var rows []sqlcgen.ListBeneficiariesByClientsRow
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		rows, err = q.ListBeneficiariesByClients(ctx, clientIDs)
		return err
	})
	if err != nil {
		return nil, err
	}

	clabes := make([]string, 0, len(rows))
	seen := map[string]bool{}
	for _, r := range rows {
		if !seen[r.Clabe] {
			seen[r.Clabe] = true
			clabes = append(clabes, r.Clabe)
		}
	}
	clabeShared := map[string]bool{}
	if len(clabes) > 0 {
		err = s.withRLSBypass(ctx, func(q *sqlcgen.Queries) error {
			sharedRows, err := q.CountCardholdersByClabes(ctx, clabes)
			if err != nil {
				return err
			}
			for _, sr := range sharedRows {
				clabeShared[sr.Clabe] = true
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	out := make([]beneficiary.DirectoryEntry, 0, len(rows))
	for _, r := range rows {
		out = append(out, beneficiary.DirectoryEntry{
			Beneficiary: beneficiary.Beneficiary{
				ID:           r.ID,
				Alias:        r.Alias,
				CLABE:        r.Clabe,
				BankName:     r.BankName,
				CoolingUntil: r.CoolingUntil,
				CreatedAt:    r.CreatedAt,
			},
			ClientID:                    r.ClientID,
			CardholderID:                r.CardholderID,
			CardholderFullName:          r.CardholderFullName,
			PaymentCount:                r.PaymentCount,
			TotalAmountPaid:             r.TotalAmount,
			SharedByMultipleCardholders: clabeShared[r.Clabe],
		})
	}
	return out, nil
}

// RevealBeneficiaryCLABE — devuelve la CLABE completa de [beneficiaryID]
// para el directorio agregado (que la muestra enmascarada por default) —
// ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto
// 2. Queda auditada. withRLS de por sí ya limita esto al alcance de
// quien la pide (un beneficiario fuera de su alcance da
// shared.ErrNotFound, nunca la CLABE).
func (s *SPEIStore) RevealBeneficiaryCLABE(ctx context.Context, beneficiaryID string) (string, error) {
	var clabeNumber string
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetBeneficiaryByID(ctx, beneficiaryID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		clabeNumber = row.Clabe
		return logCallerAudit(ctx, q, "spei_beneficiary_clabe_revealed", "payment_beneficiary", beneficiaryID, nil)
	})
	if err != nil {
		return "", err
	}
	return clabeNumber, nil
}

// RegisterBeneficiary — ver ports.SPEIRepository. El throttle de
// intentos fallidos (beneficiaryFailedAttempts) es el mismo mecanismo de
// sesión que Store.ResolveDestination usa para C2C (ver transfer.go),
// pero en un mapa separado — fallar aquí nunca consume el cupo de una
// transferencia, ni viceversa.
func (s *SPEIStore) RegisterBeneficiary(ctx context.Context, cardholderID, alias, clabeNumber string) (beneficiary.Beneficiary, error) {
	s.attemptsMu.Lock()
	tooMany := s.beneficiaryFailedAttempts[cardholderID] >= maxFailedAttempts
	s.attemptsMu.Unlock()
	if tooMany {
		return beneficiary.Beneficiary{}, shared.ErrTooManyFailedAttempts
	}

	registerFailedAttempt := func() error {
		s.attemptsMu.Lock()
		next := s.beneficiaryFailedAttempts[cardholderID] + 1
		s.beneficiaryFailedAttempts[cardholderID] = next
		s.attemptsMu.Unlock()
		if next >= maxFailedAttempts {
			return shared.ErrTooManyFailedAttempts
		}
		return shared.ErrValidation
	}

	if !clabe.ValidChecksum(clabeNumber) {
		return beneficiary.Beneficiary{}, registerFailedAttempt()
	}
	bankName, ok := clabe.BankName(clabeNumber)
	if !ok {
		return beneficiary.Beneficiary{}, registerFailedAttempt()
	}

	var (
		result   beneficiary.Beneficiary
		ownCLABE bool
	)
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		if acct.Clabe.Valid && acct.Clabe.String == clabeNumber {
			// Nunca la propia CLABE como beneficiario — ADR-0021,
			// "Seguridad".
			ownCLABE = true
			return shared.ErrValidation
		}
		// Capa 2 — ver EnsureCLABE arriba.
		operable, err := s.IsOperable(ctx, acct.ClientID)
		if err != nil {
			return err
		}
		if !operable {
			return shared.ErrForbidden
		}

		row, err := q.CreateBeneficiary(ctx, sqlcgen.CreateBeneficiaryParams{
			ClientID:     acct.ClientID,
			CardholderID: cardholderID,
			Alias:        alias,
			Clabe:        clabeNumber,
			BankName:     bankName,
		})
		if err != nil {
			return err
		}
		result = mapper.ToBeneficiary(row)
		return logCallerAudit(ctx, q, "spei_beneficiary_registered", "payment_beneficiary", row.ID, map[string]any{"bank_name": bankName})
	})
	if err != nil {
		if ownCLABE {
			return beneficiary.Beneficiary{}, registerFailedAttempt()
		}
		return beneficiary.Beneficiary{}, err
	}

	// Éxito — mismo criterio que un login exitoso resetea el contador de
	// transferencias C2C.
	s.attemptsMu.Lock()
	delete(s.beneficiaryFailedAttempts, cardholderID)
	s.attemptsMu.Unlock()
	return result, nil
}

func (s *SPEIStore) CreatePayment(ctx context.Context, cardholderID, beneficiaryID string, amount float64) (speipayment.Payment, error) {
	var (
		payment speipayment.Payment
		ben     beneficiary.Beneficiary
	)
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		// Capa 2 — ver EnsureCLABE arriba. Un pago SPEI mueve dinero de
		// verdad hacia fuera del ecosistema, así que este chequeo pesa más
		// aquí que en ningún otro lado de SPEIStore.
		operable, err := s.IsOperable(ctx, acct.ClientID)
		if err != nil {
			return err
		}
		if !operable {
			return shared.ErrForbidden
		}

		benRow, err := q.GetBeneficiaryByID(ctx, beneficiaryID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		if benRow.CardholderID != cardholderID {
			// Nunca revela que el beneficiario existe pero es de otro
			// Tarjetahabiente — mismo criterio "nunca revelar" del resto
			// del proyecto (ver SetFrozen en cards.go).
			return shared.ErrNotFound
		}
		ben = mapper.ToBeneficiary(benRow)
		if ben.IsCooling() && amount > beneficiary.CoolingPeriodMaxAmount {
			return shared.ErrValidation
		}

		row, err := q.CreateSPEIPayment(ctx, sqlcgen.CreateSPEIPaymentParams{
			ClientID:                acct.ClientID,
			AccountID:               acct.ID,
			BeneficiaryID:           beneficiaryID,
			Amount:                  amount,
			Status:                  sqlcgen.OperationStatusPendingApproval,
			RequestedByCardholderID: cardholderID,
		})
		if err != nil {
			return err
		}
		payment = mapper.ToSPEIPayment(row)
		return logCallerAudit(ctx, q, "spei_payment_requested", "spei_payment", row.ID, map[string]any{"amount": amount, "beneficiary_id": beneficiaryID})
	})
	if err != nil {
		return speipayment.Payment{}, err
	}

	needsApproval, err := s.needsApproval(ctx, payment.ClientID, approval.OperationTypeSPEIPayment, amount)
	if err != nil {
		return speipayment.Payment{}, err
	}
	if !needsApproval {
		payment, err = s.trySPEIExecute(ctx, payment, ben)
		if err != nil {
			return speipayment.Payment{}, err
		}
		if err := s.persistSPEIResolution(ctx, payment, nil); err != nil {
			return speipayment.Payment{}, err
		}
	}
	return payment, nil
}

func (s *SPEIStore) ListPayments(ctx context.Context, cardholderID string) ([]speipayment.Payment, error) {
	var out []speipayment.Payment
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		rows, err := q.ListSPEIPaymentsByAccount(ctx, acct.ID)
		if err != nil {
			return err
		}
		out = make([]speipayment.Payment, 0, len(rows))
		for _, r := range rows {
			out = append(out, speipayment.Payment{
				ID:                      r.ID,
				ClientID:                r.ClientID,
				AccountID:               r.AccountID,
				BeneficiaryID:           r.BeneficiaryID,
				Amount:                  r.Amount,
				Status:                  approval.OperationStatus(r.Status),
				RequestedByCardholderID: r.RequestedByCardholderID,
				ResolvedByEmail:         r.ResolvedByEmail,
				ResolutionNotes:         r.ResolutionNotes,
				ProviderReference:       r.ProviderReference,
				CreatedAt:               r.CreatedAt,
				UpdatedAt:               r.UpdatedAt,
				BeneficiaryAlias:        r.BeneficiaryAlias,
				BeneficiaryCLABE:        r.BeneficiaryClabe,
			})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ListDeposits — mis depósitos SPEI entrantes, más reciente primero.
// Necesario para el comprobante propio de un depósito (ADR-0021, punto
// 9) — antes de esto, un depósito solo era visible mezclado dentro de
// los movimientos de la Cuenta (ver GetAccountLedger), sin folio ni
// referencia del proveedor propios.
func (s *SPEIStore) ListDeposits(ctx context.Context, cardholderID string) ([]speipayment.Deposit, error) {
	var out []speipayment.Deposit
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCardholderID(ctx, cardholderID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		rows, err := q.ListSPEIDepositsByAccount(ctx, acct.ID)
		if err != nil {
			return err
		}
		out = make([]speipayment.Deposit, 0, len(rows))
		for _, r := range rows {
			out = append(out, mapper.ToSPEIDeposit(r))
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ListDepositsByClients — reporte de depósitos SPEI cross-cliente para
// staff, ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md.
// Distinto de ListDeposits (self-only, un solo Tarjetahabiente).
func (s *SPEIStore) ListDepositsByClients(ctx context.Context, clientIDs []string) ([]speipayment.Deposit, error) {
	var out []speipayment.Deposit
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListSPEIDepositsByClients(ctx, clientIDs)
		if err != nil {
			return err
		}
		out = make([]speipayment.Deposit, 0, len(rows))
		for _, r := range rows {
			out = append(out, speipayment.Deposit{
				ID:                 r.ID,
				ClientID:           r.ClientID,
				AccountID:          r.AccountID,
				Amount:             r.Amount,
				ProviderReference:  r.ProviderReference,
				CreatedAt:          r.CreatedAt,
				CardholderFullName: r.CardholderFullName,
			})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *SPEIStore) ListPendingPayments(ctx context.Context, clientIDs []string) ([]speipayment.Payment, error) {
	var out []speipayment.Payment
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListPendingSPEIPaymentsByClients(ctx, clientIDs)
		if err != nil {
			return err
		}
		out = make([]speipayment.Payment, 0, len(rows))
		for _, r := range rows {
			out = append(out, speipayment.Payment{
				ID:                      r.ID,
				ClientID:                r.ClientID,
				AccountID:               r.AccountID,
				BeneficiaryID:           r.BeneficiaryID,
				Amount:                  r.Amount,
				Status:                  approval.OperationStatus(r.Status),
				RequestedByCardholderID: r.RequestedByCardholderID,
				ResolvedByEmail:         r.ResolvedByEmail,
				ResolutionNotes:         r.ResolutionNotes,
				ProviderReference:       r.ProviderReference,
				CreatedAt:               r.CreatedAt,
				UpdatedAt:               r.UpdatedAt,
				BeneficiaryAlias:        r.BeneficiaryAlias,
				BeneficiaryCLABE:        r.BeneficiaryClabe,
				RequestedByFullName:     r.RequestedByFullName,
			})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ListPaymentsByClients — historial completo (cualquier estatus) para el
// reporte de staff, ver
// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. A
// diferencia de ListPendingPayments, nunca filtra por status.
func (s *SPEIStore) ListPaymentsByClients(ctx context.Context, clientIDs []string) ([]speipayment.Payment, error) {
	var out []speipayment.Payment
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		rows, err := q.ListSPEIPaymentsByClients(ctx, clientIDs)
		if err != nil {
			return err
		}
		out = make([]speipayment.Payment, 0, len(rows))
		for _, r := range rows {
			out = append(out, speipayment.Payment{
				ID:                      r.ID,
				ClientID:                r.ClientID,
				AccountID:               r.AccountID,
				BeneficiaryID:           r.BeneficiaryID,
				Amount:                  r.Amount,
				Status:                  approval.OperationStatus(r.Status),
				RequestedByCardholderID: r.RequestedByCardholderID,
				ResolvedByEmail:         r.ResolvedByEmail,
				ResolutionNotes:         r.ResolutionNotes,
				ProviderReference:       r.ProviderReference,
				CreatedAt:               r.CreatedAt,
				UpdatedAt:               r.UpdatedAt,
				BeneficiaryAlias:        r.BeneficiaryAlias,
				BeneficiaryCLABE:        r.BeneficiaryClabe,
				RequestedByFullName:     r.RequestedByFullName,
			})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ApprovePayment — mismo criterio de withAdvisoryLock que approval.go's
// Approve: sin esto, dos llamadas concurrentes sobre el mismo pago
// pendiente podrían ambas pasar el chequeo de estado antes de que
// cualquiera lo actualizara.
func (s *SPEIStore) ApprovePayment(ctx context.Context, paymentID, approvedByEmail string) (speipayment.Payment, error) {
	var result speipayment.Payment
	err := s.withAdvisoryLock(ctx, "spei_payment:"+paymentID, func() error {
		payment, ben, err := s.getPendingSPEIPaymentTx(ctx, paymentID)
		if err != nil {
			return err
		}

		operable, err := s.IsOperable(ctx, payment.ClientID)
		if err != nil {
			return err
		}
		if !operable {
			return shared.ErrForbidden
		}

		payment, err = s.trySPEIExecute(ctx, payment, ben)
		if err != nil {
			return err
		}
		payment.ResolvedByEmail = &approvedByEmail
		if err := s.persistSPEIResolution(ctx, payment, &approvedByEmail); err != nil {
			return err
		}
		result = payment
		return nil
	})
	if err != nil {
		return speipayment.Payment{}, err
	}
	return result, nil
}

// RejectPayment nunca toca el ledger. Ver ApprovePayment sobre
// withAdvisoryLock.
func (s *SPEIStore) RejectPayment(ctx context.Context, paymentID, rejectedByEmail, reason string) (speipayment.Payment, error) {
	var result speipayment.Payment
	err := s.withAdvisoryLock(ctx, "spei_payment:"+paymentID, func() error {
		payment, _, err := s.getPendingSPEIPaymentTx(ctx, paymentID)
		if err != nil {
			return err
		}

		operable, err := s.IsOperable(ctx, payment.ClientID)
		if err != nil {
			return err
		}
		if !operable {
			return shared.ErrForbidden
		}

		err = s.withRLS(ctx, func(q *sqlcgen.Queries) error {
			rejectedByID, err := q.GetStaffUserIDByEmail(ctx, rejectedByEmail)
			if err != nil {
				return err
			}
			if err := q.UpdateSPEIPaymentStatus(ctx, sqlcgen.UpdateSPEIPaymentStatusParams{
				ID:              paymentID,
				Status:          sqlcgen.OperationStatusRejected,
				ResolvedBy:      &rejectedByID,
				ResolutionNotes: &reason,
			}); err != nil {
				return err
			}
			return logCallerAudit(ctx, q, "spei_payment_rejected", "spei_payment", paymentID, map[string]any{"resolved_by_email": rejectedByEmail, "reason": reason})
		})
		if err != nil {
			return err
		}
		payment.Status = approval.OperationStatusRejected
		payment.ResolvedByEmail = &rejectedByEmail
		payment.ResolutionNotes = &reason
		result = payment
		return nil
	})
	if err != nil {
		return speipayment.Payment{}, err
	}
	return result, nil
}

// getPendingSPEIPaymentTx — lookup común de Approve/Reject: la fila (con
// FOR UPDATE) y su Beneficiario. Lanza shared.ErrNotFound o
// shared.ErrInvalidState (si no estaba pending_approval).
func (s *SPEIStore) getPendingSPEIPaymentTx(ctx context.Context, paymentID string) (speipayment.Payment, beneficiary.Beneficiary, error) {
	var (
		payment speipayment.Payment
		ben     beneficiary.Beneficiary
	)
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		row, err := q.GetSPEIPaymentForUpdate(ctx, paymentID)
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}
		payment = mapper.ToSPEIPayment(row)
		if payment.Status != approval.OperationStatusPendingApproval {
			return shared.ErrInvalidState
		}
		benRow, err := q.GetBeneficiaryByID(ctx, payment.BeneficiaryID)
		if err != nil {
			return err
		}
		ben = mapper.ToBeneficiary(benRow)
		return nil
	})
	if err != nil {
		return speipayment.Payment{}, beneficiary.Beneficiary{}, err
	}
	return payment, ben, nil
}

// trySPEIExecute — debita la Cuenta y despacha [payment] al SPEIGateway;
// nunca escribe en spei_payments ni en audit_log, el llamador decide
// cuándo y con qué resolved_by (mismo split que approval.go's
// tryExecute/Request/Approve). Si el proveedor rechaza el pago después
// de debitar, revierte con un crédito compensatorio de inmediato — nunca
// deja al Tarjetahabiente con el monto descontado sin un pago real en
// curso.
func (s *SPEIStore) trySPEIExecute(ctx context.Context, payment speipayment.Payment, ben beneficiary.Beneficiary) (speipayment.Payment, error) {
	if _, err := s.postAccountEntry(ctx, payment.AccountID, ledger.EntryDebit, payment.Amount, "Pago SPEI a "+ben.Alias); err != nil {
		if errors.Is(err, shared.ErrInsufficientFunds) {
			notes := "Fondos insuficientes."
			payment.Status = approval.OperationStatusFailed
			payment.ResolutionNotes = &notes
			return payment, nil
		}
		return speipayment.Payment{}, err
	}

	ref, err := s.gateway.DispatchPayment(ctx, payment, ben)
	if err != nil {
		if _, creditErr := s.postAccountEntry(ctx, payment.AccountID, ledger.EntryCredit, payment.Amount, "Reverso: pago SPEI rechazado por el proveedor"); creditErr != nil {
			return speipayment.Payment{}, creditErr
		}
		notes := "El proveedor SPEI rechazó el pago; el monto fue reversado."
		payment.Status = approval.OperationStatusFailed
		payment.ResolutionNotes = &notes
		return payment, nil
	}

	payment.Status = approval.OperationStatusExecuted
	payment.ProviderReference = &ref
	return payment, nil
}

// persistSPEIResolution — el único UPDATE de spei_payments tras
// trySPEIExecute, con su fila de audit_log. resolvedByEmail es nil para
// el auto-ejecutado por debajo del umbral (ver CreatePayment) — no lo
// "aprobó" nadie.
func (s *SPEIStore) persistSPEIResolution(ctx context.Context, payment speipayment.Payment, resolvedByEmail *string) error {
	return s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var resolvedByID *string
		if resolvedByEmail != nil {
			id, err := q.GetStaffUserIDByEmail(ctx, *resolvedByEmail)
			if err != nil {
				return err
			}
			resolvedByID = &id
		}
		if err := q.UpdateSPEIPaymentStatus(ctx, sqlcgen.UpdateSPEIPaymentStatusParams{
			ID:                payment.ID,
			Status:            sqlcgen.OperationStatus(payment.Status),
			ResolvedBy:        resolvedByID,
			ResolutionNotes:   payment.ResolutionNotes,
			ProviderReference: payment.ProviderReference,
		}); err != nil {
			return err
		}
		metadata := map[string]any(nil)
		if resolvedByEmail != nil {
			metadata = map[string]any{"resolved_by_email": *resolvedByEmail}
		}
		return logCallerAudit(ctx, q, "spei_payment_"+string(payment.Status), "spei_payment", payment.ID, metadata)
	})
}

// postAccountEntry — igual que Store.PostEntry pero resolviendo el
// ledger_account por account_id directo, no por cardID a través de una
// tarjeta: SPEI se dirige a la Cuenta Individual incluso cuando todavía
// no tiene ninguna tarjeta asignada (ver
// docs/adr/0020-cuenta-individual-tarjetahabiente.md).
func (s *SPEIStore) postAccountEntry(ctx context.Context, accountID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error) {
	var result ledger.Entry
	err := s.withRLS(ctx, func(q *sqlcgen.Queries) error {
		var err error
		result, err = s.postAccountEntryTx(ctx, q, accountID, entryType, amount, description)
		return err
	})
	if err != nil {
		return ledger.Entry{}, err
	}
	return result, nil
}

func (s *SPEIStore) postAccountEntryTx(ctx context.Context, q *sqlcgen.Queries, accountID string, entryType ledger.EntryType, amount float64, description string) (ledger.Entry, error) {
	account, err := q.GetLedgerAccountByAccountIDForUpdate(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return ledger.Entry{}, shared.ErrNotFound
	}
	if err != nil {
		return ledger.Entry{}, err
	}

	current, err := q.GetLatestLedgerBalance(ctx, account.ID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return ledger.Entry{}, err
	}

	newBalance := current
	if entryType == ledger.EntryCredit {
		newBalance += amount
	} else {
		newBalance -= amount
	}
	if newBalance < 0 {
		return ledger.Entry{}, shared.ErrInsufficientFunds
	}

	desc := description
	row, err := q.InsertLedgerEntry(ctx, sqlcgen.InsertLedgerEntryParams{
		ClientID:        account.ClientID,
		LedgerAccountID: account.ID,
		EntryType:       sqlcgen.LedgerEntryType(entryType),
		Amount:          amount,
		BalanceAfter:    newBalance,
		Description:     &desc,
	})
	if err != nil {
		return ledger.Entry{}, err
	}
	return ledger.Entry{
		ID:           row.ID,
		Type:         entryType,
		Amount:       row.Amount,
		BalanceAfter: row.BalanceAfter,
		Description:  description,
		CreatedAt:    row.CreatedAt,
	}, nil
}

// HandleDeposit — el webhook entrante de un proveedor SPEI (simulado o
// real). Sin identidad de llamador (nadie hizo login: es un proveedor
// externo) — corre con RLS bypaseado, igual que Login/Activate, y audita
// con logSystemAudit en vez de logCallerAudit. Idempotente por
// [providerReference]: una entrega repetida del proveedor devuelve el
// mismo depósito ya existente, sin acreditar el ledger dos veces.
func (s *SPEIStore) HandleDeposit(ctx context.Context, clabeNumber string, amount float64, providerReference string) (speipayment.Deposit, error) {
	var result speipayment.Deposit
	err := s.withRLSBypass(ctx, func(q *sqlcgen.Queries) error {
		acct, err := q.GetIndividualAccountByCLABE(ctx, pgtype.Text{String: clabeNumber, Valid: true})
		if errors.Is(err, pgx.ErrNoRows) {
			return shared.ErrNotFound
		}
		if err != nil {
			return err
		}

		row, err := q.CreateSPEIDeposit(ctx, sqlcgen.CreateSPEIDepositParams{
			ClientID:          acct.ClientID,
			AccountID:         acct.ID,
			Amount:            amount,
			ProviderReference: providerReference,
		})
		if errors.Is(err, pgx.ErrNoRows) {
			// ON CONFLICT (provider_reference) DO NOTHING — ya se procesó
			// esta entrega antes; se devuelve el mismo depósito sin
			// acreditar el ledger otra vez (idempotencia, ADR-0021 punto 8).
			existing, err := q.GetSPEIDepositByProviderReference(ctx, providerReference)
			if err != nil {
				return err
			}
			result = mapper.ToSPEIDeposit(existing)
			return nil
		}
		if err != nil {
			return err
		}

		// Acredita la Cuenta de inmediato, en la misma transacción que el
		// registro del depósito — conciliación automática (ADR-0021, punto
		// 8), nunca pasa por el paso manual de Colectora.
		if _, err := s.postAccountEntryTx(ctx, q, acct.ID, ledger.EntryCredit, amount, "Depósito SPEI"); err != nil {
			return err
		}

		result = mapper.ToSPEIDeposit(row)
		return logSystemAudit(ctx, q, "spei_deposit_received", "spei_deposit", row.ID, map[string]any{"amount": amount, "provider_reference": providerReference})
	})
	if err != nil {
		return speipayment.Deposit{}, err
	}
	return result, nil
}
