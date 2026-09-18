# language: es
Característica: Portal de autoservicio del Tarjetahabiente
  Como Tarjetahabiente
  Quiero ver y operar mis propias cuentas desde un portal web
  Sin depender de un Operador ni tocar la gestión de saldos del staff

  Escenario: Login exitoso muestra el saldo de la tarjeta
    Dado que "Juan Perez" es un Tarjetahabiente con cuenta de autoservicio activada
    Cuando inicia sesión con su email y contraseña
    Entonces ve el saldo actual de su tarjeta

  Escenario: Tarjetahabiente con más de una tarjeta ve un selector
    Dado que "Juan Perez" tiene dos tarjetas activas
    Cuando inicia sesión
    Entonces ve un selector para elegir cuál tarjeta consultar

  Escenario: El estado de cuenta se puede filtrar por rango de fechas
    Dado que "Juan Perez" ve el detalle de su tarjeta
    Cuando filtra su estado de cuenta por un rango de fechas
    Entonces solo ve los movimientos dentro de ese rango
    Y ve un resumen con el total de créditos y débitos del periodo

  Escenario: Congelar la propia tarjeta
    Dado que la tarjeta de "Juan Perez" está "active"
    Cuando la congela desde el portal
    Entonces la tarjeta queda en estado "frozen"
    Y puede descongelarla él mismo más tarde

  Escenario: Un bloqueo del staff no se puede revertir desde el portal
    Dado que un Admin Cliente bloqueó la tarjeta de "Juan Perez" ("blocked")
    Cuando "Juan Perez" entra al detalle de su tarjeta
    Entonces no ve ninguna acción de autoservicio disponible sobre esa tarjeta
    Y ve un mensaje indicando que debe contactar a su administrador

  Escenario: Un bloqueo del staff prevalece incluso si el usuario ya la había congelado
    Dado que "Juan Perez" congeló su propia tarjeta ("frozen")
    Y luego un Admin Cliente la bloquea ("blocked")
    Cuando "Juan Perez" entra al detalle de su tarjeta
    Entonces la ve bloqueada, no congelada, y sin acción de autoservicio disponible

  Escenario: Presentar un reclamo sobre un movimiento propio
    Dado que "Juan Perez" ve un movimiento en su estado de cuenta
    Cuando presenta un reclamo sobre ese movimiento
    Entonces el reclamo queda registrado con su propio correo como solicitante

  Escenario: El registro/activación de cuenta no es parte de esta versión
    Dado que un Tarjetahabiente todavía no activó su cuenta de autoservicio
    Cuando intenta entrar al portal web
    Entonces no encuentra un flujo de registro — solo login
