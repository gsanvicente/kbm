# ADR-0020: Cuenta Individual del Tarjetahabiente — el saldo deja de vivir en la tarjeta

- Estado: Aceptada
- Fecha: 2026-09-24

## Contexto
Hoy `TARJETA ||--|| LEDGER_ACCOUNT` es una relación 1:1
(`ledger_accounts.card_id uuid NOT NULL UNIQUE`) — la tarjeta misma es la
dueña de su saldo. Esto sostuvo bien a KBM mientras era solo "tarjeta
corporativa prepagada", pero se vuelve insuficiente por dos motivos que
aparecieron juntos al diseñar la integración con SPEI
(`docs/adr/0021-conector-spei.md`):

1. **SPEI no puede dirigirse a una tarjeta.** SPEI mueve dinero por CLABE
   (18 dígitos), y una CLABE identifica una cuenta bancaria, nunca un PAN
   de tarjeta. Si el saldo vive en la tarjeta, no hay dónde colgar la
   CLABE de forma coherente.
2. **`docs/business/tarjetas-y-asignacion.md` ya había marcado esto como
   deuda pendiente**: *"liberar/reasignar una tarjeta ya asignada...
   fuera de alcance de esta pasada, deliberadamente... revisitar antes de
   considerar el límite de 1 completamente funcional en producción."* Hoy,
   si la única tarjeta de alguien se pierde, es robada o vence, no hay
   forma de reemplazarla sin perder su historial — `CardRepository.assign`
   crea un `ledger_account` nuevo desde cero por cada tarjeta.

Ambos problemas tienen la misma causa raíz: el saldo está amarrado al
objeto equivocado. Una tarjeta es un instrumento de gasto desechable
(vence, se pierde, se reporta robada); la relación económica real y
duradera es entre el Tarjetahabiente y su dinero.

## Decisión
1. **Nueva entidad "Cuenta Individual"** — nombre elegido deliberadamente
   distinto de "Cuenta Concentradora"/"Cuenta Colectora" (que son del
   *Cliente*/empresa, ver `docs/business/tesoreria-cliente.md`); esta es
   la del *Tarjetahabiente* (persona), un concepto distinto que no debe
   confundirse con esos dos.
2. **Cardinalidad real: 1 Cuenta Individual : N Tarjetas a lo largo del
   tiempo**, con el invariante **"como máximo una tarjeta `active` por
   Cuenta en un momento dado"** — nunca cero mientras la Cuenta esté en
   uso normal, nunca dos. El límite de Cuentas por Tarjetahabiente sigue
   siendo configurable por Cliente (mismo mecanismo que hoy
   `client_settings.max_active_cards_per_cardholder`, reinterpretado —
   ver punto 6).
3. **La Cuenta nace al dar de alta al Tarjetahabiente**, no al asignarle
   su primera tarjeta — puede existir (con su CLABE, ver
   `docs/adr/0021-conector-spei.md`) antes de tener ninguna tarjeta
   asignada, igual que una cuenta de banco real existe antes de que
   llegue la tarjeta de débito física. Esto **corrige** la frase actual
   de `tarjetas-y-asignacion.md` ("no tiene sentido llevar saldo de algo
   que nadie tiene todavía") — con Cuenta Individual, sí tiene sentido:
   la Cuenta puede recibir SPEI desde el día del alta.
4. **El saldo se relocaliza**: `ledger_accounts.card_id` se reemplaza por
   `ledger_accounts.account_id` (referencia a la Cuenta Individual).
   `cards.account_id` es la FK nueva que liga cada tarjeta a su Cuenta.
   Dispersión, Deducción, Transferencia C2C y SPEI (entrante y saliente)
   todos afectan el saldo de la **Cuenta**, nunca el de una tarjeta
   directamente.
5. **`cancelled` pasa de ser un estado sin implementar a tener
   comportamiento real** — terminal, nunca reversible (a diferencia de
   `blocked`/`frozen`, que sí lo son). Nuevo campo `cancelled_reason`
   (`expirada` | `robada` | `extraviada`), mismo espíritu que
   `blocked_reason` ya existente.
6. **Nueva operación "Reemplazar tarjeta"**, solo staff
   (Super Admin/Admin Cliente — mismo criterio que asignar, ver
   `docs/business/tarjetas-y-asignacion.md`, "Quién puede asignar"; el
   propio Tarjetahabiente **no** puede iniciarlo en esta iteración,
   revisitar si el negocio lo pide más adelante). Es **atómica**: cancela
   la tarjeta actual + toma una tarjeta `disponible` del mismo Cliente +
   la asigna a la **misma Cuenta** — reutiliza el pool de tarjetas
   disponibles que ya existe, no inventa una fuente nueva de tarjetas.
   El saldo, la CLABE y el historial de la Cuenta **no se tocan**. Mismo
   principio de "nunca a medias" que ya rige cualquier operación de saldo
   en el proyecto: cancelar y reasignar ocurren en la misma transacción,
   para que el invariante "siempre una tarjeta activa" nunca se rompa en
   un estado observable.
7. **El límite configurable por Cliente pasa a contar Cuentas, no
   tarjetas activas sueltas** — dentro de cada Cuenta, "una activa a la
   vez" queda garantizado por construcción (punto 2), no por conteo. Esto
   simplifica la ambigüedad que tenía el mecanismo actual (¿qué pasa si
   la única tarjeta de alguien se reemplaza? — ahora ni siquiera es una
   pregunta, sigue siendo la misma Cuenta).
8. **Una sola Cuenta, sin distinguir origen del dinero** — decisión de
   negocio explícita: el saldo que llegó por Dispersión (la empresa
   fondeó a su empleado) y el que llegue por depósito SPEI directo (ver
   ADR-0021) conviven en el mismo saldo, sin separación contable. Mismo
   criterio que una cuenta de nómina real: el sueldo y el dinero propio
   de la persona no se distinguen una vez depositados.

## Consecuencias
- **Migración de datos**: por cada `ledger_account` existente hoy (una
  por tarjeta activa), se crea su Cuenta Individual correspondiente y se
  reapunta `account_id` — transicionalmente 1:1, diverge recién con el
  primer reemplazo de tarjeta.
- Documentos que este ADR corrige o extiende:
  `docs/business/tarjetas-y-asignacion.md` (ciclo de vida, límite,
  "Reemplazo de tarjeta" nuevo), `docs/business/saldo-y-ledger.md` (el
  saldo ya no es "de la tarjeta"), `docs/business/domain-model.md`
  (diagrama), `docs/business/tesoreria-cliente.md` (sigue igual en sí,
  pero ahora convive con un segundo camino de fondeo, ver ADR-0021).
- **Riesgo regulatorio marcado, no resuelto aquí**: una Cuenta con CLABE
  real puede implicar obligaciones de identificación/PLD más estrictas
  que las de un monedero prepagado cerrado — ver
  `docs/adr/0021-conector-spei.md`, "Seguridad", y
  `docs/security/threat-model.md` punto 17. Validar con quien lleve el
  tema legal/compliance en Koons antes de producción; no es una decisión
  que este ADR resuelva.
- Habilita directamente `docs/adr/0021-conector-spei.md` — sin esta
  entidad, SPEI no tiene dónde vivir.

## Alternativas consideradas
- **Mantener 1:1 Tarjeta:Ledger y resolver el reemplazo con un campo
  "reemplaza_a" apuntando a la tarjeta anterior**: descartado — no
  resuelve el problema de fondo (SPEI sigue sin tener una CLABE
  coherente que colgar), solo parcha el síntoma del reemplazo sin tocar
  la causa.
- **Cuenta 1:1 con Tarjeta, sin historial de reemplazos**: descartado —
  no cumple la regla de negocio "siempre una tarjeta activa" tras un
  reemplazo sin perder saldo ni CLABE, que es justo el problema que
  `tarjetas-y-asignacion.md` ya había dejado pendiente.
- **Separar contablemente fondos de empresa vs. fondos personales dentro
  de la misma Cuenta**: descartado por ahora, decisión de negocio
  explícita (punto 8) — revisitar si el negocio lo pide.

## Ver también
- `docs/adr/0021-conector-spei.md` — la integración que motivó este
  cambio.
- `docs/business/tarjetas-y-asignacion.md`
- `docs/business/saldo-y-ledger.md`
- `docs/business/domain-model.md`
- `docs/security/threat-model.md`
