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
