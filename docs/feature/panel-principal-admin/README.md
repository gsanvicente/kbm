# Panel principal de administración

- Estado: En desarrollo (esta iteración: shell de navegación + listado de Clientes con repositorio fake)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`, `docs/adr/0002-flutter-web-mobile-two-apps.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 y 2 (control de acceso, fuga de datos entre tenants)
- Roles/actores involucrados: todos los roles de staff (ver `docs/business/roles-and-permissions.md`)

## Objetivo
Dar al usuario autenticado un punto de entrada a la consola: navegación
por secciones del dominio, y el primer listado real (Clientes) respetando
la jerarquía padre/hija.

## Contexto / motivación
Segunda mitad del walking skeleton iniciado en
`docs/feature/login-administrativo/`. Ejercita por primera vez la regla de
visibilidad jerárquica descrita en `docs/business/roles-and-permissions.md`
en una pantalla real.

## Nota de alcance de esta iteración
`ClientRepository` es una implementación fake en memoria que replica la
jerarquía de `backend/scripts/init-db/001_seed.sql` (holding + 2
subsidiarias). Las secciones de Tarjetahabientes, Tarjetas, Operaciones de
Saldo y Aprobaciones se muestran en la navegación como "próximamente" —
sin funcionalidad todavía, para dejar visible la forma final del panel.

## Flujo principal
1. Tras el login, el usuario llega al panel con una barra de navegación
   lateral (secciones del dominio). La sección seleccionada por defecto
   depende del rol: Super Admin y Admin Cliente aterrizan en "Inicio"
   (ver `docs/feature/panel-directivo/README.md`); Operador y Auditor
   siguen aterrizando en "Clientes", como en la versión original de este
   flujo.
2. Desde "Clientes" se ve la jerarquía completa como **árbol** (ver
   "Vista jerárquica" abajo), no una lista plana.
3. Un botón de cierre de sesión regresa al login.

## Vista jerárquica (revisado 2026-09-17)
El listado de Clientes dejó de ser plano — ahora es un **árbol
indentado** (expandir/colapsar por nodo, mismo patrón que un explorador
de archivos), porque la jerarquía real puede tener profundidad arbitraria
(holding → subsidiaria → sub-subsidiaria), no solo los 2 niveles de los
datos de prueba. Tocar un nodo sigue llevando al mismo
`ClientDetailView` de siempre — el árbol solo cambia cómo se **navega
hacia** ahí, no el destino.

**Estado inicial, distinto por rol:**
- **Admin Cliente**: árbol **expandido por defecto** — su propio
  subárbol normalmente es acotado.
- **Super Admin**: árbol **colapsado por defecto** (solo empresas raíz
  visibles) — puede haber varias empresas raíz independientes, cada una
  con su propio árbol; expandir todo de entrada saturaría la pantalla.

**Deliberadamente sin filtro de "Tipo: Matriz/Hija"** — sería
información redundante una vez que el árbol ya muestra la anidación
visualmente.

## Búsqueda (revisado 2026-09-17)
Un campo de búsqueda en vivo por **nombre, razón social o RFC**, que
filtra el árbol mostrando:
- Los nodos que coinciden.
- **Su cadena completa de ancestros** (para no perder el contexto de en
  qué filial está ese resultado), auto-expandiendo esas ramas.
- Nada más — las ramas sin ninguna coincidencia (propia o de un
  descendiente) se ocultan.

Mismo criterio que un explorador de archivos con buscador (VS Code, por
ejemplo) — no una lista de chips de filtro independiente que compita
visualmente con el árbol.

## Breadcrumb con ancestría completa (revisado 2026-09-17)
Antes, entrar al detalle de un Cliente mostraba únicamente "Clientes >
[ese Cliente]" en el breadcrumb, sin importar su profundidad real en la
jerarquía — inconsistente para una filial de tercer nivel. Ahora el
breadcrumb muestra la cadena completa: "Clientes > Grupo Koons Holding >
Koons Subsidiaria A > ...". Cada elemento intermedio es navegable (regresa
al detalle de ese ancestro), igual que el resto de los breadcrumbs de la
app.

## Reglas de negocio
Ver `docs/business/roles-and-permissions.md` — no se repite aquí. En
particular: la visibilidad es unidireccional (un hijo nunca ve al padre ni
a sus hermanas) y aplica a **todos** los roles del padre, no solo Admin
Cliente.

## Casos borde / fuera de alcance
- Crear/editar/desactivar un Cliente: fuera de esta pantalla — el
  listado (árbol) sigue siendo de solo lectura/navegación; esas acciones
  viven en `docs/feature/alta-y-gestion-de-clientes/README.md`.
- Búsqueda por objeto social/giro, o por otros campos del expediente KYB:
  fuera de alcance — solo nombre/razón social/RFC por ahora.
- Recordar el estado expandido/colapsado entre sesiones: fuera de
  alcance, siempre se recalcula el estado inicial por rol al entrar.

## Criterios de aceptación
Ver `acceptance.feature`.
