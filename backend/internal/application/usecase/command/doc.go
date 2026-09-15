// Package command holds use cases that mutate state (create balance
// operation, approve/reject, block a card, ...). These always go through
// full domain validation and the approval workflow. Kept separate from
// package query so read-heavy paths can evolve (e.g. read replicas,
// materialized views) without touching write logic.
package command
