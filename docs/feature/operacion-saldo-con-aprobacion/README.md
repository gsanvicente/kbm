# Operación de saldo con aprobación configurable

- Estado: Draft
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1, 2 y 4
- Roles/actores involucrados: Operador, Admin Cliente, Tarjetahabiente (autoservicio)

## Objetivo
Permitir que un Operador (o el propio Tarjetahabiente vía autoservicio)
solicite una operación de saldo (carga, débito, transferencia,
bloqueo/desbloqueo) sobre una tarjeta, respetando las reglas de aprobación
configuradas por el Cliente dueño de esa tarjeta y la jerarquía
padre/hija.

## Contexto / motivación
Ver `docs/business/approval-policy.md` para el modelo completo. Esta
feature es el primer caso de uso "de escritura" real del sistema — sienta
el patrón (estado, autorización, ledger) que seguirán el resto de
operaciones.

## Flujo principal
1. El solicitante (Operador o Tarjetahabiente) pide una operación sobre
   una tarjeta.
2. El backend resuelve si el solicitante tiene alcance sobre esa tarjeta
   (su Cliente, o un ancestro en la jerarquía — ver
   `docs/business/roles-and-permissions.md`).
3. Se evalúan las `approval_rules` del Cliente dueño de la tarjeta para
   ese tipo de operación/monto.
4. Sin aprobación requerida → se ejecuta de inmediato, se escribe el
   movimiento en el ledger.
5. Con aprobación requerida → queda `pending_approval`; el Admin Cliente
   correspondiente la aprueba o rechaza.
6. Aprobada → se ejecuta igual que el paso 4. Rechazada → se cierra sin
   tocar el ledger.

## Reglas de negocio
Ver `docs/business/approval-policy.md` y
`docs/business/roles-and-permissions.md` — no se repiten aquí.

## Casos borde / fuera de alcance
- Qué pasa si el Cliente dueño de la tarjeta no tiene ningún Admin Cliente
  activo (¿escala al Admin de la empresa padre?) — **pendiente de
  definir con negocio, no implementar hasta resolverlo**.
- Operaciones concurrentes sobre la misma tarjeta (ej. dos débitos a la
  vez) — fuera de alcance de este documento, requiere su propio análisis
  de concurrencia antes de implementarse.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
