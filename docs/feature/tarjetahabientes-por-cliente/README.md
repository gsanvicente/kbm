# Tarjetahabientes por Cliente

- Estado: En desarrollo (esta iteración: drill-down en `admin/` con repositorio fake)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`, `docs/adr/0007-custom-design-system-koons-tokens.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 y 2 (control de acceso, fuga de datos entre tenants)
- Roles/actores involucrados: todos los roles de staff (ver `docs/business/roles-and-permissions.md`)

## Objetivo
Permitir al usuario navegar de un Cliente (empresa) a sus Tarjetahabientes,
como segundo nivel de la jerarquía Cliente → Tarjetahabiente → Tarjeta.

## Contexto / motivación
Continuación directa de `docs/feature/panel-principal-admin/`. No introduce
una regla de autorización nueva: la visibilidad de Clientes ya resuelve
qué Clientes puede ver el usuario (jerarquía padre/hija); esta feature solo
agrega un nivel de navegación hacia abajo desde un Cliente ya visible.

## Nota de alcance de esta iteración
`CardholderRepository` es una implementación fake en memoria, con los
mismos tarjetahabientes que `backend/scripts/init-db/001_seed.sql`
(2 por subsidiaria). "Grupo Koons Holding" no tiene tarjetahabientes
propios a propósito — una holding típicamente no emite tarjetas
directamente, solo sus subsidiarias — esto ejercita el estado vacío de la
UI.

## Flujo principal
1. Desde el listado de Clientes, el usuario hace clic en un Cliente.
2. Se muestra el listado de sus Tarjetahabientes, con un breadcrumb
   ("Clientes / {nombre del cliente}") para volver.
3. Si el Cliente no tiene tarjetahabientes propios, se muestra un estado
   vacío explicativo en vez de una lista en blanco.

## Reglas de negocio
Ninguna nueva — hereda la regla de visibilidad de
`docs/business/roles-and-permissions.md`. Si el usuario pudo ver el
Cliente en el listado anterior, puede ver sus Tarjetahabientes.

## Casos borde / fuera de alcance
- Buscar/filtrar tarjetahabientes: fuera de alcance.
- Ver el detalle completo y gestionar (editar/desactivar) un
  tarjetahabiente: ver `docs/feature/detalle-y-gestion-tarjetahabiente/`
  (esta feature solo cubre el listado, no el detalle).
- Navegar de un Tarjetahabiente a sus Tarjetas: es una feature futura, no
  esta.

## Criterios de aceptación
Ver `acceptance.feature`.
