// Package query holds read-only use cases (dashboards, client hierarchy
// views, movement history, audit reports). Separated from package command
// (CQRS-lite) so reporting/scale needs can be addressed independently of
// the write path's invariants.
package query
