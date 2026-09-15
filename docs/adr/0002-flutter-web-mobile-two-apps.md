# ADR-0002: Flutter para web y mobile, como dos aplicaciones separadas

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
KBM necesita tres superficies de UI: consola administrativa (Super Admin,
Admin Cliente, Operador, Auditor), portal web de tarjetahabiente, y app
móvil de tarjetahabiente. Equipo pequeño, se busca un solo lenguaje de UI
para minimizar piezas móviles.

## Decisión
Flutter/Dart para todo el frontend, como **dos aplicaciones separadas**:
`admin` (web-first, roles administrativos) y `cardholder` (web + mobile,
autoservicio de tarjetahabiente). No comparten código en tiempo de
ejecución.

## Consecuencias
- Un solo stack de UI cubre las tres superficies.
- La lógica y los datos administrativos nunca viajan dentro del bundle
  móvil del tarjetahabiente (superficie de ataque y peso de la app).
- Backend (Go) y frontend (Dart) no comparten tipos de forma nativa — el
  contrato se mantiene vía OpenAPI (ver ADR-0006), no vía tipos
  compartidos como hubiera sido posible con un stack full-TypeScript.

## Alternativas consideradas
- **React/Next.js + React Native**: propuesta inicial, descartada por el
  usuario a favor de un único lenguaje (Dart) cubriendo web y mobile.
- **Una sola app Flutter para admin + cardholder**: descartada por riesgo
  de seguridad/tamaño de bundle (ver Consecuencias).
- **Apps nativas (Swift/Kotlin)**: descartada — costo/tiempo de desarrollo
  no justificado para el tamaño del equipo y el horizonte del MVP.
