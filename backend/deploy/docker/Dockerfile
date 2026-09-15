# Not used for local development (see docker-compose.yml / README) — this
# builds the deployable image for AWS (ECS Fargate). Multi-stage keeps the
# runtime image minimal and dependency-free.
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/api /api
USER nonroot:nonroot
ENTRYPOINT ["/api"]
