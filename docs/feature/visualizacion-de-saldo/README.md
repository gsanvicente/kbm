# Visualización de saldo de Tarjeta

- Estado: Implementado contra Postgres (`HttpLedgerRepository` por default — ver `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`; `FakeLedgerRepository` solo para `flutter test`, solo lectura)
- ADR/TDR relacionados: `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`
- Amenazas relevantes: `docs/security/threat-model.md` punto 1 (control de acceso a datos financieros)
- Roles/actores involucrados: todos los roles de staff (ver `docs/business/roles-and-permissions.md`) — es solo lectura, no hay gating de rol nuevo

## Objetivo
Mostrar el saldo actual de una tarjeta en el listado de Tarjetas y en su
detalle — primer paso visible de "manejo de saldos", antes de construir
fondeo/débito/transferencia.

## Contexto / motivación
Sienta las bases visuales (de dónde se lee el dato, cómo se distingue
"sin cuenta" de "cuenta en cero") antes de construir las operaciones que
lo modifican. Ver `docs/business/saldo-y-ledger.md` para el modelo
completo.

## Nota de alcance de esta iteración
- Nuevo `LedgerRepository` fake, de solo lectura (`getByCard`,
  `getByCards`) — sin `update`/`credit`/`debit` todavía.
- Los montos son datos semilla fijos, no el resultado de ningún cálculo
  sobre movimientos (no hay `ledger_entries` implementadas en el
  repositorio fake, solo el saldo resultante). El backend real sí sembró
  un movimiento inicial por cuenta (`backend/scripts/init-db/001_seed.sql`)
  para que el dato tenga trazabilidad desde el día uno, aunque el
  repositorio fake no lo replique.

## Flujo principal
1. En el listado de Tarjetas (global o dentro de un Tarjetahabiente), cada
   fila de una tarjeta **asignada** muestra su saldo actual.
2. Una tarjeta **disponible** no muestra un monto — muestra que no tiene
   cuenta de saldo (no "$0.00", que sería engañoso).
3. En el detalle de una tarjeta, el saldo se muestra de forma prominente
   (es el dato central de la aplicación), separado de la tarjeta visual
   grande — una tarjeta física real nunca muestra el saldo impreso.

## Reglas de negocio
Ver `docs/business/saldo-y-ledger.md` — no se repite aquí.

## Casos borde / fuera de alcance
- Fondear, debitar, transferir: fuera de alcance, ver nota de negocio.
- Historial de movimientos: implementado por separado, ver
  `docs/feature/reclamos-de-movimientos/`.

## Criterios de aceptación
Ver `acceptance.feature`.
