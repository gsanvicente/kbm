.PHONY: db-up db-down db-reset run run-worker test lint

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

# Drops the local volume so 0001_init.sql/0002_seed.sql re-run from scratch.
db-reset:
	docker compose down -v
	docker compose up -d postgres

run:
	go run ./cmd/api

run-worker:
	go run ./cmd/worker

test:
	go test ./...

lint:
	go vet ./...
