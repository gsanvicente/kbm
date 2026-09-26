# ADR-0027: Validar saldo antes de enviar un pago SPEI, y corregir el estatus/refresco tras enviarlo

- Estado: Aceptada
- Fecha: 2026-09-25

## Contexto
Dos bugs reales reportados en vivo sobre "Enviar dinero" (`SendSpeiDialog`,
`cardholder/`):

1. Un Tarjetahabiente con **$736.00** de saldo pidió un pago SPEI de
   **$10,000.00** y el sistema lo dejó enviar sin ningún aviso. Se
   confirmó contra el backend real (`curl`): el pago se crea igual como
   `pending_approval`, con `HTTP 200`, sin ninguna validación de saldo.
   Causa raíz: `CreatePayment` (`backend/internal/adapters/postgres/repository/spei.go`)
   solo valida saldo **al ejecutar** (`trySPEIExecute`, cuando el monto
   está por debajo del umbral de aprobación del Cliente) — un pago que
   *sí* requiere aprobación nunca pasa por ahí al crearse, así que
   queda "pendiente" indefinidamente sin que nadie le diga al
   Tarjetahabiente, desde el momento en que lo pidió, que ya sabíamos
   que no alcanzaba.
2. Después de pulsar "Enviar", el Tarjetahabiente no veía ningún mensaje
   de estatus ("Aplicado" / "Pendiente de aprobación" / etc.) ni la
   lista de movimientos/pagos se actualizaba — no había forma de saber
   si el pago se procesó o no. El código sí generaba un mensaje
   distinto por estatus (`speiResultMessage`) y sí llamaba a un
   refresco (`_reload()`) tras cerrar el diálogo, pero ninguno de los
   dos se sentía como si hubiera pasado — mismo síntoma, en otra
   pantalla, que ya se había visto (y corregido puntualmente) en
   ADR-0025 para "Agregar beneficiario": la pantalla no reflejaba lo que
   el propio usuario acababa de guardar.

## Decisión

### 1. Bloquear el envío client-side si el monto excede el saldo
`SendSpeiDialog` recibe ahora el saldo disponible (`balance`, `currency`
— ya se cargaba en pantalla, en `_BalanceCard`) y lo valida en el mismo
punto donde ya se validaba "monto > 0" y "elegiste un beneficiario": al
pulsar "Continuar", antes de llegar siquiera al paso de confirmación. Un
monto por encima del saldo nunca llega al servidor — mensaje explícito:
"Saldo insuficiente — tu saldo disponible es $X MXN."

**No se relajó ni se dejó pasar "por si acaso llega un depósito antes de
que lo aprueben"**: la Cuenta Individual no tiene línea de crédito ni
sobregiro (`docs/business/saldo-y-ledger.md`), así que pedir un pago por
encima del saldo *actual* nunca es una operación legítima, apruebe quien
apruebe después. Mismo criterio de "bloquear, no solo advertir" que ya
usa `TransferDialog` (C2C) para fondos insuficientes.

**El backend no cambió** — `trySPEIExecute` sigue siendo la única fuente
de verdad real (el saldo puede cambiar entre que se abre el diálogo y se
confirma), esto es una validación de UX que evita el caso obvio, no un
reemplazo del candado real del servidor.

### 2. Estatus y refresco confiables tras enviar
Mismo arreglo que ADR-0025 aplicó a "Agregar beneficiario": el pago que
devuelve el propio `POST` (con su estatus real: `executed` /
`pending_approval` / `failed` / `rejected`) se inserta de inmediato en
la lista de pagos ya cargada en pantalla, sin depender de que un
refetch lo vea a tiempo — el mensaje de estatus (`speiResultMessage`,
ya existente, sin cambios) se muestra en ese mismo instante. El saldo y
el resto del ledger sí necesitan datos frescos del servidor (un pago
`executed` debita de verdad), así que ahí sí se mantiene un `_reload()`
después, pero ya no es lo único que decide si el usuario ve o no
confirmación de que su pago se procesó.

Adicionalmente, y a diferencia de ADR-0025 (donde no se pudo aislar la
causa exacta de la falta de refresco), esta vez se agrega una corrección
de raíz: **`Cache-Control: no-store` en toda respuesta de la API**
(`middleware.NoStore`, `backend/internal/adapters/http/middleware/nostore.go`).
Ninguna respuesta de esta API debería poder quedar cacheada por el
navegador — son datos financieros con sesión — y es la explicación más
plausible para por qué un GET inmediatamente después de un POST a veces
no reflejaba el cambio. Se aplica a ambos bugs (este y el de ADR-0025)
sin necesitar identificar cuál pantalla es la próxima en toparse con el
mismo síntoma.

## Consecuencias
- `SendSpeiDialog` gana dos parámetros (`balance`, `currency`) — sin
  cambios de API/backend.
- `NoStore` es middleware global (se monta en `cmd/api/main.go`, junto a
  `CORS`) — aplica a **toda** la API, no solo a SPEI. Es una mejora de
  seguridad de todos modos (una API con sesión nunca debería ser
  cacheable por un intermediario), no solo un parche de UX.
- No se auditaron ni corrigieron preventivamente otras pantallas con el
  mismo patrón de `_reload()` (p. ej. transferencias C2C en `admin/`) —
  se confía en que `NoStore` resuelve la causa de raíz para todas; si
  aparece un tercer caso puntual, amerita revisar si `NoStore` de verdad
  bastó o si hace falta el mismo parche de "insertar localmente el
  resultado del propio POST" ahí también.
- Prueba nueva: `cardholder/test/send_spei_dialog_test.dart`, que fija
  el bug exacto reportado ($736 de saldo, intento de $10,000) como
  regresión.

## Alternativas consideradas
- **Dejar pasar el pago si está `pending_approval`, avisar solo si se
  ejecuta de inmediato y falla**: descartado — el negocio fue explícito:
  "ni siquiera debería haber dejado enviar". Un pago que hoy no se puede
  cubrir no debería registrarse como una solicitud pendiente real.
- **Validar el saldo en el backend antes de crear el registro
  `pending_approval`** (en vez de solo client-side): evaluado y
  descartado por ahora — cambiaría el comportamiento para pagos que sí
  requieren aprobación (hoy se registran igual, y podrían tener fondos
  para cuando se aprueben); el negocio no pidió ese cambio de fondo, solo
  que el propio Tarjetahabiente no pueda *intentar* pedir algo que hoy
  claramente no puede cubrir. Se reconsidera si el negocio pide impedir
  también la solicitud pendiente cuando no hay fondos hoy.
- **Auditar y corregir todas las pantallas con el patrón `_reload()`
  ahora mismo**: descartado por alcance — `NoStore` ataca la causa más
  probable de raíz para todas a la vez; parchear pantalla por pantalla
  sin evidencia de que cada una tiene el mismo síntoma sería trabajo
  especulativo.

## Ver también
- `docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md`
  — el mismo síntoma de refresco, ya corregido puntualmente ahí; este
  ADR agrega la corrección de raíz (`NoStore`).
- `docs/adr/0021-conector-spei.md` — el umbral de aprobación y el flujo
  de ejecución de un pago SPEI.
- `docs/business/saldo-y-ledger.md` — por qué la Cuenta Individual nunca
  admite saldo negativo.
