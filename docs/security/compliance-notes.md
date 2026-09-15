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
