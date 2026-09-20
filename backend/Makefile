.PHONY: db-up db-down db-reset run run-worker test lint

# DATABASE_URL (y el resto de .env) tienen que llegar como variables de
# entorno a `go run` — `-include` + `export` hace que todo lo que
# make lea de .env se propague a los targets de abajo. Silencioso si
# .env no existe (ver .env.example).
-include .env
export

# Podman, no Docker Desktop — ver docs/adr/0004-aws-fargate-terraform-local-no-containers.md.
# docker-compose.yml no cambia; `podman compose` lo consume igual, vía
# podman-compose (`brew install podman-compose`).
db-up:
	podman compose up -d postgres

db-down:
	podman compose down

# Drops the local volume so migrations/*.sql y scripts/init-db/001_seed.sql
# re-run from scratch.
db-reset:
	podman compose down -v
	podman compose up -d postgres

run:
	go run ./cmd/api

run-worker:
	go run ./cmd/worker

test:
	go test ./...

lint:
	go vet ./...
