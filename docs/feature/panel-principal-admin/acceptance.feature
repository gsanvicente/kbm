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

  Escenario: Admin Cliente ve el árbol expandido por defecto
    Dado que inicié sesión como Admin Cliente de "Grupo Koons Holding"
    Cuando entro a "Clientes"
    Entonces veo "Koons Subsidiaria A" y "Koons Subsidiaria B" ya visibles, sin expandir nada

  Escenario: Super Admin ve el árbol colapsado por defecto
    Dado que inicié sesión como Super Admin
    Cuando entro a "Clientes"
    Entonces solo veo las empresas raíz
    Y no veo "Koons Subsidiaria A" ni "Koons Subsidiaria B" hasta expandir "Grupo Koons Holding"

  Escenario: Buscar por RFC filtra el árbol y muestra la cadena de ancestros
    Dado que "Koons Subsidiaria A" es hija de "Grupo Koons Holding" y tiene un RFC conocido
    Cuando busco ese RFC en el campo de búsqueda de Clientes
    Entonces veo "Koons Subsidiaria A" en el resultado
    Y también veo a "Grupo Koons Holding" (su ancestro), aunque no coincida con la búsqueda
    Y no veo a "Koons Subsidiaria B"

  Escenario: El breadcrumb muestra la cadena completa de ancestros
    Dado que "Koons Subsidiaria A" es hija de "Grupo Koons Holding"
    Cuando entro al detalle de "Koons Subsidiaria A"
    Entonces el breadcrumb muestra "Clientes > Grupo Koons Holding > Koons Subsidiaria A"
