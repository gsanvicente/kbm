# Clasificación de datos — KBM

> Referencia viva. Última revisión: 2026-09-15.

| Dato | Clasificación | Notas |
|---|---|---|
| PAN de tarjeta | **Fuera de alcance** | KBM solo almacena `masked_pan` (ej. `**** **** **** 1234`). El PAN real vive en el procesador de tarjetas externo, nunca en la base de datos de KBM. Ver `compliance-notes.md`. |
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
