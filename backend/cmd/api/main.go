package main

import (
	"context"
	"log"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/koons/kbm/backend/internal/adapters/http/handler"
	"github.com/koons/kbm/backend/internal/adapters/http/middleware"
	memrepo "github.com/koons/kbm/backend/internal/adapters/memory/repository"
	pgrepo "github.com/koons/kbm/backend/internal/adapters/postgres/repository"
	"github.com/koons/kbm/backend/internal/platform/config"
)

func main() {
	cfg := config.Load()

	var (
		h       *handler.Handler
		backend string
		closeFn func()
	)

	switch cfg.StorageBackend {
	case "memory":
		// Backend en memoria — modo demo explícito, ver
		// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md y
		// docs/tdr/0003-in-memory-repository-adapter.md. Un solo Store
		// implementa los cuatro ports que este slice necesita.
		store := memrepo.NewStore()
		h = handler.New(store, store, store, store)
		backend = "in-memory"
	case "postgres":
		if cfg.DatabaseURL == "" {
			log.Fatal("STORAGE_BACKEND=postgres requiere DATABASE_URL — ver .env.example")
		}
		ctx := context.Background()
		pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
		if err != nil {
			log.Fatalf("no se pudo conectar a Postgres: %v", err)
		}
		if err := pool.Ping(ctx); err != nil {
			log.Fatalf("Postgres no responde (¿está corriendo? ver backend/README.md, \"Postgres real\"): %v", err)
		}
		store := pgrepo.NewStore(pool)
		h = handler.New(store, store, store, store)
		backend = "postgres"
		closeFn = store.Close
	default:
		log.Fatalf("STORAGE_BACKEND inválido: %q (usa \"postgres\" o \"memory\")", cfg.StorageBackend)
	}
	if closeFn != nil {
		defer closeFn()
	}

	// Solo loopback — nunca 0.0.0.0, ver threat-model.md punto 15. El
	// puerto sigue siendo configurable (HTTP_PORT) para no romper
	// deploys futuros, pero el host queda fijo en desarrollo.
	addr := "127.0.0.1:" + cfg.HTTPPort

	log.Printf("kbm-backend api (%s) listening on %s (env=%s)", backend, addr, cfg.Env)
	if err := http.ListenAndServe(addr, middleware.CORS(h.Routes())); err != nil {
		log.Fatal(err)
	}
}
