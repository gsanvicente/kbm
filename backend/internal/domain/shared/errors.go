package shared

import "errors"

// Sentinel errors shared across domain packages so adapters (HTTP, etc.)
// can map them to the right status/response without importing domain internals.
var (
	ErrNotFound     = errors.New("resource not found")
	ErrForbidden    = errors.New("operation not permitted")
	ErrInvalidState = errors.New("invalid state transition")
	ErrValidation   = errors.New("validation failed")
)
