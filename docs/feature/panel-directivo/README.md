# Panel directivo ("Inicio")

- Estado: En desarrollo (esta iteración: `admin/` con repositorio fake)
- ADR/TDR relacionados: `docs/adr/0003-multitenancy-rls-hierarchy.md`
- Amenazas relevantes: `docs/security/threat-model.md` puntos 1 y 2
  (control de acceso, fuga de datos entre tenants) — un panel que agrega
  cifras de varios Clientes es exactamente el tipo de pantalla donde un
  error de alcance filtraría datos de un Cliente a otro
- Roles/actores involucrados: Super Admin y Admin Cliente (ver "Quién ve
  esto" más abajo) — Operador y Auditor no tienen esta pantalla

## Objetivo
Dar a quien gestiona la estructura de la empresa (Super Admin o Admin
Cliente) un resumen ejecutivo al iniciar sesión: saldos agregados,
operaciones/depósitos que requieren su acción, y una foto de la huella
operativa (tarjetas), sin tener que entrar Cliente por Cliente a
recolectarlo manualmente.

## Contexto / motivación
Hasta ahora el punto de entrada tras el login era el listado de Clientes
(`docs/feature/panel-principal-admin/`), una pantalla de navegación, no
de información. A medida que crece el número de Clientes/filiales, un
directivo necesita un lugar que responda "¿cómo está todo?" antes de
decidir a dónde entrar.

## Nota de alcance de esta iteración
- Repositorio fake (`DashboardRepository`) que compone los repositorios
  fake ya existentes (Cliente, Tarjeta, Ledger, Tesorería, Operaciones de
  saldo) — no tiene datos propios, ver comentario en
  `FakeDashboardRepository`.
- Asume una sola moneda (MXN) al sumar entre Clientes, igual que el resto
  de la plataforma en esta iteración.
- La gráfica de volumen semanal (ver "Volumen de movimientos" abajo) usa
  **datos sintéticos deterministas**, no operaciones reales — ver la nota
  de alcance dedicada más abajo. Todo lo demás en esta pantalla (saldos,
  pendientes, reclamos, tarjetas) es 100% real sobre el estado actual de
  los repositorios fake.
- No hay actualización en vivo: se calcula una vez al entrar a la
  pantalla, mismo patrón que el indicador de saldo del encabezado
  (`docs/feature/tesoreria-cliente/README.md`).
- No hay selector de rango de fechas ni exportación/reportes.

## Quién ve esto
Solo **Super Admin** y **Admin Cliente** (`Role.canViewExecutiveDashboard`,
mismo grupo que `canManageCardholders`) aterrizan en "Inicio" tras iniciar
sesión, y son los únicos que ven ese ítem en el menú lateral. Operador y
Auditor siguen aterrizando en "Clientes": es un resumen pensado para quien
gestiona la estructura de la empresa, no para el uso operativo del día a
día — ver `docs/business/roles-and-permissions.md`.

## Alcance de datos por rol
Se reutiliza exactamente `ClientRepository.listAccessibleClients(session)`
— el mismo Cliente propio + descendientes que ya usa el resto de la
plataforma (`docs/business/roles-and-permissions.md`, "Herencia sobre la
jerarquía padre/hija"):

- **Super Admin**: todas las empresas del sistema.
- **Admin Cliente**: su empresa + todas las descendientes. Si no tiene
  filiales, el panel simplemente no muestra la sección "Desglose por
  empresa" (una sola empresa no necesita compararse consigo misma).

## Contenido de la pantalla
1. **Cifras clave** (fila de tarjetas KPI):
   - Saldo total en Cuentas Concentradoras (suma de
     `ConcentratorAccount.balance` de los Clientes en alcance).
   - Saldo total cargado en tarjetas (suma de `LedgerAccount.balance`).
   - Depósitos pendientes de conciliar (cuenta + monto).
   - Operaciones pendientes de aprobación (cuenta + monto).
   - Reclamos abiertos (cuenta).
   - Estado de tarjetas: activas / disponibles / bloqueadas-congeladas.
2. **Desglose por empresa** (solo si hay más de un Cliente en alcance):
   tabla comparando saldo de Concentradora, tarjetas activas, operaciones
   y depósitos pendientes por cada Cliente.
3. **Requiere tu atención** (revisado 2026-09-17): las hasta 5 operaciones
   pendientes de aprobación y los hasta 5 depósitos pendientes de
   conciliar más recientes, ambos con hipervínculo. Tocar una operación
   pendiente navega a "Operaciones de saldo" abriendo la pestaña
   "Pendientes de aprobación"; tocar un depósito pendiente navega ahí
   mismo pero abriendo la pestaña "Depósitos por conciliar" — ver
   `docs/feature/operacion-saldo-con-aprobacion/README.md`, sección
   "'Operaciones de saldo' es un hub con tres pestañas". Conciliar sigue
   estando también disponible desde la Tesorería de cada Cliente (dos
   entry points a propósito, ver
   `docs/feature/tesoreria-cliente/README.md`).
4. **Volumen de movimientos** (gráfica de barras apiladas,
   Dispersión/Deducción/Transferencia, últimas 12 semanas) — ver nota de
   alcance dedicada abajo.

## Volumen de movimientos: dato sintético (nota de alcance importante)
La gráfica de la sección 4 **no refleja operaciones reales**. Se genera
de forma determinista (semilla fija, sin `DateTime.now()`) dentro de
`FakeBalanceOperationRepository.getWeeklyTrend`, deliberadamente separada
de `listByClients` (el historial real que alimenta las pestañas
"Pendientes de aprobación" e "Historial completo" del hub "Operaciones
de saldo") — nunca se mezclan.

- **Por qué es sintética:** el objetivo de este panel es mostrar la forma
  final de un resumen ejecutivo con volumen histórico antes de que exista
  suficiente actividad real para que una gráfica de tendencia tenga
  sentido. La UI incluye un aviso visible ("Dato ilustrativo mientras no
  haya integración bancaria real...") para que nadie —en una demo, una
  revisión de negocio o una auditoría de seguridad— la confunda con
  transacciones reales.
- **Por qué una ventana fija reciente (jun–sep 2026) y no enero 2026**
  (como el resto del seed): el resto de los datos fake no necesita verse
  "vigente", pero esta gráfica sí — una ventana de hace 8 meses se vería
  como una demo desactualizada. La ventana termina cerca del "hoy" de
  esta iteración (2026-09-17).
- **Por qué semanas y no días**: con ~12 semanas de datos, una gráfica
  diaria se ve ruidosa; agrupar por semana es más legible para una
  audiencia directiva y evita 80+ barras diminutas.
- **Es un dato de flujo, no de saldo**: no se espera que el total de la
  gráfica cuadre con el saldo actual de ninguna Concentradora — son
  conceptos distintos (cuánto se movió en 12 semanas vs. cuánto hay
  ahorita).
- **Qué pasa cuando exista backend real**: `getWeeklyTrend` se reimplementa
  como una consulta/reporte real (agrupar `balance_operations` reales por
  semana); nada en `DashboardSection` ni en `DashboardSummary` cambia.

## Reglas de negocio
No se introduce ninguna regla de negocio nueva — este panel solo lee y
agrega datos ya gobernados por `docs/business/tesoreria-cliente.md`,
`docs/business/saldo-y-ledger.md`, `docs/business/approval-policy.md` y
`docs/business/reclamos-de-movimientos.md`. La única regla propia es la
de visibilidad del panel mismo, ver `docs/business/roles-and-permissions.md`.

## Casos borde / fuera de alcance
- Gráficas de tendencia sobre datos reales: fuera de alcance hasta que
  haya backend y volumen histórico real.
- Exportar/imprimir el panel, filtros de fecha personalizados: fuera de
  alcance.
- Actualización en vivo (sin recargar/volver a iniciar sesión): fuera de
  alcance, mismo criterio que el indicador de saldo del encabezado.
- Deep-link directo hacia la pestaña Tesorería de un Cliente específico:
  sigue fuera de alcance — el shell actual no tiene navegación anidada
  entre secciones. Esto ya no aplica al hipervínculo de depósitos
  pendientes (revisado 2026-09-17): ese salta a "Operaciones de saldo" →
  pestaña "Depósitos por conciliar" (una sección de primer nivel con una
  pestaña fija), no a la Tesorería de un Cliente en particular.
- Métricas para Operador/Auditor: no aplica, no tienen esta pantalla.
- La "cuenta raíz de Koons" (visión futura descrita en
  `docs/business/tesoreria-cliente.md`) no participa de ninguna cifra de
  este panel todavía.

## Criterios de aceptación
Ver `acceptance.feature` en esta misma carpeta.
