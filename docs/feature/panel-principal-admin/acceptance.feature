# language: es
Característica: Panel principal de administración
  Como usuario de staff autenticado
  Quiero ver los Clientes dentro de mi alcance
  Para navegar hacia sus tarjetahabientes y tarjetas

  Escenario: Super Admin ve todos los Clientes
    Dado que inicié sesión como Super Admin
    Cuando entro al panel principal
    Entonces veo el listado completo de Clientes del sistema

  Escenario: Admin Cliente de la empresa padre ve también a las hijas
    Dado que inicié sesión como Admin Cliente de "Grupo Koons Holding"
    Y "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Cuando entro al panel principal
    Entonces veo "Grupo Koons Holding", "Koons Subsidiaria A" y "Koons Subsidiaria B"

  Escenario: Admin Cliente de una empresa hija no ve al padre ni a sus hermanas
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando entro al panel principal
    Entonces solo veo "Koons Subsidiaria A"
    Y no veo "Grupo Koons Holding" ni "Koons Subsidiaria B"
