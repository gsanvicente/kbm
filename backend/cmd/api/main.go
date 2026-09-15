package main

import (
	"log"
	"net/http"

	"github.com/koons/kbm/backend/internal/platform/config"
)

func main() {
	cfg := config.Load()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	log.Printf("kbm-backend api listening on :%s (env=%s)", cfg.HTTPPort, cfg.Env)
	if err := http.ListenAndServe(":"+cfg.HTTPPort, mux); err != nil {
		log.Fatal(err)
	}
}
