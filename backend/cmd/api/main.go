package main

import (
	"log"
	"net/http"

	"github.com/koons/kbm/backend/internal/adapters/http/handler"
	"github.com/koons/kbm/backend/internal/adapters/http/middleware"
	memrepo "github.com/koons/kbm/backend/internal/adapters/memory/repository"
	"github.com/koons/kbm/backend/internal/platform/config"
)

func main() {
	cfg := config.Load()

	// Backend en memoria — ver
	// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md y
	// docs/tdr/0003-in-memory-repository-adapter.md. Un solo Store
	// implementa los cuatro ports que este slice necesita.
	store := memrepo.NewStore()
	h := handler.New(store, store, store, store)

	// Solo loopback — nunca 0.0.0.0, ver threat-model.md punto 15. El
	// puerto sigue siendo configurable (HTTP_PORT) para no romper
	// deploys futuros, pero el host queda fijo en desarrollo.
	addr := "127.0.0.1:" + cfg.HTTPPort

	log.Printf("kbm-backend api (in-memory) listening on %s (env=%s)", addr, cfg.Env)
	if err := http.ListenAndServe(addr, middleware.CORS(h.Routes())); err != nil {
		log.Fatal(err)
	}
}
