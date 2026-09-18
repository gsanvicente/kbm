# Pool y asignación de Tarjetas

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake mutable)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control de acceso — asignar sin verificar rol) y 2 (asignar cruzando Clientes)
- Roles/actores involucrados: Super Admin, Admin Cliente (pueden asignar); Operador, Auditor (solo ven)

## Objetivo
Dar acceso, desde el ítem "Tarjetas" del menú principal, a todas las
tarjetas dentro del alcance del usuario (disponibles y ya asignadas), y
permitir asignar una tarjeta disponible a un Tarjetahabiente.

## Contexto / motivación
Sin esta feature, una tarjeta que llega del procesador no tiene forma de
llegar a manos de un Tarjetahabiente dentro de KBM. Complementa
`docs/feature/tarjetas-de-tarjetahabiente/` (que solo muestra, no asigna).

## Nota de alcance de esta iteración
`CardRepository` fake, mutable (igual que `CardholderRepository` desde
`docs/feature/alta-y-gestion-de-tarjetahabientes/`). El pool de
disponibles es dato semilla fijo — ver
`docs/business/tarjetas-y-asignacion.md` para por qué no hay pantalla de
alta de tarjetas nuevas en esta iteración. **Diseñado, pendiente**:
`CardRepository` migra a un backend Go compartido con `cardholder/` —
ver `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` —
sin cambios en esta pantalla, la interfaz no cambia.

## Flujo principal
1. El usuario entra a "Tarjetas" desde el menú principal.
2. Ve todas las tarjetas dentro de su alcance (jerarquía de Clientes,
   misma regla que el resto del sistema), con su estado — disponibles y
   asignadas mezcladas, distinguibles por el estado visible.
3. Puede acotar el listado con filtros combinables (AND entre categorías,
   sin selección = sin restricción en esa categoría) — son filtros de
   cliente sobre lo que ya ve, nunca cambian qué tarjetas están dentro de
   su alcance:
   - **Estado** (multiselección: Disponible / Activa / Bloqueada /
     Congelada / Cancelada) — combo desplegable con casillas, muestra un
     contador cuando hay selección (ej. "Estado (2)").
   - **Empresa** (multiselección, mismo patrón de combo) — solo aparece
     si el usuario tiene acceso a más de un Cliente; para roles
     acotados a un solo Cliente (Admin Cliente, Operador, Auditor) no
     tendría opciones que filtrar, así que se oculta.
   - **Tarjetahabiente**: cuadro de búsqueda con autocompletar — al
     escribir aparecen sugerencias de nombres que coinciden; al elegir
     una, el listado se acota a las tarjetas de esa persona exacta (las
     Disponibles nunca coinciden, no tienen Tarjetahabiente). Texto
     escrito sin seleccionar una sugerencia no filtra nada por sí solo,
     para evitar coincidencias parciales ambiguas.
   - Un botón "Limpiar filtros" aparece cuando hay alguno activo.
4. En una tarjeta **disponible**, si su rol lo permite, ve el botón
   "Asignar": elige un Tarjetahabiente **activo** del mismo Cliente que
   la tarjeta, y confirma — los Tarjetahabientes inactivos no aparecen
   como opción (ver `docs/business/desactivacion-de-tarjetahabientes.md`).
5. Si el Tarjetahabiente elegido ya alcanzó el límite de tarjetas activas
   configurado para su Cliente, la asignación se rechaza con un mensaje
   explicando el límite — no se le oculta la opción, se le explica por
   qué no se puede.
6. Al asignar: la tarjeta pasa a estado `activa`, queda ligada al
   Tarjetahabiente, y se registra la fecha de asignación.

## Reglas de negocio
Ver `docs/business/tarjetas-y-asignacion.md` — no se repite aquí.

## Casos borde / fuera de alcance
- Revertir una asignación (quitarle la tarjeta a alguien y devolverla al
  pool): fuera de alcance, no solicitado.
- Alta de tarjetas nuevas al pool: fuera de alcance (ver nota de negocio).

## Criterios de aceptación
Ver `acceptance.feature`.
