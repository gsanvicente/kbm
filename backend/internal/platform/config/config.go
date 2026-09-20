package config

import "os"

type Config struct {
	Env         string
	HTTPPort    string
	DatabaseURL string
	JWTSecret   string

	// StorageBackend selecciona el adaptador de Cards/Ledger: "postgres"
	// (default, ver docs/adr/0011-processor-integration-architecture-and-postgres-default.md)
	// o "memory" (modo demo explícito, ver
	// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md) —
	// nunca se infiere de APP_ENV, para poder correr Postgres en local
	// (APP_ENV=local) sin ambigüedad.
	StorageBackend string
}

func Load() Config {
	return Config{
		Env:            getenv("APP_ENV", "local"),
		HTTPPort:       getenv("HTTP_PORT", "8080"),
		DatabaseURL:    getenv("DATABASE_URL", ""),
		JWTSecret:      getenv("JWT_SECRET", ""),
		StorageBackend: getenv("STORAGE_BACKEND", "postgres"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
