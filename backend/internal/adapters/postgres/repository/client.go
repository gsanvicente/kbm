package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/koons/kbm/backend/internal/adapters/postgres/mapper"
	sqlcgen "github.com/koons/kbm/backend/internal/adapters/postgres/sqlc/gen"
	kbmclient "github.com/koons/kbm/backend/internal/domain/client"
	"github.com/koons/kbm/backend/internal/domain/shared"
)

func (s *Store) loadClientDetails(ctx context.Context, row sqlcgen.ListAllClientsRow) (kbmclient.Client, error) {
	apoderadoRows, err := s.q.ListApoderadosByClient(ctx, row.ID)
	if err != nil {
		return kbmclient.Client{}, err
	}
	apoderados := make([]kbmclient.ApoderadoLegal, 0, len(apoderadoRows))
	for _, r := range apoderadoRows {
		apoderados = append(apoderados, mapper.ToApoderado(mapper.ApoderadoRow(r)))
	}

	beneficiarioRows, err := s.q.ListBeneficiariosByClient(ctx, row.ID)
	if err != nil {
		return kbmclient.Client{}, err
	}
	beneficiarios := make([]kbmclient.BeneficiarioControlador, 0, len(beneficiarioRows))
	for _, r := range beneficiarioRows {
		beneficiarios = append(beneficiarios, mapper.ToBeneficiario(mapper.BeneficiarioRow(r)))
	}

	return mapper.ToClient(mapper.ClientRow(row), apoderados, beneficiarios), nil
}

func (s *Store) ListAll(ctx context.Context) ([]kbmclient.Client, error) {
	rows, err := s.q.ListAllClients(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]kbmclient.Client, 0, len(rows))
	for _, r := range rows {
		c, err := s.loadClientDetails(ctx, r)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, nil
}

// Create — asigna un id nuevo, mantiene client_hierarchy (cierre
// transitivo: [nuevo] a sí mismo con profundidad 0, más una fila por
// cada ancestro de draft.ParentClientID a profundidad+1) e inserta
// Apoderados/BeneficiariosControladores, todo en una transacción — ver
// migrations/0001_init.sql, comentario de client_hierarchy.
func (s *Store) Create(ctx context.Context, draft kbmclient.Client) (kbmclient.Client, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return kbmclient.Client{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	var acta struct {
		numeroEscritura, notario, plaza, folioRPC *string
		fecha                                     *time.Time
	}
	if draft.ActaConstitutiva != nil {
		acta.numeroEscritura = &draft.ActaConstitutiva.NumeroEscritura
		acta.notario = &draft.ActaConstitutiva.Notario
		acta.plaza = &draft.ActaConstitutiva.Plaza
		acta.folioRPC = &draft.ActaConstitutiva.FolioRPC
		fecha := draft.ActaConstitutiva.Fecha
		acta.fecha = &fecha
	}
	addressCountry := draft.AddressCountry

	row, err := qtx.CreateClient(ctx, sqlcgen.CreateClientParams{
		Name:                draft.Name,
		ParentClientID:      draft.ParentClientID,
		RazonSocial:         draft.RazonSocial,
		NombreComercial:     draft.NombreComercial,
		Rfc:                 draft.RFC,
		FechaConstitucion:   draft.FechaConstitucion,
		ObjetoSocial:        draft.ObjetoSocial,
		ActaNumeroEscritura: acta.numeroEscritura,
		ActaNotario:         acta.notario,
		ActaPlaza:           acta.plaza,
		ActaFecha:           acta.fecha,
		ActaFolioRpc:        acta.folioRPC,
		AddressStreet:       draft.AddressStreet,
		AddressNeighborhood: draft.AddressNeighborhood,
		AddressCity:         draft.AddressCity,
		AddressState:        draft.AddressState,
		AddressPostalCode:   draft.AddressPostalCode,
		AddressCountry:      &addressCountry,
	})
	if err != nil {
		return kbmclient.Client{}, err
	}

	if err := qtx.InsertHierarchySelf(ctx, row.ID); err != nil {
		return kbmclient.Client{}, err
	}
	if draft.ParentClientID != nil {
		if err := qtx.InsertHierarchyFromParent(ctx, sqlcgen.InsertHierarchyFromParentParams{
			ChildID:  row.ID,
			ParentID: *draft.ParentClientID,
		}); err != nil {
			return kbmclient.Client{}, err
		}
	}

	apoderados, err := insertApoderados(ctx, qtx, row.ID, draft.Apoderados)
	if err != nil {
		return kbmclient.Client{}, err
	}
	beneficiarios, err := insertBeneficiarios(ctx, qtx, row.ID, draft.BeneficiariosControladores)
	if err != nil {
		return kbmclient.Client{}, err
	}

	// Toda empresa nace con su propia Cuenta Concentradora en cero — ver
	// docs/business/tesoreria-cliente.md. Get-or-create: nunca falla ni
	// duplica si algo más ya la creó.
	if _, err := qtx.CreateConcentratorAccount(ctx, row.ID); err != nil {
		return kbmclient.Client{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return kbmclient.Client{}, err
	}

	return mapper.ToClient(mapper.ClientRow(row), apoderados, beneficiarios), nil
}

func insertApoderados(ctx context.Context, q *sqlcgen.Queries, clientID string, drafts []kbmclient.ApoderadoLegal) ([]kbmclient.ApoderadoLegal, error) {
	out := make([]kbmclient.ApoderadoLegal, 0, len(drafts))
	for _, a := range drafts {
		row, err := q.CreateApoderado(ctx, sqlcgen.CreateApoderadoParams{
			ClientID:                 clientID,
			FullName:                 a.Persona.FullName,
			IDDocumentType:           sqlcgen.IDDocumentType(a.Persona.IDDocumentType),
			IDDocumentNumber:         a.Persona.IDDocumentNumber,
			Curp:                     a.Persona.CURP,
			Rfc:                      a.Persona.RFC,
			TipoPoder:                sqlcgen.ClientTipoPoder(a.TipoPoder),
			DescripcionPoderEspecial: a.DescripcionPoderEspecial,
			NumeroEscritura:          a.NumeroEscritura,
			Notario:                  a.Notario,
			FechaInstrumento:         a.FechaInstrumento,
			Vigencia:                 a.Vigencia,
			EsPrincipal:              a.EsPrincipal,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, mapper.ToApoderado(mapper.ApoderadoRow(row)))
	}
	return out, nil
}

func insertBeneficiarios(ctx context.Context, q *sqlcgen.Queries, clientID string, drafts []kbmclient.BeneficiarioControlador) ([]kbmclient.BeneficiarioControlador, error) {
	out := make([]kbmclient.BeneficiarioControlador, 0, len(drafts))
	for _, b := range drafts {
		row, err := q.CreateBeneficiario(ctx, sqlcgen.CreateBeneficiarioParams{
			ClientID:                clientID,
			FullName:                b.Persona.FullName,
			IDDocumentType:          sqlcgen.IDDocumentType(b.Persona.IDDocumentType),
			IDDocumentNumber:        b.Persona.IDDocumentNumber,
			Curp:                    b.Persona.CURP,
			Rfc:                     b.Persona.RFC,
			PorcentajeParticipacion: b.PorcentajeParticipacion,
			IsPoliticallyExposed:    b.IsPoliticallyExposed,
			EsMayoritario:           b.EsMayoritario,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, mapper.ToBeneficiario(mapper.BeneficiarioRow(row)))
	}
	return out, nil
}

// Update — reemplaza el expediente KYB completo, incluidos
// Apoderados/BeneficiariosControladores (delete-all-reinsert, el
// llamador manda la lista final) — ParentClientID e IsActive nunca se
// tocan aquí.
func (s *Store) Update(ctx context.Context, updated kbmclient.Client) (kbmclient.Client, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return kbmclient.Client{}, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	var acta struct {
		numeroEscritura, notario, plaza, folioRPC *string
		fecha                                     *time.Time
	}
	if updated.ActaConstitutiva != nil {
		acta.numeroEscritura = &updated.ActaConstitutiva.NumeroEscritura
		acta.notario = &updated.ActaConstitutiva.Notario
		acta.plaza = &updated.ActaConstitutiva.Plaza
		acta.folioRPC = &updated.ActaConstitutiva.FolioRPC
		fecha := updated.ActaConstitutiva.Fecha
		acta.fecha = &fecha
	}
	addressCountry := updated.AddressCountry

	row, err := qtx.UpdateClient(ctx, sqlcgen.UpdateClientParams{
		ID:                  updated.ID,
		Name:                updated.Name,
		RazonSocial:         updated.RazonSocial,
		NombreComercial:     updated.NombreComercial,
		Rfc:                 updated.RFC,
		FechaConstitucion:   updated.FechaConstitucion,
		ObjetoSocial:        updated.ObjetoSocial,
		ActaNumeroEscritura: acta.numeroEscritura,
		ActaNotario:         acta.notario,
		ActaPlaza:           acta.plaza,
		ActaFecha:           acta.fecha,
		ActaFolioRpc:        acta.folioRPC,
		AddressStreet:       updated.AddressStreet,
		AddressNeighborhood: updated.AddressNeighborhood,
		AddressCity:         updated.AddressCity,
		AddressState:        updated.AddressState,
		AddressPostalCode:   updated.AddressPostalCode,
		AddressCountry:      &addressCountry,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return kbmclient.Client{}, shared.ErrNotFound
	}
	if err != nil {
		return kbmclient.Client{}, err
	}

	if err := qtx.DeleteApoderadosByClient(ctx, updated.ID); err != nil {
		return kbmclient.Client{}, err
	}
	apoderados, err := insertApoderados(ctx, qtx, updated.ID, updated.Apoderados)
	if err != nil {
		return kbmclient.Client{}, err
	}

	if err := qtx.DeleteBeneficiariosByClient(ctx, updated.ID); err != nil {
		return kbmclient.Client{}, err
	}
	beneficiarios, err := insertBeneficiarios(ctx, qtx, updated.ID, updated.BeneficiariosControladores)
	if err != nil {
		return kbmclient.Client{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return kbmclient.Client{}, err
	}
	return mapper.ToClient(mapper.ClientRow(row), apoderados, beneficiarios), nil
}

// SetActive — cascada a [clientID] y TODOS sus descendientes, un solo
// UPDATE — ver docs/business/desactivacion-de-clientes.md.
func (s *Store) SetActive(ctx context.Context, clientID string, active bool) (kbmclient.Client, error) {
	descendantIDs, err := s.q.ListDescendantClientIDs(ctx, clientID)
	if err != nil {
		return kbmclient.Client{}, err
	}
	targets := append([]string{clientID}, descendantIDs...)

	rows, err := s.q.SetClientActiveByIDs(ctx, sqlcgen.SetClientActiveByIDsParams{
		IsActive:  active,
		ClientIds: targets,
	})
	if err != nil {
		return kbmclient.Client{}, err
	}
	for _, r := range rows {
		if r.ID == clientID {
			return s.loadClientDetails(ctx, sqlcgen.ListAllClientsRow(r))
		}
	}
	return kbmclient.Client{}, shared.ErrNotFound
}

func (s *Store) IsOperable(ctx context.Context, clientID string) (bool, error) {
	return s.q.IsClientOperable(ctx, clientID)
}
