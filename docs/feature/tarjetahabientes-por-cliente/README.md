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
4. Cada fila muestra, además del nombre, un **pill de estado**
   ("Activo"/"Inactivo") y de "PEP" si corresponde, para identificar de
   un vistazo quién no puede operar — ver
   `docs/business/desactivacion-de-tarjetahabientes.md`.
5. Un cuadro de filtros combinables (mismo patrón que
   `docs/feature/listado-global-tarjetahabientes/`): **Estado**
   (Activo/Inactivo) y **PEP** (Sí/No), ambos multiselección.
6. Si el rol tiene `canManageCardholders`, un botón **"+ Nuevo
   Tarjetahabiente"** — ver
   `docs/feature/alta-y-gestion-de-tarjetahabientes/README.md`.

## Reglas de negocio
Ninguna nueva sobre visibilidad — hereda la regla de
`docs/business/roles-and-permissions.md`. Si el usuario pudo ver el
Cliente en el listado anterior, puede ver sus Tarjetahabientes. Crear un
Tarjetahabiente sí tiene su propia regla de rol — ver
`docs/feature/alta-y-gestion-de-tarjetahabientes/README.md`.

## Casos borde / fuera de alcance
- Buscar por nombre desde este listado (a diferencia del filtro por
  Estado/PEP, que sí existe aquí): fuera de alcance — la búsqueda por
  nombre solo existe en
  `docs/feature/listado-global-tarjetahabientes/` (ahí sí tiene sentido,
  porque no se sabe de antemano el Cliente).
- Ver el detalle completo y gestionar (editar/desactivar) un
  tarjetahabiente: ver `docs/feature/alta-y-gestion-de-tarjetahabientes/`
  (esta feature solo cubre el listado, no el detalle).
- Navegar de un Tarjetahabiente a sus Tarjetas: es una feature futura, no
  esta.

## Criterios de aceptación
Ver `acceptance.feature`.
