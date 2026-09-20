# ADR-0009: PAN completo en tránsito (nunca persistido) para resolver transferencias C2C de Tarjetahabiente

- Estado: Aceptada
- Fecha: 2026-09-17

## Contexto
`docs/feature/transferencia-c2c-tarjetahabiente/README.md` necesita que
un Tarjetahabiente pueda transferir dinero a la tarjeta de otro
Tarjetahabiente escribiendo su número de tarjeta completo (no un
directorio navegable, no un identificador propio de KBM — el usuario ya
conoce el número porque el destinatario se lo dio, igual que un banco
real recibe "transferencia a tarjeta" por el número completo).

Esto entra en tensión directa con una decisión ya documentada:
`docs/security/data-classification.md` establece que *"KBM solo almacena
`masked_pan`... el PAN real y el CVV viven en el procesador de tarjetas
externo, nunca en la base de datos de KBM"*, y
`docs/security/compliance-notes.md` apoya la reducción de alcance
PCI-DSS precisamente en que KBM nunca toca el PAN completo. Por la regla
MUST del `README.md` raíz ("un conflicto con lo ya definido se pregunta,
nunca se resuelve solo"), esto se discutió explícitamente con el negocio
antes de decidir — ver la conversación 2026-09-17.

## Decisión
El PAN completo **puede transitar** por el backend de KBM para resolver
el destino de una transferencia C2C, bajo estas reglas estrictas:

1. **Nunca se persiste.** Ni en `payment_cards`, ni en ninguna otra tabla,
   ni en logs/trazas de aplicación o de error. Vive únicamente en memoria
   durante la duración de esa petición HTTP.
2. **El enmascarado mientras el usuario escribe es solo visual (cliente)**
   — no criptográfico. La protección real en tránsito es TLS, igual que
   cualquier campo sensible hoy (ej. contraseñas). No se implementa
   cifrado adicional en el cliente: para una app **web**, cualquier llave
   usada para "cifrar antes de enviar" sería visible en el bundle
   JS/Wasm — daría una falsa sensación de seguridad sin beneficio real.
3. **La resolución interna (¿a qué tarjeta pertenece este número?) usa un
   hash con llave (HMAC), no cifrado reversible.** Cada tarjeta tiene un
   hash precalculado de su propio PAN real, guardado en un almacén
   separado y de acceso restringido (no mezclado con las lecturas
   normales de `payment_cards`). El backend calcula el HMAC del PAN
   recibido con la misma llave y compara hash-contra-hash — nunca
   necesita "descifrar" nada, y ni KBM mismo podría recuperar el PAN a
   partir del hash guardado.
4. **Hacia el procesador de tarjetas externo** (pendiente de integración
   real en esta iteración): el PAN recibido en la misma petición —no el
   hash— es el que se reenviaría, en memoria, y se descarta después. El
   hash es exclusivamente para que KBM identifique la cuenta destino
   internamente; el procesador necesita el PAN real para su propia
   operación.
5. **Alcance de la búsqueda: mismo Cliente que la tarjeta origen** — no
   toda la plataforma. Decisión de negocio explícita (no técnica): evita
   que el dinero de la nómina/tarjetas de una empresa salga hacia
   terceros fuera de su propia estructura, relevante para PLD/AML.

## Consecuencias
- `docs/security/data-classification.md` se actualiza para reflejar esta
  excepción puntual y controlada — la regla general ("KBM no almacena el
  PAN") se mantiene, esto no la reemplaza.
- `docs/security/compliance-notes.md` necesita reconfirmar con un QSA la
  clasificación de alcance PCI-DSS una vez que el procesador real esté
  integrado — el manejo transitorio (sin almacenamiento) sigue siendo
  significativamente menor alcance que almacenar el PAN, pero ya no es
  "nunca lo toca en absoluto".
- Nuevo riesgo de enumeración: alguien podría intentar muchos números de
  tarjeta para "descubrir" cuáles existen y de quién son — ver
  `docs/security/threat-model.md` puntos 11 y 12 para mitigación (mensaje
  de error genérico + límite de intentos).
- Cualquier middleware de logging/observabilidad del backend debe excluir
  explícitamente el campo de PAN de cualquier log, traza o reporte de
  error — no es opcional, es la garantía central de esta ADR.
- **Implementado** (2026-09-19, `docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md`):
  el cálculo del HMAC y el almacén de hashes viven en el backend Go
  compartido (`internal/adapters/memory/`, `crypto/hmac` +
  `crypto/sha256`), no en ninguna app Flutter — corrige la primera
  versión interina de
  `docs/feature/transferencia-c2c-tarjetahabiente/README.md`, que a
  falta de backend calculaba el HMAC dentro del repositorio fake de
  `cardholder/`.
- **Actualizado** (2026-09-20,
  `docs/adr/0011-processor-integration-architecture-and-postgres-default.md`):
  el adaptador Postgres real (`internal/adapters/postgres/`, ver
  `backend/docs/tdr/0004-postgres-repository-adapter.md`) ya persiste el
  hash en `cards.pan_hash` — este es ahora el almacén persistente final
  para el alcance vigente (Cards/Ledger/login/transferencias C2C); el
  adaptador en memoria sigue existiendo solo como modo demo explícito.

## Alternativas consideradas
- **Cifrado reversible en vez de hash**: descartado — no hay ningún caso
  de uso que necesite recuperar el PAN a partir de lo guardado (la
  comparación siempre es hash-contra-hash), así que un hash irreversible
  es estrictamente más seguro sin costo funcional.
- **Últimos 4 dígitos + confirmación**, mismo patrón que usa Operador en
  `docs/feature/operacion-saldo-con-aprobacion/README.md`: descartado
  para este caso — ahí funciona porque el alcance ya está acotado a un
  Cliente conocido por el staff; para un Tarjetahabiente operando desde
  fuera de la consola administrativa, últimos 4 dígitos por sí solos
  tendrían más probabilidad de colisión y no es el patrón que describe
  el negocio (que sí conoce el caso real de un banco: número completo).
- **Identificador propio de KBM (tipo CLABE) en vez del PAN**: se
  descartó por decisión de negocio explícita — el flujo debe sentirse
  como una transferencia a tarjeta real, no a un número interno nuevo que
  el Tarjetahabiente tendría que aprender y compartir.
