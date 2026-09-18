# Notas de compliance — KBM

> Referencia viva. Última revisión: 2026-09-15.
> **Esto no es una determinación legal/de compliance formal** — son notas
> de diseño para orientar la conversación con un QSA/auditor antes de la
> revisión formal. No sustituyen una evaluación PCI-DSS real.

## Reducción de alcance PCI-DSS por diseño

KBM nunca **almacena** el PAN completo — solo `masked_pan` y un hash
irreversible (HMAC) del PAN, usado exclusivamente para resolver el
destino de una transferencia C2C de Tarjetahabiente (ver
`data-classification.md` y
`docs/adr/0009-pan-hash-transit-for-c2c-transfers.md`). El manejo del PAN
real en operaciones de pago sigue siendo responsabilidad del procesador
de tarjetas externo.

**Actualización 2026-09-17**: a diferencia de la postura original ("KBM
nunca toca el PAN en absoluto"), el PAN completo ahora sí **transita**
(nunca se persiste ni se loguea) por el backend durante la resolución de
una transferencia C2C, y a futuro hacia el procesador externo. Esto sigue
siendo un alcance significativamente menor que almacenar el PAN, pero
cambia la conversación con el QSA respecto a la postura anterior — no es
ya "nunca lo ve", es "lo ve en memoria, nunca lo guarda". Debe
confirmarse con un QSA antes de procesar tarjetas reales cuál SAQ aplica
exactamente bajo este flujo.

## Protección de datos personales (LFPDPPP — México)

Desde que el expediente del Tarjetahabiente incluye CURP, RFC, domicilio y
estatus de Persona Políticamente Expuesta (ver
`docs/business/kyc-tarjetahabiente.md`), KBM maneja datos personales
sensibles bajo la Ley Federal de Protección de Datos Personales en
Posesión de los Particulares (LFPDPPP), no solo datos de tarjeta bajo
PCI-DSS. Esto implica, pendiente de validar con asesoría legal:
- Un aviso de privacidad hacia el Tarjetahabiente (fuera de alcance de
  esta iteración — KBM hoy no tiene el flujo de consentimiento del
  Tarjetahabiente, solo lo captura el staff administrativo).
- Principio de minimización de datos: no se recolectan campos "por si
  acaso" — cada campo del expediente KYC tiene una razón de negocio
  documentada.
- Igual que con PCI-DSS, esta nota es de diseño, no una determinación
  legal — confirmar con asesoría legal antes de operar con datos reales.

## Retención de datos

Pendiente de definir con el negocio: cuánto tiempo se retienen
`audit_log`, `ledger_entries` y datos de Tarjetahabientes inactivos.
Mientras no haya una política explícita, no se debe implementar borrado
automático de estos datos.

## Trazabilidad ante incidentes

`audit_log` + el patrón Outbox (ver `threat-model.md`, punto 4) son la
base de evidencia esperada ante un incidente o revisión — cualquier
feature nueva que mute `balance_operations` o `cards` debe emitir su
evento correspondiente, no es opcional.
