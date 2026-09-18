# Clasificación de datos — KBM

> Referencia viva. Última revisión: 2026-09-15.

| Dato | Clasificación | Notas |
|---|---|---|
| PAN de tarjeta, CVV | **Fuera de alcance de almacenamiento** | KBM solo **almacena** `masked_pan` (ej. `**** **** **** 1234`) y un **hash con llave (HMAC)** del PAN completo, usado solo para resolver el destino de una transferencia C2C de Tarjetahabiente — nunca el PAN en claro. El PAN completo sí puede **transitar** (nunca persistirse ni loguearse) durante esa resolución y, a futuro, hacia el procesador externo — ver `docs/adr/0009-pan-hash-transit-for-c2c-transfers.md` y `docs/feature/transferencia-c2c-tarjetahabiente/README.md`. El CVV nunca transita ni se almacena en KBM bajo ningún flujo. Ver `compliance-notes.md`. |
| Hash de PAN (HMAC, para resolución de transferencias C2C) | Secreto | Irreversible — ni KBM puede recuperar el PAN a partir de él. Vive en un almacén separado, no mezclado con las lecturas normales de `payment_cards` (defensa en profundidad). La llave del HMAC se gestiona como cualquier otro secreto (ver fila de `password_hash`/secretos más abajo). |
| Red (Visa/Mastercard), vigencia (mes/año), estado, fecha de asignación de la Tarjeta | Operacional | No reconstruye una tarjeta funcional por sí solo (sin PAN completo ni CVV) — control de acceso estándar, no requiere el mismo nivel que CURP/RFC. Ver `docs/business/tarjetas-y-asignacion.md`. |
| `curp`, `rfc`, tipo/número de identificación oficial del Tarjetahabiente | **Sensible (PII regulada — LFPDPPP)** | Datos personales de identificación bajo la ley mexicana de protección de datos. Mismo nivel de protección que credenciales: nunca en logs, nunca en exports sin control de acceso. Ver `docs/business/kyc-tarjetahabiente.md`. |
| Domicilio y fecha de nacimiento del Tarjetahabiente | Sensible (PII) | Requisito de KYC ("comprobante de domicilio"), no dato de contacto genérico — mismo nivel que CURP/RFC. |
| `is_politically_exposed` (PEP) | Sensible (PII de cumplimiento) | Dato de perfil PLD/AML — su exposición indebida puede ser tan dañina como la del propio CURP; no incluir en exports/reportes sin necesidad justificada. |
| Saldos y movimientos (`ledger_entries`) | Confidencial / financiero | Append-only por diseño (ver threat-model.md, punto 3). |
| `password_hash` (staff y cardholder) | Secreto | Nunca en texto plano, nunca en logs. Hashing vía bcrypt (`pgcrypto` en local; el backend real usa la misma familia de algoritmo). |
| `audit_log` | Integridad crítica | Debe tratarse como append-only igual que el ledger — es la evidencia ante un incidente o auditoría. |
| Credenciales del procesador externo / secrets de AWS | Secreto | Nunca en `.env` committeado — ver `AWS Secrets Manager` en la fase de despliegue (ADR-0004). |
| Datos de contacto del Tarjetahabiente (email, teléfono) | PII | Base para el plano de identidad de autoservicio — separado de los datos de `users` (staff). |

## Dos planos de identidad, dos políticas de autenticación

- **Staff (`users`)**: MFA recomendado/obligatorio según rol, sesión más
  corta, acceso desde consola administrativa.
- **Tarjetahabiente (`cardholder_users`)**: login simple + posible
  biométrico en el app móvil, pensado para uso frecuente de autoservicio.

Mantenerlos en tablas y flujos separados (ver `domain-model.md`) es lo que
permite que estas políticas diverjan sin lógica condicional dispersa por
el código.
