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
