# language: es
Característica: Listado global de Tarjetahabientes
  Como usuario de staff autenticado
  Quiero ver todos los tarjetahabientes dentro de mi alcance en un solo listado
  Para encontrar a alguien sin saber antes a qué Cliente pertenece

  Escenario: Super Admin ve tarjetahabientes de todos los Clientes
    Dado que inicié sesión como Super Admin
    Cuando entro a "Tarjetahabientes" desde el menú principal
    Entonces veo tarjetahabientes de "Koons Subsidiaria A" y de "Koons Subsidiaria B"

  Escenario: Admin Cliente de la empresa padre ve tarjetahabientes de las hijas
    Dado que inicié sesión como Admin Cliente de "Grupo Koons Holding"
    Cuando entro a "Tarjetahabientes" desde el menú principal
    Entonces veo tarjetahabientes de "Koons Subsidiaria A" y de "Koons Subsidiaria B"

  Escenario: Admin Cliente de una empresa hija solo ve los suyos
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando entro a "Tarjetahabientes" desde el menú principal
    Entonces solo veo tarjetahabientes de "Koons Subsidiaria A"
    Y no veo tarjetahabientes de "Koons Subsidiaria B"

  Escenario: Filtrar el listado por Empresa
    Dado que inicié sesión como Super Admin en "Tarjetahabientes"
    Cuando selecciono "Koons Subsidiaria B" en el filtro de Empresa
    Entonces solo veo tarjetahabientes de "Koons Subsidiaria B"

  Escenario: El filtro de Empresa no aparece si solo hay un Cliente accesible
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando entro a "Tarjetahabientes" desde el menú principal
    Entonces no veo el filtro de Empresa

  Escenario: Buscar un tarjetahabiente por nombre
    Dado que inicié sesión como Super Admin en "Tarjetahabientes"
    Cuando escribo "Maria" en el buscador de nombre
    Y selecciono "Maria Gomez" de las sugerencias
    Entonces solo veo a "Maria Gomez" en el listado

  Escenario: Filtrar el listado por Estado
    Dado que "Juan Perez" está inactivo
    Cuando selecciono "Inactivo" en el filtro de Estado
    Entonces solo veo tarjetahabientes inactivos, incluido "Juan Perez"

  Escenario: Filtrar el listado por PEP
    Dado que inicié sesión como Super Admin en "Tarjetahabientes"
    Cuando selecciono "Sí" en el filtro de PEP
    Entonces solo veo tarjetahabientes marcados como Persona Políticamente Expuesta

  Escenario: El listado muestra el estado de cada tarjetahabiente sin abrir su detalle
    Dado que "Juan Perez" está inactivo y el resto están activos
    Cuando veo el listado global de Tarjetahabientes
    Entonces veo un pill "Inactivo" junto a "Juan Perez"
    Y veo un pill "Activo" junto a los demás
