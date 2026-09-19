# language: es
Característica: Tarjetas del Tarjetahabiente
  Como usuario de staff autenticado
  Quiero ver las tarjetas de un tarjetahabiente desde su detalle
  Para conocer su estado sin salir de la pantalla

  Escenario: Tarjetahabiente con una tarjeta asignada
    Dado que veo el detalle de "Juan Perez"
    Cuando reviso la sección "Tarjetas"
    Entonces veo su tarjeta con terminaciones, red, vigencia y estado

  Escenario: Tarjetahabiente sin tarjetas asignadas
    Dado que "Ana Torres" no tiene tarjetas asignadas
    Cuando veo su detalle
    Entonces la sección "Tarjetas" muestra un estado vacío, no una lista en blanco

  Escenario: Asignar una tarjeta directamente desde el Tarjetahabiente
    Dado que "Ana Torres" está activa y no tiene tarjetas asignadas
    Y su Cliente tiene al menos una tarjeta disponible
    Cuando un Admin Cliente toca "Asignar tarjeta" en su detalle
    Y elige una tarjeta disponible y confirma
    Entonces esa tarjeta pasa a estado "activa", ligada a "Ana Torres"
    Y ya no aparece un estado vacío en la sección "Tarjetas"

  Escenario: No se puede asignar tarjeta a un Tarjetahabiente inactivo desde su propia página
    Dado que un Tarjetahabiente está inactivo
    Cuando veo su detalle
    Entonces no veo el botón "Asignar tarjeta"
