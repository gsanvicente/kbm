# language: es
Característica: Bloqueo / desbloqueo de Tarjeta
  Como Operador, Admin Cliente o Super Admin
  Quiero bloquear o desbloquear una tarjeta asignada
  Para deshabilitarla temporalmente sin depender de una aprobación

  Escenario: Operador bloquea una tarjeta activa, tras confirmar
    Dado que inicié sesión como Operador
    Y veo el detalle de una tarjeta "Activa"
    Cuando pulso "Bloquear" y confirmo el diálogo
    Entonces su estado pasa a "Bloqueada" de inmediato
    Y no se me pide ninguna aprobación

  Escenario: Cancelar el diálogo de bloqueo no cambia nada
    Dado que inicié sesión como Operador
    Y veo el detalle de una tarjeta "Activa"
    Cuando pulso "Bloquear" y cancelo el diálogo
    Entonces su estado sigue siendo "Activa"

  Escenario: Operador desbloquea una tarjeta bloqueada, tras confirmar
    Dado que inicié sesión como Operador
    Y veo el detalle de una tarjeta "Bloqueada"
    Cuando pulso "Desbloquear" y confirmo el diálogo
    Entonces su estado vuelve a "Activa"

  Escenario: Auditor no puede bloquear ni desbloquear
    Dado que inicié sesión como Auditor
    Cuando veo el detalle de una tarjeta asignada
    Entonces no veo ningún botón de bloquear ni desbloquear

  Escenario: Una tarjeta disponible no tiene control de bloqueo
    Dado que veo el detalle de una tarjeta "Disponible"
    Entonces no veo ningún botón de bloquear ni desbloquear
    Y en su lugar veo, si mi rol lo permite, el botón "Asignar"
