# language: es
Característica: Visualización de saldo de Tarjeta
  Como usuario de staff autenticado
  Quiero ver el saldo actual de una tarjeta
  Para conocer su estado financiero sin poder modificarlo todavía

  Escenario: Tarjeta asignada muestra su saldo en el listado y en el detalle
    Dado que "Juan Perez" tiene una tarjeta activa con saldo
    Cuando veo el listado de Tarjetas
    Entonces veo el saldo junto a esa tarjeta
    Cuando entro a su detalle
    Entonces veo el mismo saldo, mostrado de forma prominente

  Escenario: Tarjeta disponible no muestra un monto
    Dado que una tarjeta está "Disponible" (sin asignar)
    Cuando la veo en el listado o en su detalle
    Entonces no veo ningún monto de saldo
    Y veo una indicación de que no tiene cuenta de saldo, no "$0.00"

  Escenario: Una tarjeta bloqueada sigue mostrando su saldo
    Dado que "Carlos Ruiz" tiene una tarjeta bloqueada con saldo
    Cuando veo su detalle
    Entonces el saldo se sigue mostrando con normalidad
