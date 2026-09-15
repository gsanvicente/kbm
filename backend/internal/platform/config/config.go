package config

import "os"

type Config struct {
	Env         string
	HTTPPort    string
	DatabaseURL string
	JWTSecret   string
}

func Load() Config {
	return Config{
		Env:         getenv("APP_ENV", "local"),
		HTTPPort:    getenv("HTTP_PORT", "8080"),
		DatabaseURL: getenv("DATABASE_URL", ""),
		JWTSecret:   getenv("JWT_SECRET", ""),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
