# ADR-0008: `fl_chart` como librería de gráficas para el Panel directivo

- Estado: Aceptada
- Fecha: 2026-09-17

## Contexto
`docs/feature/panel-directivo/README.md` necesita una gráfica de volumen
de movimientos (barras apiladas por semana). Flutter no trae gráficas
nativas, y ADR-0007 ya había descartado agregar librerías de UI de
terceros (`shadcn_ui`) para no ceder control de marca ni sumar
dependencias sin justificación clara. Esa decisión fue sobre librerías de
**componentes** generales (botones, inputs, layout) — este caso es
distinto: es la primera necesidad de **visualización de datos**, algo que
construir a mano (CustomPainter) es sustancialmente más costoso que un
botón o un input.

Como la plataforma será auditada en seguridad
(`docs/business/kbm_security_mindset` / memoria del proyecto), cualquier
dependencia nueva es superficie extra a vetar, no una decisión gratuita.

## Decisión
Adoptar `fl_chart` (pub.dev) para las gráficas del Panel directivo —
primera dependencia de UI de terceros del proyecto más allá de
`google_fonts`. Motivos:

- Sin llamadas de red ni ejecución de código dinámico — es una librería
  de renderizado puro sobre `CustomPainter`.
- Ampliamente usada y mantenida activamente en el ecosistema Flutter.
- Cubre el caso de uso (`BarChart` con `rodStackItems` para barras
  apiladas) sin necesitar código propio de layout/eje/interpolación.
- Se desactivó su animación (`duration: Duration.zero`) en el Panel
  directivo para mantener determinismo en tests de widget.

No cambia la postura de ADR-0007 sobre librerías de **componentes**
generales — sigue sin adoptarse ninguna para botones/inputs/layout.

## Consecuencias
- Una dependencia externa nueva en `admin/pubspec.yaml`
  (`fl_chart: ^1.2.0`) — a vigilar en actualizaciones de seguridad como
  cualquier otra dependencia de terceros.
- Si `cardholder/` necesita gráficas en el futuro, debería reusar la
  misma librería por consistencia, salvo que aparezca una razón concreta
  para no hacerlo.
- El Koons color system (`lib/app/theme.dart`) sigue siendo la única
  fuente de colores — `fl_chart` solo se usa como motor de renderizado,
  los colores de cada serie se pasan explícitamente desde `KoonsColors`.

## Alternativas consideradas
- **Gráfica hecha a mano** (`Container`s de altura proporcional o
  `CustomPainter` propio): cero dependencias nuevas, pero
  significativamente más esfuerzo para lograr el mismo resultado (ejes,
  etiquetas, barras apiladas), sin ganancia de seguridad relevante dado
  que `fl_chart` no introduce red ni ejecución dinámica.
