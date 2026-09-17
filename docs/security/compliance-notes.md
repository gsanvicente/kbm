# Notas de compliance — KBM

> Referencia viva. Última revisión: 2026-09-15.
> **Esto no es una determinación legal/de compliance formal** — son notas
> de diseño para orientar la conversación con un QSA/auditor antes de la
> revisión formal. No sustituyen una evaluación PCI-DSS real.

## Reducción de alcance PCI-DSS por diseño

KBM nunca almacena el PAN completo — solo `masked_pan` (ver
`data-classification.md`). El manejo del PAN real es responsabilidad del
procesador de tarjetas externo. Esta decisión de diseño busca mantener a
KBM fuera del alcance completo de PCI-DSS (perfil más cercano a un
comercio que no almacena datos de tarjeta, tipo SAQ A/A-EP), pero la
clasificación final depende de cómo se integre con el procesador — debe
confirmarse con un QSA antes de procesar tarjetas reales.

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
