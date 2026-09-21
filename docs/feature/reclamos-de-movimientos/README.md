# Movimientos y Reclamos

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake mutable)
- ADR/TDR relacionados: ninguno nuevo
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control de acceso — resolver sin verificar rol) y 4 (trazabilidad)
- Roles/actores involucrados: Super Admin, Admin Cliente (solicitan y resuelven); Operador (solo solicita); Auditor (solo ve)

## Objetivo
Mostrar el historial de movimientos de una tarjeta y permitir disputar
uno (reclamo), con su resolución — primera funcionalidad real más allá de
solo "mostrar el saldo".

## Contexto / motivación
Cierra el "fuera de alcance" que veníamos dejando explícito en
`docs/business/saldo-y-ledger.md` (historial de movimientos) y agrega la
primera pieza de disputa de negocio. Ver
`docs/business/reclamos-de-movimientos.md` para el modelo completo.

## Nota de alcance de esta iteración
- `CardDetailView` pasa a tener dos pestañas: **Resumen** (lo que ya
  existía) y **Movimientos** (nuevo).
- El detalle de un movimiento (y su reclamo, si tiene) se abre en un
  diálogo — no es un nivel nuevo de breadcrumb, ver nota de negocio.
- `LedgerRepository` (fake) gana `listEntries`, `getClaim`, `fileClaim`,
  `resolveClaim` — mutable, mismo patrón que `CardRepository`.
- **Actualizado 2026-09-21**: `getClaims` (la forma en lote que usa el
  Panel directivo para saber si cada movimiento de cada tarjeta tiene
  reclamo) hacía una llamada HTTP por movimiento
  (`Future.wait` de N `getClaim`) contra el backend Postgres — un
  patrón N+1 real, aunque funcionalmente correcto. Se agregó
  `GET /v1/claims?ledger_entry_ids=a,b,c` (`ports.LedgerRepository.GetClaimsByLedgerEntries`
  en el backend) y `HttpLedgerRepository.getClaims` ahora hace una sola
  llamada. Ver `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`.

## Flujo principal
1. En el detalle de una tarjeta con cuenta de saldo, la pestaña
   "Movimientos" lista sus movimientos: fecha, descripción, tipo
   (crédito/débito), monto y saldo resultante. Un movimiento con reclamo
   muestra un badge de su estado en la fila.
2. Al hacer clic en un movimiento se abre su detalle en un diálogo.
3. Si no tiene reclamo y el rol lo permite (Super Admin, Admin Cliente,
   Operador): botón "Reclamar", pide un motivo (texto libre) y lo crea en
   estado "Abierto".
4. Si ya tiene reclamo: se ve su motivo, estado y (si está resuelto) las
   notas de resolución. Si el rol lo permite (Super Admin, Admin Cliente)
   y el reclamo no está resuelto: botones "Resolver a favor" / "Rechazar",
   piden notas de resolución obligatorias.
5. Una tarjeta sin cuenta de saldo (disponible) muestra la pestaña
   "Movimientos" con el mismo mensaje de "sin cuenta" que ya usa la
   pestaña Resumen.

## Reglas de negocio
Ver `docs/business/reclamos-de-movimientos.md` — no se repite aquí.

## Casos borde / fuera de alcance
Ver la sección "Fuera de alcance" de la nota de negocio.

## Criterios de aceptación
Ver `acceptance.feature`.
