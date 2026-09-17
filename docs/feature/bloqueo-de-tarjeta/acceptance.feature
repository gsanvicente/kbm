# language: es
Característica: Bloqueo / desbloqueo de Tarjeta
  Como Operador, Admin Cliente o Super Admin
  Quiero bloquear o desbloquear una tarjeta asignada
  Para deshabilitarla temporalmente sin depender de una aprobación

  Escenario: Operador bloquea una tarjeta activa
    Dado que inicié sesión como Operador
    Y veo el detalle de una tarjeta "Activa"
    Cuando la bloqueo
    Entonces su estado pasa a "Bloqueada" de inmediato
    Y no se me pide ninguna aprobación

  Escenario: Operador desbloquea una tarjeta bloqueada
    Dado que inicié sesión como Operador
    Y veo el detalle de una tarjeta "Bloqueada"
    Cuando la desbloqueo
    Entonces su estado vuelve a "Activa"

  Escenario: Auditor no puede bloquear ni desbloquear
    Dado que inicié sesión como Auditor
    Cuando veo el detalle de una tarjeta asignada
    Entonces no veo ningún botón de bloquear ni desbloquear

  Escenario: Una tarjeta disponible no tiene control de bloqueo
    Dado que veo el detalle de una tarjeta "Disponible"
    Entonces no veo ningún botón de bloquear ni desbloquear
    Y en su lugar veo, si mi rol lo permite, el botón "Asignar"
