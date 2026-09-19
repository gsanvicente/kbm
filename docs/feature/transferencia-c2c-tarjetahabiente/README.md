# Transferencia C2C del Tarjetahabiente

- Estado: **Implementado** (2026-09-19) en la app `cardholder/` con
  repositorio fake, junto con el mínimo de
  `docs/feature/portal-autoservicio-tarjetahabiente/README.md` necesario
  para llegar aquí (login y detalle de tarjeta) — el resto de ese portal
  (reclamos, estado de cuenta con filtro de fechas) sigue pendiente;
  congelar/descongelar ya se implementó, ver
  `docs/business/autoservicio-tarjetahabiente.md`. Migración a backend
  compartido ya implementada, ver
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` — la
  "Limitación conocida" de abajo ya no aplica.
- ADR/TDR relacionados: `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`,
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 9 (para
  contraste — este NO es el mismo caso), 11, 12 y 15
- Roles/actores involucrados: Tarjetahabiente únicamente

## Objetivo
Que un Tarjetahabiente transfiera saldo directamente a la tarjeta de otro
Tarjetahabiente del mismo Cliente, capturando el número de tarjeta
completo del destinatario — como una transferencia bancaria real "a
tarjeta", no un directorio de contactos.

## Nota de alcance de esta iteración
- `cardholder/` pasó de scaffold vacío a una app Flutter real
  (`flutter create --platforms=web`) — el `README.md` original de esa
  app describía consumir un backend real vía OpenAPI-generator; se
  corrigió, ver ese archivo.
- Alcance mínimo de portal necesario para esto: login y detalle de una
  tarjeta (saldo + botón Transferir) — ver
  `docs/feature/portal-autoservicio-tarjetahabiente/README.md` para lo
  que sigue pendiente (reclamos, estado de cuenta con filtro de fechas).
- Puerto de desarrollo: `8766` (junto al `8765` de `admin/`), para poder
  correr ambas apps a la vez.

## Limitación conocida — resuelta por ADR-0010
Por ADR-0002, `cardholder/` no comparte código ni estado en tiempo de
ejecución con `admin/` — son dos procesos Flutter independientes. La
primera versión de esta feature usó un repositorio fake propio de
`cardholder/` (`FakeCardholderBackend`, con su propio universo de datos
sembrados) — una transferencia hecha ahí **no** se reflejaba en `admin/`
corriendo al mismo tiempo, y viceversa.

`docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md` resuelve
esto: ambas apps hablan por HTTP contra el mismo proceso Go
(`../backend`, `127.0.0.1:8080`), así que una transferencia hecha desde
`cardholder/` sí se refleja de inmediato en el saldo/movimientos que
`admin/` muestra de esas mismas tarjetas. `FakeCardholderBackend` sigue
existiendo solo para los widget tests de `cardholder/` (ver su README) —
ya no es el camino que usa la app real.

## Por qué es una entidad de negocio distinta de "Operación de saldo"
No es una variación de `docs/feature/operacion-saldo-con-aprobacion/`:
- La solicita un `CARDHOLDER_USER`, nunca un `USUARIO` de staff.
- **Nunca** pasa por `approval_rules` — el Tarjetahabiente opera su
  propio saldo, sin fricción de aprobación de nadie.
- **Nunca** toca la Cuenta Concentradora del Cliente — es
  tarjeta-a-tarjeta, directo.
- El destino se identifica por el **número de tarjeta completo**, no por
  últimos 4 dígitos como en el flujo de Operador (ver la siguiente
  sección para el porqué de esta diferencia).

Sí comparte la mecánica de ledger de una Transferencia normal (débito en
origen + crédito en destino, mismo `LedgerRepository.postEntry`,
`OperationType.transfer` técnicamente hablando a nivel de asiento
contable) — la diferencia es quién la pide, cómo se resuelve el destino,
y que nunca requiere aprobación.

## Por qué número completo y no últimos 4 dígitos
`docs/feature/operacion-saldo-con-aprobacion/README.md` (para el flujo de
Operador) usa últimos 4 dígitos + confirmación porque ahí el riesgo es
**sobre-exposición dentro del mismo tenant** (threat-model punto 9): un
Operador con acceso legítimo al Cliente no debería poder navegar un
directorio de tarjetas ajenas para completar un formulario.

Aquí el caso es distinto: el propio Tarjetahabiente ya conoce el número
completo porque el destinatario se lo dio directamente (igual que
compartes tu número de cuenta o tarjeta para que alguien te transfiera en
un banco real) — no está navegando ningún directorio, está identificando
una cuenta específica que ya conoce. El riesgo aquí no es
sobre-exposición por diseño de UI, es **enumeración** (¿y si prueba
números al azar?) — ver "Seguridad" más abajo, es un riesgo distinto con
una mitigación distinta (límite de intentos, no "resolver por un dato que
ya debería tener").

## Manejo del PAN (resumen — el detalle completo está en la ADR)
Ver `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` para la decisión
completa. Resumen del flujo:

1. **Cliente (Flutter web)**: el campo de captura enmascara visualmente
   mientras el usuario escribe (deja ver solo los últimos 4 dígitos, como
   cualquier input de tarjeta) — esto es **solo UX**, el valor real
   completo es lo que se envía. No hay cifrado adicional en el cliente
   (en una app web, cualquier llave puesta ahí sería visible en el bundle
   — falsa sensación de seguridad).
2. **Transporte**: el PAN completo viaja al backend protegido únicamente
   por TLS, igual que cualquier campo sensible hoy (ej. contraseñas).
3. **Backend**: calcula un **hash con llave (HMAC)** del PAN recibido y
   lo compara contra el almacén de hashes precalculados (uno por tarjeta,
   calculado desde que la tarjeta se dio de alta) — así identifica a qué
   tarjeta/Tarjetahabiente corresponde. El PAN recibido **nunca se
   persiste ni se loguea** — vive solo en memoria durante esa petición.
4. **Hacia el procesador externo** (pendiente de integración real en
   esta iteración): el PAN en claro de esa misma petición —no el hash—
   es el que se reenviaría, y se descarta después de usarlo.

## Flujo principal
1. El Tarjetahabiente, desde el detalle de su tarjeta, pulsa
   "Transferir" y captura: monto y número de tarjeta destino (enmascarado
   mientras escribe).
2. El backend resuelve el destino (ver arriba). Dos resultados posibles:
   - **No se encuentra una tarjeta válida** dentro del mismo Cliente que
     la tarjeta origen → un solo mensaje de error genérico (no distingue
     "formato inválido" de "no pertenece a nuestro universo" — ver
     "Seguridad").
   - **Se encuentra exactamente una** → se muestra una confirmación
     (nombre del Tarjetahabiente destino + número enmascarado) antes de
     poder enviar, igual que un banco real confirma el beneficiario antes
     de una transferencia.
3. Al confirmar: se debita el ledger de la tarjeta origen y se acredita
   el de la tarjeta destino — **sin pasar por `approval_rules`**, sin
   tocar ninguna Cuenta Concentradora. Se ejecuta de inmediato.
4. Si el saldo de la tarjeta origen es insuficiente, la operación falla
   sin tocar ningún ledger — mismo principio de "nunca a medias" que ya
   aplica a la Transferencia de Operador.

## Alcance: mismo Cliente, no toda la plataforma
Decisión de negocio explícita (no técnica): la búsqueda del destino se
restringe al mismo Cliente que la tarjeta origen del Tarjetahabiente que
transfiere — evita que el dinero de la nómina/tarjetas de una empresa
salga hacia terceros fuera de su propia estructura corporativa (relevante
para PLD/AML). Transferencias entre Tarjetahabientes de Clientes
distintos: fuera de alcance. Adicionalmente, el destino debe pertenecer a
**otro** Tarjetahabiente — transferir a otra tarjeta propia (si el mismo
Tarjetahabiente tiene más de una) no está soportado, y da el mismo error
genérico que cualquier otro destino inválido (ver "Seguridad").

## Seguridad
- **Mensaje de error genérico**: nunca se distingue "número con formato
  inválido" de "número válido pero no pertenece a nuestro universo" de
  "es tu propia tarjeta" — ver threat-model punto 12.
- **Límite de intentos fallidos: 5 por sesión.** Al quinto intento
  fallido consecutivo, el formulario de transferencia queda bloqueado
  hasta el siguiente inicio de sesión — sin esto, el mensaje genérico por
  sí solo no evita que alguien pruebe muchos números buscando una
  coincidencia. Se reinicia únicamente al volver a iniciar sesión, nunca
  dentro de la misma sesión (ni siquiera cerrando y reabriendo el
  formulario).
- **El PAN nunca se loguea** — cualquier middleware de
  logging/observabilidad del backend debe excluirlo explícitamente. Ver
  threat-model punto 11.
- El hash de PAN vive en un almacén separado y de acceso restringido, no
  mezclado con las lecturas normales de tarjetas — ver la ADR. Se calcula
  del lado del servidor (`internal/adapters/memory/` del backend
  compartido, ver
  `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`), no
  en ninguna app Flutter — la única diferencia con producción es dónde
  vive la llave del HMAC (aquí, una constante marcada como
  solo-desarrollo; en producción, un almacén de secretos real). La
  primera versión de esta feature (antes de esa ADR) lo calculaba dentro
  del repositorio fake de `cardholder/`, a falta de backend — ya
  corregido.

## Reglas de negocio
Ver `docs/business/autoservicio-tarjetahabiente.md` y la ADR — no se
repiten aquí.

## Casos borde / fuera de alcance
- Transferencias hacia Clientes distintos: fuera de alcance (ver
  "Alcance" arriba).
- Transferencias hacia fuera del ecosistema KBM (cuenta bancaria
  externa): fuera de alcance, requeriría integración bancaria real.
- Deshacer/cancelar una transferencia ya ejecutada: fuera de alcance —
  se ejecuta de inmediato, sin estado intermedio (no hay
  `pending_approval` en este flujo).
- Límite de monto por transferencia o por día: no definido todavía —
  puede ser una extensión futura si el negocio lo pide, no bloquea esta
  versión.
- Transferir entre dos tarjetas propias del mismo Tarjetahabiente: fuera
  de alcance (ver "Alcance" arriba) — no solicitado, y el negocio
  describió el caso real como "pagarle a alguien más", no reacomodar tu
  propio dinero.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
