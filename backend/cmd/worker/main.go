package main

import "log"

// Composition root for the async worker: relays internal/adapters/outbox
// events (reconciliation, notifications) once those adapters exist.
func main() {
	log.Println("kbm-backend worker started (outbox relay placeholder)")
	select {}
}
