# ADR-0007: Sistema de diseño Material 3 personalizado con tokens de marca Koons

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
La primera versión visual de `admin/` (NavigationRail y colorSchemeSeed
por defecto de Material 3) se sintió genérica — no a la altura de
plataformas de referencia (Stripe/Linear/Vercel) y sin ninguna relación
con la marca Koons. Esta decisión aplica potencialmente tanto a `admin/`
como al futuro `cardholder/` (misma familia de apps Flutter, ver
ADR-0002), por lo que es una decisión de sistema, no solo de un
componente.

## Decisión
- **No** adoptar una librería de componentes de terceros (se evaluó
  `shadcn_ui` para Flutter). Se construye un sistema de diseño propio
  sobre Material 3: theme centralizado (`lib/app/theme.dart`), sin
  dependencias nuevas de UI más allá de `google_fonts` para tipografía
  (ver `admin/docs/tdr/0001-google-fonts-typography.md`).
- **Tokens de color** extraídos directamente de `assets/images/kbm_logo.png`
  (muestreo de píxeles agrupado por tono, no valores inventados):
  - Navy: `#062E56`
  - Azul: `#227EA7`
  - Verde: `#43AB63`
- **Importante:** estos son los colores del logo de **KBM** (el producto),
  no necesariamente la identidad corporativa oficial de **Koons** — no
  existe todavía un manual de marca de Koons disponible. Si aparece uno,
  esta ADR debe reemplazarse (no editarse) por una nueva que referencie
  los valores oficiales.
- Patrón visual: sidebar oscuro (navy) con navegación horizontal
  ícono+texto, barra superior blanca con borde inferior sutil, contenido
  en tarjetas con borde de 1px (sin sombra dura), tipografía Inter.

## Consecuencias
- Un solo lugar (`lib/app/theme.dart` en cada app Flutter) concentra los
  tokens — cambiar de paleta el día que llegue la marca oficial de Koons
  es editar un archivo, no cada pantalla.
- `cardholder/` debería adoptar el mismo `theme.dart` (o una copia
  sincronizada) cuando se construya su UI, para consistencia de marca
  entre ambas apps.
- Queda pendiente vendorizar Inter como asset local antes de producción
  (ver TDR referenciada arriba) — riesgo de red en runtime documentado en
  `docs/security/threat-model.md`.

## Alternativas consideradas
- **shadcn_ui para Flutter**: descartada por ahora — agrega una
  dependencia externa y menos control sobre la marca, por una ganancia de
  velocidad que no se justifica todavía con un equipo de 1-3 personas.
