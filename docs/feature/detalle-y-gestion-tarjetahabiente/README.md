# Detalle y gestión de Tarjetahabiente

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake mutable)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control de acceso roto — editar/desactivar sin verificar rol) y 4 (trazabilidad de cambios)
- Roles/actores involucrados: Super Admin, Admin Cliente (pueden gestionar); Operador, Auditor (solo ven)

## Objetivo
Ver la información completa de un tarjetahabiente y, si el rol lo permite,
editarla o desactivarlo. Se llega aquí tanto desde
`docs/feature/tarjetahabientes-por-cliente/` como desde
`docs/feature/listado-global-tarjetahabientes/` — es la misma pantalla.

## Contexto / motivación
Primera feature de KBM que muta datos (no solo lee) fuera del flujo de
aprobación de saldos — por eso la regla de autorización se documenta
explícitamente en `docs/business/roles-and-permissions.md` en vez de
asumirse.

## Nota de alcance de esta iteración
`CardholderRepository` pasa de ser puramente de lectura a soportar
`update` y `setActive` sobre una lista mutable en memoria (sigue sin
backend real). Los cambios persisten mientras la app esté abierta, se
pierden al recargar — comportamiento esperado de un repositorio fake, no
un bug.

## Flujo principal
1. El usuario hace clic en un tarjetahabiente (desde cualquiera de los dos
   listados).
2. Ve su información, organizada en secciones: identificación legal
   (CURP, RFC, tipo/número de identificación oficial, fecha de
   nacimiento, nacionalidad), domicilio, contacto (email, teléfono),
   perfil de cumplimiento (PEP), Cliente al que pertenece, y estado
   (activo/inactivo). Ver `docs/business/kyc-tarjetahabiente.md` para el
   detalle y la razón de negocio de cada campo.
3. Si su rol lo permite (Super Admin o Admin Cliente): puede editar
   cualquiera de esos campos, y activar/desactivar al tarjetahabiente.
4. Si su rol no lo permite (Operador, Auditor): ve la misma información
   completa, sin los controles de edición/desactivación visibles — ver
   `docs/business/kyc-tarjetahabiente.md` para por qué no se enmascara
   nada por rol en esta iteración.

## Reglas de negocio
Ver `docs/business/roles-and-permissions.md`, sección "Gestión de
Tarjetahabientes (editar / desactivar)" — no se repite aquí. Punto clave:
desactivar **no** requiere aprobación (no es una operación de saldo).

## Casos borde / fuera de alcance
- Validación real de CURP/RFC (dígito verificador): campos de texto libre
  por ahora, ver `docs/business/kyc-tarjetahabiente.md`.
- Cambiar el Cliente al que pertenece un tarjetahabiente ("mover" entre
  empresas): fuera de alcance, no solicitado.
- Historial de cambios (quién editó qué y cuándo): fuera de alcance de
  esta iteración — cuando exista backend real, debe ir a `audit_log` (ver
  `docs/security/threat-model.md` punto 4), no se implementa en el
  repositorio fake.

## Criterios de aceptación
Ver `acceptance.feature`.
