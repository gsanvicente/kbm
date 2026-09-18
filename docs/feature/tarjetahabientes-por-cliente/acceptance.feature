# language: es
Característica: Tarjetahabientes por Cliente
  Como usuario de staff autenticado
  Quiero ver los tarjetahabientes de un Cliente que ya puedo ver
  Para navegar hacia sus tarjetas

  Escenario: Ver tarjetahabientes de una subsidiaria con datos
    Dado que estoy en el listado de Clientes
    Cuando hago clic en "Koons Subsidiaria A"
    Entonces veo el listado de sus tarjetahabientes
    Y veo un breadcrumb "Clientes / Koons Subsidiaria A"

  Escenario: Cliente sin tarjetahabientes propios muestra estado vacío
    Dado que estoy en el listado de Clientes
    Cuando hago clic en "Grupo Koons Holding"
    Entonces veo un mensaje indicando que no tiene tarjetahabientes propios,
      no una lista en blanco

  Escenario: Filtrar por Estado dentro del listado de un Cliente
    Dado que "Juan Perez" (de "Koons Subsidiaria A") está inactivo
    Cuando veo el listado de Tarjetahabientes de "Koons Subsidiaria A"
    Y selecciono "Inactivo" en el filtro de Estado
    Entonces solo veo a "Juan Perez" en el listado

  Escenario: Solo quien puede gestionar Tarjetahabientes ve el botón de alta
    Dado que inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo el listado de Tarjetahabientes de "Koons Subsidiaria A"
    Entonces no veo el botón "+ Nuevo Tarjetahabiente"
