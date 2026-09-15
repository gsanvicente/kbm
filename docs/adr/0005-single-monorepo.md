# ADR-0005: Monorepo único `kbm` en vez de 3 repositorios independientes

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
El proyecto arrancó con 3 repositorios independientes (`kbm-backend`,
`kbm-admin`, `kbm-cardholder`), pensados para subirse a GitHub por
separado. Esto dejó sin resolver dónde vive la documentación cross-cutting
(reglas de negocio, ADRs de sistema, seguridad) sin duplicarla ni elegir
arbitrariamente un repo "canónico".

## Decisión
Fusionar los 3 repos en un único repositorio `kbm`, con `backend/`,
`admin/` y `cardholder/` como carpetas de primer nivel. `docs/{adr,
feature, business, security}/` vive en la raíz como fuente única de
verdad a nivel de sistema. Las decisiones técnicas locales a un componente
(TDR) quedan dentro de `<componente>/docs/tdr/`.

## Consecuencias
- PRs/commits atómicos entre componentes (una feature que toca backend +
  admin + cardholder se revisa como un solo cambio).
- Un solo `git tag` congela el estado exacto de los 3 componentes a la vez
  — útil para reproducibilidad ante auditoría de seguridad.
- Un solo PR template / CI (con path filters) para forzar la regla de "no
  desarrollo sin documentación" en todo el sistema.
- Se pierde el control de acceso granular por repositorio de GitHub — si
  en el futuro un colaborador externo debe ver solo un componente, ese
  componente tendría que separarse a su propio repo en ese momento.
- Al clonar el monorepo, `docs/` siempre viaja junto con el código — evita
  el riesgo real de que alguien con solo un repo clonado (en el esquema de
  3 repos) nunca tenga la documentación de negocio/seguridad actualizada
  localmente.

## Alternativas consideradas
- **3 repos, `kbm-backend` como dueño canónico de `business/`/ADRs**:
  descartada — el dominio de negocio no es propiedad del backend.
- **3 repos + un 4to repo `kbm-docs` solo de documentación**: descartada —
  repo adicional sin beneficio de atomicidad.
- **3 repos + superproyecto `kbm` con git submodules**: descartada por
  ahora — la fricción de submodules (HEAD separado, punteros que se
  olvidan actualizar) no se justifica para un equipo de 1-3 personas;
  revisitar antes de una auditoría formal o cuando se necesiten pruebas de
  integración reales entre los 3 componentes.
