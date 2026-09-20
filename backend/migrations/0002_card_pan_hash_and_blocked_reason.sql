-- pan_hash backs the C2C transfer destination lookup (see
-- docs/adr/0009-pan-hash-transit-for-c2c-transfers.md) — the full PAN
-- itself is never persisted, only its HMAC-SHA256. Nullable: a card in
-- the "unassigned" pool has no PAN to hash from the app's perspective
-- yet in this iteration (no processor integration). A card issued later
-- through a real processor gets this populated at assignment time once
-- that integration exists (see
-- docs/adr/0011-processor-integration-architecture-and-postgres-default.md).
ALTER TABLE cards ADD COLUMN pan_hash text;

-- Matches the query ResolveDestination runs: same Cliente as the origin
-- card, matching hash.
CREATE INDEX ON cards (client_id, pan_hash);

-- internal/domain/card/card.go's BlockedReason (manual vs.
-- cardholder_inactive, see docs/business/tarjetas-y-asignacion.md,
-- "Motivo de bloqueo") had no column here yet — the in-memory adapter
-- (docs/adr/0010) tracked it only in Go, this table never needed it
-- until now. Only meaningful while status = 'blocked'.
CREATE TYPE card_blocked_reason AS ENUM ('manual', 'cardholder_inactive');
ALTER TABLE cards ADD COLUMN blocked_reason card_blocked_reason;
ALTER TABLE cards ADD CONSTRAINT cards_blocked_reason_only_when_blocked
    CHECK (status = 'blocked' OR blocked_reason IS NULL);
