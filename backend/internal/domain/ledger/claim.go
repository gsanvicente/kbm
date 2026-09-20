package ledger

import "time"

// ClaimStatus mirrors admin/lib/core/models/claim_status.dart.
type ClaimStatus string

const (
	ClaimStatusOpen          ClaimStatus = "open"
	ClaimStatusInReview      ClaimStatus = "in_review"
	ClaimStatusResolvedFavor ClaimStatus = "resolved_favor"
	ClaimStatusRejected      ClaimStatus = "rejected"
)

// MovementClaim — una disputa sobre un Entry ya ejecutado. Nunca muta el
// movimiento mismo — ver docs/business/reclamos-de-movimientos.md. 1:1
// con el Entry al que refiere.
type MovementClaim struct {
	ID               string
	LedgerEntryID    string
	Reason           string
	Status           ClaimStatus
	RequestedByEmail string
	ResolvedByEmail  *string
	ResolutionNotes  *string
	CreatedAt        time.Time
	ResolvedAt       *time.Time
}
