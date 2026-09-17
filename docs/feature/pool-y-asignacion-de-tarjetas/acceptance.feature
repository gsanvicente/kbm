# language: es
Característica: Pool y asignación de Tarjetas
  Como Admin Cliente o Super Admin
  Quiero asignar una tarjeta disponible a un tarjetahabiente
  Para que pueda empezar a usarla

  Escenario: Asignar una tarjeta disponible dentro del límite configurado
    Dado que "Koons Subsidiaria B" permite hasta 2 tarjetas activas por tarjetahabiente
    Y "Maria Gomez" tiene actualmente 1 tarjeta activa
    Y existe una tarjeta disponible de "Koons Subsidiaria B"
    Cuando un Admin Cliente asigna esa tarjeta a "Maria Gomez"
    Entonces la tarjeta pasa a estado "activa"
    Y aparece en la sección "Tarjetas" del detalle de "Maria Gomez"

  Escenario: Rechazar la asignación si se alcanzó el límite
    Dado que "Koons Subsidiaria A" permite hasta 1 tarjeta activa por tarjetahabiente
    Y "Juan Perez" ya tiene 1 tarjeta activa
    Y existe una tarjeta disponible de "Koons Subsidiaria A"
    Cuando un Admin Cliente intenta asignar esa tarjeta a "Juan Perez"
    Entonces la asignación se rechaza
    Y el mensaje explica el límite configurado, no solo "no se pudo"

  Escenario: Operador no puede asignar tarjetas
    Dado que inicié sesión como Operador
    Cuando veo una tarjeta disponible en el listado de "Tarjetas"
    Entonces no veo el botón "Asignar"

  Escenario: No se puede asignar una tarjeta de otro Cliente
    Dado que una tarjeta disponible pertenece a "Koons Subsidiaria B"
    Cuando un Admin Cliente de "Koons Subsidiaria A" intenta asignarla
    Entonces "Koons Subsidiaria A" no aparece como opción de destino válida,
      porque el Tarjetahabiente debe pertenecer al mismo Cliente que la tarjeta

  Escenario: Filtrar el listado por varios estados a la vez
    Dado que inicié sesión como Super Admin en el listado de "Tarjetas"
    Cuando selecciono "Bloqueada" y "Congelada" en el filtro de Estado
    Entonces solo veo tarjetas en esos dos estados

  Escenario: El filtro de Empresa no aparece si solo hay un Cliente accesible
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando entro al listado de "Tarjetas"
    Entonces no veo el filtro de Empresa

  Escenario: Buscar tarjetas por el nombre del Tarjetahabiente asignado
    Dado que inicié sesión como Super Admin en el listado de "Tarjetas"
    Cuando escribo "Juan" en el buscador de Tarjetahabiente
    Y selecciono "Juan Perez" de las sugerencias
    Entonces solo veo las tarjetas asignadas a "Juan Perez"
