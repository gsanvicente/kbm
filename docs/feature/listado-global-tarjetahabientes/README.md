# Listado global de Tarjetahabientes

- Estado: Implementado contra Postgres (`HttpCardholderRepository` por default — ver `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`; `FakeCardholderRepository` solo para `flutter test`)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`, `docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 y 2
- Roles/actores involucrados: todos los roles de staff

## Objetivo
Dar acceso directo, desde el ítem "Tarjetahabientes" del menú principal, a
todos los tarjetahabientes visibles para el usuario sin tener que navegar
Cliente por Cliente — complementa (no reemplaza) el drill-down de
`docs/feature/tarjetahabientes-por-cliente/`.

## Contexto / motivación
El drill-down exige saber a qué Cliente pertenece la persona que se busca.
Este listado sirve para el caso contrario: "sé el nombre, no sé la
empresa".

## Nota de alcance de esta iteración
Repositorio fake, mismo dataset que las demás features de tarjetahabiente.

## Flujo principal
1. El usuario entra a "Tarjetahabientes" desde el menú principal.
2. Ve una lista de todos los tarjetahabientes de los Clientes dentro de su
   alcance (misma regla de jerarquía que `panel-principal-admin`), con una
   columna/etiqueta indicando a qué Cliente pertenece cada uno.
3. Puede acotar el listado con filtros combinables, mismo componente
   reutilizable que `docs/feature/pool-y-asignacion-de-tarjetas/` (son
   filtros de cliente, nunca cambian qué tarjetahabientes están dentro de
   su alcance):
   - **Empresa** (multiselección, combo con casillas) — oculto si el
     usuario solo tiene acceso a un Cliente.
   - **Estado** (Activo/Inactivo, multiselección) — para encontrar
     rápido a quién no puede operar, ver
     `docs/business/desactivacion-de-tarjetahabientes.md`.
   - **PEP** (Sí/No, multiselección).
   - **Nombre**: cuadro de búsqueda con autocompletar — al elegir una
     sugerencia, el listado se acota a esa persona exacta.
   - Un botón "Limpiar filtros" aparece cuando hay alguno activo.
4. Cada fila muestra un pill de Estado ("Activo"/"Inactivo") y de "PEP"
   si corresponde, para identificar de un vistazo — mismo criterio que
   `docs/feature/tarjetahabientes-por-cliente/`.
5. Al hacer clic en uno, se abre su detalle — ver
   `docs/feature/alta-y-gestion-de-tarjetahabientes/`.

## Reglas de negocio
Ninguna nueva — el conjunto de tarjetahabientes visible es exactamente la
unión de los tarjetahabientes de cada Cliente accesible (ver
`docs/business/roles-and-permissions.md`).

## Casos borde / fuera de alcance
- Filtrar/buscar por documento (CURP, INE, RFC): fuera de alcance — el
  buscador de esta iteración solo indexa el nombre completo.

## Criterios de aceptación
Ver `acceptance.feature`.
