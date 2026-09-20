package ports

import (
	"context"

	"github.com/koons/kbm/backend/internal/domain/cardholder"
)

// CardholderManagementRepository — el expediente KYC completo que admin/
// gestiona (alta, edición, activar/desactivar), distinto de
// CardholderAuthRepository (solo login del portal de autoservicio). Ver
// docs/feature/alta-y-gestion-de-tarjetahabientes/README.md.
type CardholderManagementRepository interface {
	ListByClient(ctx context.Context, clientID string) ([]cardholder.Cardholder, error)
	ListByClients(ctx context.Context, clientIDs []string) ([]cardholder.Cardholder, error)
	GetByID(ctx context.Context, cardholderID string) (*cardholder.Cardholder, error)

	// Create ignora draft.ID (se asigna uno nuevo).
	Create(ctx context.Context, draft cardholder.Cardholder) (cardholder.Cardholder, error)

	// Update ignora updated.ClientID e updated.IsActive (mover de
	// Cliente sigue fuera de alcance; usar SetActive para el estado).
	Update(ctx context.Context, updated cardholder.Cardholder) (cardholder.Cardholder, error)

	SetActive(ctx context.Context, cardholderID string, isActive bool) (cardholder.Cardholder, error)

	// IsOperable — true solo si cardholderID existe y está activo. Sin
	// cadena de ancestros (a diferencia de ClientRepository.IsOperable).
	IsOperable(ctx context.Context, cardholderID string) (bool, error)
}
