# language: es
Característica: Operación de saldo con aprobación configurable
  Como Operador de Saldos
  Quiero solicitar una Dispersión, Deducción o Transferencia desde el detalle de una tarjeta
  Para mover fondos respetando las reglas de aprobación del Cliente dueño

  Escenario: Operación sin aprobación requerida se ejecuta de inmediato
    Dado que "Koons Subsidiaria A" no requiere aprobación para operaciones de tipo "load"
    Y "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" solicita una Dispersión de 100 desde el detalle de una tarjeta de "Koons Subsidiaria A"
    Entonces la operación queda en estado "executed"
    Y se registra un movimiento en el ledger de esa tarjeta
    Y el saldo mostrado en la pestaña "Resumen" de esa tarjeta se actualiza sin recargar la pantalla

  Escenario: Operación por encima del umbral requiere aprobación
    Dado que "Koons Subsidiaria A" requiere aprobación para transferencias mayores a 500
    Y "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" solicita una Transferencia de 800 hacia otra tarjeta de "Koons Subsidiaria A"
    Entonces la operación queda en estado "pending_approval"
    Y no se registra ningún movimiento en el ledger todavía
    Y el saldo mostrado en "Resumen" no cambia todavía

  Escenario: Sin regla configurada, la operación requiere aprobación por defecto
    Dado que "Koons Subsidiaria A" no tiene ninguna regla configurada para operaciones de tipo "debit"
    Y "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" solicita una Deducción de 50 desde el detalle de una tarjeta de "Koons Subsidiaria A"
    Entonces la operación queda en estado "pending_approval"

  Escenario: Auditor no puede solicitar operaciones de saldo
    Dado que inicié sesión como Auditor
    Cuando veo la pestaña "Operaciones" de una tarjeta dentro de mi alcance
    Entonces veo el historial de operaciones pero no los botones de Dispersión, Deducción o Transferencia

  Escenario: Admin Cliente aprueba una operación pendiente
    Dado que existe una operación en estado "pending_approval" sobre una tarjeta de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" aprueba la operación
    Entonces la operación pasa a estado "executed"
    Y se registra el movimiento en el ledger
    Y el registro de auditoría guarda que "Carlos" fue quien aprobó

  Escenario: Admin Cliente rechaza una operación pendiente con motivo
    Dado que existe una operación en estado "pending_approval" sobre una tarjeta de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" rechaza la operación indicando un motivo
    Entonces la operación pasa a estado "rejected"
    Y no se registra ningún movimiento en el ledger

  Escenario: Aprobar una operación sin saldo suficiente la marca como fallida
    Dado que una tarjeta de "Koons Subsidiaria A" tiene saldo de 100
    Y existe una Deducción de 500 en estado "pending_approval" sobre esa tarjeta
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" aprueba la operación
    Entonces la operación pasa a estado "failed"
    Y no se registra ningún movimiento en el ledger

  Escenario: Escribir los últimos 4 dígitos de una tarjeta del mismo Cliente resuelve el destino
    Dado que estoy en la pestaña "Operaciones" de la tarjeta de "Maria Gomez" en "Koons Subsidiaria B"
    Y "Carlos Ruiz" tiene una tarjeta activa terminación 7890 en "Koons Subsidiaria B"
    Cuando escribo "7890" en el campo de tarjeta destino de una Transferencia
    Entonces se muestra una confirmación con el nombre "Carlos Ruiz" y la terminación 7890

  Escenario: Los últimos 4 dígitos de una tarjeta de otro Cliente no resuelven ningún destino
    Dado que estoy en la pestaña "Operaciones" de la tarjeta de "Maria Gomez" en "Koons Subsidiaria B"
    Y "Juan Perez" tiene una tarjeta terminación 1234 en "Koons Subsidiaria A"
    Cuando escribo "1234" en el campo de tarjeta destino de una Transferencia
    Entonces no se encuentra ninguna coincidencia dentro de "Koons Subsidiaria B"

  Escenario: Una transferencia mueve saldo entre dos tarjetas del mismo Cliente
    Dado que "Maria Gomez" y "Carlos Ruiz" tienen tarjetas activas de "Koons Subsidiaria B"
    Y "Koons Subsidiaria B" no requiere aprobación para transferencias de 100
    Cuando un Operador transfiere 100 desde la tarjeta de "Maria Gomez" hacia la terminación 7890
    Entonces el saldo de "Maria Gomez" disminuye en 100
    Y el saldo de "Carlos Ruiz" aumenta en 100

  Escenario: Operador no puede aprobar ni rechazar
    Dado que inicié sesión como Operador
    Y existe una operación en estado "pending_approval" dentro de mi alcance
    Cuando veo la sección "Aprobaciones"
    Entonces veo la operación pero no los botones de aprobar o rechazar

  Escenario: Auditor solo puede consultar
    Dado que inicié sesión como Auditor
    Cuando veo la pestaña "Operaciones" de una tarjeta
    Entonces no veo los botones de Dispersión, Deducción o Transferencia

  Escenario: Operador de la empresa padre opera sobre una tarjeta de una subsidiaria
    Dado que "Koons Subsidiaria A" es hija de "Grupo Koons Holding"
    Y "Luis" es Operador de "Grupo Koons Holding"
    Cuando "Luis" solicita una Deducción desde el detalle de una tarjeta de "Koons Subsidiaria A"
    Entonces la solicitud se acepta como si "Luis" perteneciera a "Koons Subsidiaria A"

  Escenario: Operador de una empresa hija no puede operar sobre empresas hermanas
    Dado que "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Y "Marta" es Operador de "Koons Subsidiaria A"
    Cuando "Marta" intenta abrir el detalle de una tarjeta de "Koons Subsidiaria B"
    Entonces no tiene acceso a esa tarjeta en absoluto
