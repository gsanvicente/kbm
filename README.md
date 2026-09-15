# kbm — Koons Balance Management

Sistema multi-cliente para gestionar saldos de tarjetas/tarjetahabientes:
**Cliente (empresa, con jerarquía padre/hijas) → Tarjetahabiente → Tarjetas**.

Monorepo único (ver `docs/adr/0005-single-monorepo.md`), con tres
componentes independientes en despliegue pero versionados juntos:

```
backend/       Go, arquitectura hexagonal (monolito modular)
admin/         Flutter web — Super Admin / Admin Cliente / Operador / Auditor
cardholder/    Flutter web + mobile — autoservicio del tarjetahabiente
docs/          documentación de sistema (ver regla MUST abajo)
.github/       plantilla de PR + CI (con path filters por componente)
```

Cada componente tiene su propio `README.md` de setup — empieza por
`backend/README.md`, que también documenta el Postgres local compartido
por todo el sistema.

## Regla MUST: no hay desarrollo sin documentación que lo sustente

Ningún cambio de código se abre en PR sin enlazar al menos uno de estos
documentos (ver `.github/pull_request_template.md`, que lo exige en el
checklist):

```
docs/
├── adr/         Decisiones de arquitectura de sistema completo —
│                estructurales, costosas de revertir (lenguaje, multi-
│                tenancy, cloud, topología de repos...). Nunca se editan
│                una vez Aceptadas: se reemplazan por una nueva ADR.
├── feature/     Una carpeta por feature: README.md (objetivo, flujo,
│                reglas, fuera de alcance) + acceptance.feature (Gherkin)
│                para las reglas de negocio/permisos que necesitan
│                criterios de aceptación no ambiguos.
├── business/    Conocimiento de dominio vigente (glosario, modelo de
│                dominio, roles y permisos, política de aprobación) — a
│                diferencia de adr/, esto SÍ se edita in-place cuando el
│                negocio cambia.
└── security/    Modelo de amenazas, clasificación de datos, notas de
                 compliance — punto de entrada para la auditoría de
                 seguridad de la plataforma.

<componente>/docs/tdr/   Decisiones técnicas LOCALES a ese componente
                          (ej. sqlc vs ORM en backend/, Riverpod vs Bloc
                          en admin/) — si la decisión afecta a más de un
                          componente, es una ADR en la raíz, no una TDR.
```

Cada carpeta tiene una plantilla (`_TEMPLATE.md` / `_TEMPLATE.feature`) —
cópiala en vez de empezar de cero.

### Cuándo usar Gherkin en `feature/`

Solo para las reglas de negocio/permisos/dinero donde la ambigüedad es
peligrosa (aprobaciones, jerarquía de clientes, movimientos de saldo) —
ver `docs/feature/operacion-saldo-con-aprobacion/` como ejemplo real.
Features puramente visuales pueden quedarse con criterios de aceptación
en viñetas dentro del mismo README, justificando por qué no llevan
`.feature`.

## Estado del proyecto

MVP en construcción — arquitectura y stack decididos (ver `docs/adr/`).

- **`admin/`**: primer walking skeleton implementado — login
  (`docs/feature/login-administrativo/`) y panel principal con listado de
  Clientes respetando jerarquía (`docs/feature/panel-principal-admin/`),
  con sistema de diseño propio (`docs/adr/0007-custom-design-system-koons-tokens.md`).
  Corre contra repositorios *fake* en memoria (no contra el backend real
  todavía) — ver la nota de alcance en cada feature doc.
- **`backend/`**: solo scaffolding (entrypoints, esquema de base de datos,
  seed de prueba) — sin casos de uso reales implementados aún. Bloqueado
  para desarrollo real por la falta de Postgres local (ver siguiente
  punto).
- **`cardholder/`**: solo scaffolding, sin pantallas implementadas.

**Entorno de desarrollo (en la máquina donde se hizo este trabajo):** Go y
Flutter instalados en `/usr/local/{go,flutter}`. **Docker no está
instalado todavía** — es necesario para levantar Postgres local (ver
`backend/README.md`) antes de implementar el backend real y reemplazar los
repositorios fake de `admin/`.
