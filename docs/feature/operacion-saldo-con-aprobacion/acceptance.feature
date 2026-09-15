# language: es
Característica: Operación de saldo con aprobación configurable
  Como Operador o Tarjetahabiente
  Quiero solicitar una operación de saldo sobre una tarjeta
  Para mover fondos respetando las reglas de aprobación del Cliente dueño

  Escenario: Operación sin aprobación requerida se ejecuta de inmediato
    Dado que "Koons Subsidiaria A" no requiere aprobación para operaciones de tipo "load"
    Y "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" solicita una carga de 100 sobre una tarjeta de "Koons Subsidiaria A"
    Entonces la operación queda en estado "executed"
    Y se registra un movimiento en el ledger de esa tarjeta

  Escenario: Operación por encima del umbral requiere aprobación
    Dado que "Koons Subsidiaria A" requiere aprobación para transferencias mayores a 500
    Y "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" solicita una transferencia de 800 sobre una tarjeta de "Koons Subsidiaria A"
    Entonces la operación queda en estado "pending_approval"
    Y no se registra ningún movimiento en el ledger todavía

  Escenario: Admin Cliente aprueba una operación pendiente
    Dado que existe una operación en estado "pending_approval" sobre una tarjeta de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" aprueba la operación
    Entonces la operación pasa a estado "executed"
    Y se registra el movimiento en el ledger
    Y el registro de auditoría guarda que "Carlos" fue quien aprobó

  Escenario: Operador de la empresa padre opera sobre una tarjeta de una subsidiaria
    Dado que "Koons Subsidiaria A" es hija de "Grupo Koons Holding"
    Y "Luis" es Operador de "Grupo Koons Holding"
    Cuando "Luis" solicita un débito sobre una tarjeta de "Koons Subsidiaria A"
    Entonces la solicitud se acepta como si "Luis" perteneciera a "Koons Subsidiaria A"

  Escenario: Operador de una empresa hija no puede operar sobre la empresa padre ni sobre empresas hermanas
    Dado que "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Y "Marta" es Operador de "Koons Subsidiaria A"
    Cuando "Marta" intenta operar sobre una tarjeta de "Koons Subsidiaria B"
    Entonces la operación se rechaza por falta de autorización
    Y el intento queda registrado en el log de auditoría
