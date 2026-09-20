// Package client holds the Cliente entity, its KYB expediente, and
// parent/child hierarchy business rules. No DB/HTTP dependencies. See
// docs/business/kyb-cliente.md and
// admin/lib/core/models/client.dart (the Dart shape this mirrors).
package client

import (
	"time"

	"github.com/koons/kbm/backend/internal/domain/shared"
)

// TipoPoder — ver admin/lib/core/models/tipo_poder.dart.
type TipoPoder string

const (
	TipoPoderActosDeAdministracion TipoPoder = "actos_de_administracion"
	TipoPoderPleitosYCobranzas     TipoPoder = "pleitos_y_cobranzas"
	TipoPoderActosDeDominio        TipoPoder = "actos_de_dominio"
	TipoPoderEspecial              TipoPoder = "especial"
)

// RequiereDescripcion — solo "especial" requiere describir libremente las
// facultades otorgadas.
func (t TipoPoder) RequiereDescripcion() bool { return t == TipoPoderEspecial }

// ActaConstitutiva — datos del instrumento notarial que constituye
// legalmente a un Cliente. Solo datos estructurados en esta iteración,
// sin carga del PDF real.
type ActaConstitutiva struct {
	NumeroEscritura string
	Notario         string
	Plaza           string
	Fecha           time.Time
	FolioRPC        string
}

// ApoderadoLegal — persona física con poder notarial para actuar en
// nombre de un Cliente frente a KBM. Cada Cliente tiene exactamente un
// apoderado con EsPrincipal=true.
type ApoderadoLegal struct {
	ID                       string
	Persona                  shared.PersonaFisica
	TipoPoder                TipoPoder
	DescripcionPoderEspecial *string
	NumeroEscritura          string
	Notario                  string
	FechaInstrumento         time.Time
	Vigencia                 *time.Time
	EsPrincipal              bool
}

// BeneficiarioControlador — persona física que en última instancia posee
// o controla un Cliente (PLD/LFPIORPI). Cada Cliente tiene exactamente
// un beneficiario con EsMayoritario=true.
type BeneficiarioControlador struct {
	ID                      string
	Persona                 shared.PersonaFisica
	PorcentajeParticipacion float64
	IsPoliticallyExposed    bool
	EsMayoritario           bool
}

// Client — el expediente KYB completo empieza en RazonSocial; todos esos
// campos son punteros porque un Cliente sembrado sin expediente completo
// sigue siendo válido (ver admin/lib/core/models/client.dart).
type Client struct {
	ID             string
	Name           string
	ParentClientID *string
	IsActive       bool

	RazonSocial       *string
	NombreComercial   *string
	RFC               *string
	FechaConstitucion *time.Time
	ObjetoSocial      *string
	ActaConstitutiva  *ActaConstitutiva

	AddressStreet       *string
	AddressNeighborhood *string
	AddressCity         *string
	AddressState        *string
	AddressPostalCode   *string
	AddressCountry      string

	Apoderados                 []ApoderadoLegal
	BeneficiariosControladores []BeneficiarioControlador
}

func (c Client) ApoderadoPrincipal() *ApoderadoLegal {
	for i := range c.Apoderados {
		if c.Apoderados[i].EsPrincipal {
			return &c.Apoderados[i]
		}
	}
	return nil
}

func (c Client) BeneficiarioMayoritario() *BeneficiarioControlador {
	for i := range c.BeneficiariosControladores {
		if c.BeneficiariosControladores[i].EsMayoritario {
			return &c.BeneficiariosControladores[i]
		}
	}
	return nil
}
