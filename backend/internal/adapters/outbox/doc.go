// Package outbox relays rows written to the outbox_events table (same transaction as the triggering use case) to the queue adapter, guaranteeing at-least-once delivery of domain events.
package outbox
