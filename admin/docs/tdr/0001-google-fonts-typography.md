# TDR-0001: google_fonts para tipografía (Inter)

- Estado: Aceptada
- Fecha: 2026-09-15
- Alcance: decisión local al admin app

## Contexto
La fuente de sistema por defecto de Flutter hace que la consola se vea
genérica frente a plataformas de referencia (Stripe/Linear/Vercel), que
usan tipografías geométricas tipo Inter.

## Decisión
Usar el paquete `google_fonts` con la familia "Inter" para el `TextTheme`
de la app.

## Consecuencias
- `google_fonts` descarga el archivo de fuente en tiempo de ejecución la
  primera vez (con caché posterior) — **antes de ir a producción/auditoría
  de seguridad, bundlear Inter como asset local** (declarar la fuente en
  `pubspec.yaml` con los archivos .ttf vendorizados) para eliminar esa
  dependencia de red en runtime. Ver `docs/security/threat-model.md`.
- Aceptable para esta iteración de diseño visual, no para el build final.

## Alternativas consideradas
- Bundlear Inter como asset local desde el día uno: descartado por ahora
  para no invertir tiempo en eso mientras el diseño todavía puede cambiar;
  queda como TODO explícito arriba.
