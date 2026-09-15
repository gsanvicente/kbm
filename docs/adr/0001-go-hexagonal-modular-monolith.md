# ADR-0001: Backend en Go con arquitectura hexagonal, como monolito modular

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
KBM debe ser la base de largo plazo del sistema, no un MVP desechable: la
arquitectura y el stack no deben cambiar después, solo iterar en
funcionalidades. El equipo es pequeño (1-3 personas) con horizonte de
meses. El dominio (saldos/ledger financiero) exige integridad y
auditabilidad fuertes.

## Decisión
Backend en Go, con arquitectura hexagonal (puertos y adaptadores):
`internal/domain` (reglas de negocio puras) → `internal/application`
(casos de uso + puertos) → `internal/adapters/*` (Postgres, HTTP, cola,
auth, procesador externo). Se organiza como **monolito modular** (un solo
binario, dividido internamente por bounded context: jerarquía de clientes,
tarjetahabientes/tarjetas, ledger, aprobaciones, reconciliación) en vez de
microservicios desde el día uno.

## Consecuencias
- Cada módulo ya tiene fronteras hexagonales, por lo que puede extraerse a
  su propio servicio más adelante sin rediseñar el dominio.
- Requiere disciplina: mappers explícitos entre entidades de dominio y
  filas de Postgres/DTOs HTTP (ver `internal/adapters/postgres/mapper`,
  `internal/adapters/http/dto`), o el desacople se rompe silenciosamente.
- Ciclo de desarrollo local rápido: un binario compilado, sin necesidad de
  orquestar múltiples servicios para probar cambios.

## Alternativas consideradas
- **Node.js/TypeScript (NestJS)**: descartado por el equipo — se prefirió
  un lenguaje compilado y fuertemente tipado para un ledger financiero de
  largo plazo.
- **Microservicios desde el inicio**: descartado — sobre-ingeniería
  operativa para un equipo de 1-3 personas; el monolito modular ya deja la
  puerta abierta a dividir después.
