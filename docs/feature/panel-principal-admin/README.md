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
2. Desde "Clientes" se lista cada Cliente visible para el usuario: el
   suyo propio, más todos sus descendientes en la jerarquía (ver regla de
   herencia en `docs/business/roles-and-permissions.md`).
3. Un botón de cierre de sesión regresa al login.

## Reglas de negocio
Ver `docs/business/roles-and-permissions.md` — no se repite aquí. En
particular: la visibilidad es unidireccional (un hijo nunca ve al padre ni
a sus hermanas) y aplica a **todos** los roles del padre, no solo Admin
Cliente.

## Casos borde / fuera de alcance
- Búsqueda/filtrado del listado: fuera de alcance de esta iteración.
- Crear/editar Clientes desde esta pantalla: fuera de alcance — esta
  iteración es de solo lectura.

## Criterios de aceptación
Ver `acceptance.feature`.
