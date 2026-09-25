# language: es
Característica: Movimientos y Reclamos
  Como usuario de staff autenticado
  Quiero ver los movimientos de una tarjeta y disputar uno si hace falta
  Para llevar trazabilidad de discrepancias sin modificar el ledger

  Escenario: Ver el historial de movimientos de una tarjeta
    Dado que "Juan Perez" tiene una tarjeta con movimientos
    Cuando entro a la pestaña "Movimientos" de su detalle
    Entonces veo cada movimiento con fecha, descripción, monto y saldo resultante

  Escenario: Operador solicita un reclamo sobre un movimiento
    Dado que inicié sesión como Operador
    Y veo el detalle de un movimiento sin reclamo
    Cuando lo reclamo con un motivo
    Entonces el movimiento queda con un reclamo en estado "Abierto"
    Y veo el badge de "Abierto" en la fila del movimiento

  Escenario: Auditor no puede solicitar un reclamo
    Dado que inicié sesión como Auditor
    Cuando veo el detalle de un movimiento sin reclamo
    Entonces no veo el botón "Reclamar"

  Escenario: Admin Cliente resuelve un reclamo a favor
    Dado que un movimiento tiene un reclamo "Abierto"
    Y inicié sesión como Admin Cliente
    Cuando lo resuelvo a favor con notas de resolución
    Entonces el reclamo pasa a "Resuelto a favor"
    Y el movimiento original no cambia de monto ni de saldo

  Escenario: Operador no puede resolver un reclamo
    Dado que inicié sesión como Operador
    Y veo un movimiento con un reclamo "Abierto"
    Entonces no veo botones para resolverlo, solo su estado

  Escenario: Descargar los Movimientos de una tarjeta genera un PDF de esa tarjeta, no de toda la Cuenta Individual
    Dado que "Juan Perez" tiene dos tarjetas, cada una con sus propios movimientos
    Cuando entro a la pestaña "Movimientos" de una de sus tarjetas y pulso "Descargar"
    Entonces recibo un PDF con branding de KBM/Koons que identifica esa tarjeta y a "Juan Perez"
    Y el PDF no incluye los movimientos de su otra tarjeta
