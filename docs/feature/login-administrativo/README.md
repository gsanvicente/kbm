# Login administrativo

- Estado: En desarrollo (esta iteración: solo `admin/`, con repositorio fake — ver nota de alcance)
- ADR/TDR relacionados: `docs/adr/0001-go-hexagonal-modular-monolith.md`, `docs/adr/0006-openapi-contract.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 (control de acceso) y 7 (secretos/credenciales)
- Roles/actores involucrados: Super Admin, Admin Cliente, Operador, Auditor (todos los roles de staff — ver `docs/business/roles-and-permissions.md`)

## Objetivo
Permitir que un usuario de staff (no tarjetahabiente) se autentique en la
consola administrativa (`admin/`) y obtenga una sesión con su rol y alcance
(Cliente + jerarquía) para las siguientes operaciones.

## Contexto / motivación
Primer "walking skeleton" del sistema: la meta es probar de punta a punta
que un flujo completo (UI → contrato → autorización) funciona antes de
construir el resto de features sobre el mismo patrón.

## Nota de alcance de esta iteración
Por decisión explícita (ver conversación 2026-09-15), esta iteración
implementa la pantalla de login en `admin/` contra un
`AuthRepository` **fake en memoria** (mismos usuarios que
`backend/scripts/init-db/001_seed.sql`), mientras se resuelve la
instalación de Postgres/Docker local. El backend real (`POST /auth/login`
en Go) se documenta aquí igual, y se implementa en una iteración
siguiente sin cambiar el contrato ni la UI — solo se reemplaza la
implementación del repositorio.

## Flujo principal
1. El usuario ingresa email y contraseña en la pantalla de login.
2. El sistema valida las credenciales.
3. Si son válidas y el usuario está activo → se crea una sesión con su
   rol y `client_id` (nulo para Super Admin).
4. Si son inválidas, o el usuario está inactivo → se rechaza con un
   mensaje genérico (no se revela cuál de los dos motivos fue).
5. Todo intento (éxito o fallo) queda registrado en `audit_log` (backend
   real — no aplica al repositorio fake de esta iteración).

## Reglas de negocio
- Un usuario inactivo (`is_active = false`) no puede iniciar sesión,
  aunque la contraseña sea correcta.
- El mensaje de error no distingue entre "email no existe" y "contraseña
  incorrecta" (evita enumeración de usuarios).

## Casos borde / fuera de alcance
- Recuperación de contraseña / "olvidé mi contraseña": fuera de alcance
  de esta feature.
- MFA: mencionado en `docs/security/data-classification.md` como
  recomendado para staff, no implementado en esta iteración.

## Criterios de aceptación
Ver `acceptance.feature`.
