# Datos KYB del Cliente (expediente de persona moral)

> Referencia viva. Última revisión: 2026-09-17.

## Por qué existen estos campos
Un Cliente en KBM no es solo "una empresa con nombre" — es una persona
moral con la que se firma un contrato de servicio y a través de la cual
se mueve dinero real. Para operar como plataforma de gestión de saldos en
México, el expediente necesita soportar identificación legal de la
empresa y prevención de lavado de dinero (PLD/AML) a nivel corporativo,
mismo criterio que ya aplicamos al KYC del Tarjetahabiente (ver
`docs/business/kyc-tarjetahabiente.md`) — no se recolecta un campo "por si
acaso", cada uno tiene una razón de negocio documentada (minimización de
datos, ver `docs/security/compliance-notes.md`).

## Cada Cliente en la jerarquía lleva su propio expediente completo
Decisión de negocio explícita (no técnica): una filial es una **entidad
legal independiente** de su empresa matriz (típicamente su propia S.A. de
C.V., con acta constitutiva y RFC propios), aunque pertenezca al mismo
grupo corporativo. Por eso **no hay herencia** de datos KYB entre un
Cliente padre y sus hijas — cada una, sin importar su posición en la
jerarquía (`docs/adr/0003-multitenancy-rls-hierarchy.md`), captura su
propio expediente completo desde cero.

## Campos del expediente

### Datos generales de la empresa
- `razonSocial` — nombre legal completo de la persona moral.
- `nombreComercial` — opcional, solo si difiere de la razón social.
- `rfc` — RFC persona moral (12 caracteres — distinto formato al de
  persona física, que es de 13).
- `fechaConstitucion` — fecha de constitución de la empresa.
- `objetoSocial` — giro/actividad económica — relevante para
  clasificación de riesgo PLD, no es un campo decorativo.
- `actaConstitutiva` — datos del instrumento: número de escritura,
  notario público (nombre, número de notaría, plaza/ciudad), fecha, folio
  de Registro Público de Comercio. **Solo datos estructurados en esta
  iteración — no hay carga del PDF del acta** (ver "Fuera de alcance").

### Domicilio fiscal
Mismo shape que ya existe para Tarjetahabiente (`docs/business/kyc-tarjetahabiente.md`):
calle y número, colonia, ciudad, estado, código postal, país.

### Apoderado(s) legal(es)
Quien(es) pueden actuar/firmar en nombre de la empresa frente a KBM. Un
**apoderado principal, requerido**, más apoderados adicionales,
opcionales — a diferencia del beneficiario controlador (ver abajo), aquí
no hay un concepto de "porcentaje": la distinción principal/adicional es
simplemente quién es el representante primario a efectos de contrato.

Cada apoderado (principal o adicional) captura:
- Datos de persona física — reutiliza el mismo shape que ya existe en
  `Cardholder` para identificación: nombre completo, tipo/número de
  identificación oficial, CURP, RFC (persona física).
- `tipoDePoder` — uno de: poder general para actos de administración,
  poder general para pleitos y cobranzas, poder general para actos de
  dominio, poder especial (con descripción libre de las facultades).
- Datos del instrumento notarial que otorga el poder: número de
  escritura, notario, fecha.
- `vigencia` — opcional, solo si el poder tiene fecha de expiración.

### Beneficiario controlador (PLD/LFPIORPI)
Persona(s) física(s) que en última instancia poseen o controlan la
empresa — dato de cumplimiento AML/PLD a nivel corporativo, mismo espíritu
que el flag `isPoliticallyExposed` que ya existe para Tarjetahabiente,
pero aquí es sobre la estructura accionaria de la empresa misma, no sobre
el perfil de una persona que opera una tarjeta.

Un **beneficiario controlador mayoritario, requerido** (>25% de
participación, o quien ejerza control effectivo si la propiedad está
más repartida — ver "Fuera de alcance" sobre estructuras de control
indirecto), más beneficiarios minoritarios, opcionales.

Cada beneficiario controlador (mayoritario o minoritario) captura:
- Datos de persona física — mismo shape reutilizado que Apoderado.
- `porcentajeParticipacion` — % de participación accionaria.
- `isPoliticallyExposed` — mismo flag PEP que ya existe para
  Tarjetahabiente, aplicado aquí a nivel del beneficiario controlador.

## Diseño: reutilizar un shape común de "persona física"
Tanto Apoderado como Beneficiario Controlador necesitan esencialmente los
mismos datos de identificación que ya existen en `Cardholder` (nombre,
identificación oficial, CURP, RFC). Al implementar, esto debería
modelarse como un tipo compartido (ej. `PersonaFisica` o similar) en vez
de duplicar la definición de campos tres veces (Cardholder, Apoderado,
Beneficiario Controlador) — decisión de diseño a respetar cuando se
construya el modelo real, no solo una sugerencia de estilo.

## Fuera de alcance de esta iteración
- **Carga de documentos** (PDF del acta constitutiva, poder notarial,
  comprobante de domicilio, identificación oficial del apoderado): fuera
  de alcance — solo datos estructurados, mismo criterio que
  `kyc-tarjetahabiente.md`. Requeriría infraestructura de almacenamiento
  de archivos que no existe todavía en el proyecto.
- **Validación real de RFC/CURP** (dígito verificador, estructura exacta):
  igual que en KYC de Tarjetahabiente, texto libre con longitud sugerida,
  sin validar el algoritmo de checksum real.
- **Estructuras de control indirecto complejas** (beneficiario
  controlador vía cadena de otras personas morales, fideicomisos, etc.):
  fuera de alcance — se asume participación accionaria directa y
  reportable en porcentaje simple.
- **Verificación de vigencia del poder notarial contra un registro
  externo**: se captura el dato, no se valida contra ninguna fuente
  externa.
- **Herencia de datos KYB entre Cliente padre e hijas**: explícitamente
  descartada, ver arriba — no es un "fuera de alcance por ahora", es una
  decisión de negocio permanente dado que cada filial es su propia
  entidad legal.

## Ver también
- `docs/business/kyc-tarjetahabiente.md` — el expediente equivalente para
  persona física (Tarjetahabiente), mismo criterio de rigor.
- `docs/security/data-classification.md` — clasificación de estos campos
  como PII/datos sensibles regulados.
- `docs/security/compliance-notes.md` — LFPDPPP y minimización de datos.
- `docs/feature/alta-y-gestion-de-clientes/README.md` — dónde se capturan
  y editan estos campos.
