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

	// SPEIWebhookSecret — el webhook de depósito SPEI entrante
	// (docs/adr/0021-conector-spei.md) no tiene sesión JWT (lo llama un
	// proveedor externo, nunca un usuario logueado): se autentica con este
	// secreto compartido en vez, comparado en
	// internal/adapters/http/handler/handler_spei.go. Placeholder hasta
	// elegir un proveedor real, que traería su propio esquema de firma.
	SPEIWebhookSecret string
}

func Load() Config {
	return Config{
		Env:               getenv("APP_ENV", "local"),
		HTTPPort:          getenv("HTTP_PORT", "8080"),
		DatabaseURL:       getenv("DATABASE_URL", ""),
		JWTSecret:         getenv("JWT_SECRET", ""),
		StorageBackend:    getenv("STORAGE_BACKEND", "postgres"),
		SPEIWebhookSecret: getenv("SPEI_WEBHOOK_SECRET", ""),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
