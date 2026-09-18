# language: es
Característica: Alta, edición y desactivación de Clientes
  Como Super Admin o Admin Cliente
  Quiero dar de alta, editar y desactivar/reactivar un Cliente
  Respetando mi propio alcance dentro de la estructura multi-tenant

  Escenario: Super Admin crea una nueva empresa raíz, sin padre
    Dado que inicié sesión como Super Admin
    Cuando creo un nuevo Cliente sin elegir empresa padre
    Entonces el Cliente se crea sin `parent_client_id`
    Y aparece en el listado de Clientes de todos los Super Admin

  Escenario: Admin Cliente crea una filial de su propia empresa
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" crea un nuevo Cliente eligiendo "Koons Subsidiaria A" como padre
    Entonces el nuevo Cliente queda como hija de "Koons Subsidiaria A"
    Y "Carlos" lo ve de inmediato en su listado de Clientes

  Escenario: Admin Cliente crea una filial de una de sus propias filiales
    Dado que "Koons Subsidiaria A" es hija de "Grupo Koons Holding"
    Y "Luis" es Admin Cliente de "Grupo Koons Holding"
    Cuando "Luis" crea un nuevo Cliente eligiendo "Koons Subsidiaria A" como padre
    Entonces el nuevo Cliente queda como nieta de "Grupo Koons Holding"

  Escenario: Admin Cliente no puede crear una empresa raíz sin padre
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" intenta crear un Cliente sin elegir empresa padre
    Entonces no ve la opción de crear sin padre en absoluto

  Escenario: Admin Cliente no puede crear fuera de su propio alcance
    Dado que "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" abre el selector de empresa padre
    Entonces no ve a "Koons Subsidiaria B" como opción disponible

  Escenario: Operador y Auditor no tienen la opción de crear un Cliente
    Dado que inicié sesión como Operador o como Auditor
    Cuando veo la sección "Clientes"
    Entonces no veo ningún botón para crear un Cliente nuevo

  Escenario: El apoderado principal y el beneficiario controlador mayoritario son obligatorios
    Dado que estoy completando el formulario de alta de un Cliente
    Cuando intento avanzar sin capturar un apoderado principal o un beneficiario controlador mayoritario
    Entonces el formulario no permite continuar sin esos datos

  Escenario: Apoderados adicionales y beneficiarios minoritarios son opcionales
    Dado que ya capturé el apoderado principal y el beneficiario controlador mayoritario
    Cuando no agrego ningún apoderado ni beneficiario adicional
    Entonces puedo completar el alta del Cliente de todas formas

  Escenario: Cada filial requiere su propio expediente KYB, sin heredar del padre
    Dado que "Koons Subsidiaria A" ya tiene su expediente KYB completo
    Cuando se crea una nueva filial de "Koons Subsidiaria A"
    Entonces el formulario de la nueva filial empieza vacío
    Y no se copia ningún dato del expediente de "Koons Subsidiaria A"

  Escenario: Editar un Cliente existente muestra todas las secciones a la vez, sin pasos
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" edita el expediente de "Koons Subsidiaria A"
    Entonces ve todas las secciones (Datos generales, Domicilio, Apoderados, Beneficiarios) en una sola página
    Y la empresa padre aparece de solo lectura

  Escenario: Admin Cliente puede desactivar una filial suya, pero no su propia empresa
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Y "Koons Subsidiaria A" tiene una filial propia
    Cuando "Carlos" ve el detalle de su propia empresa
    Entonces no ve ninguna opción para desactivarla
    Cuando "Carlos" ve el detalle de su filial
    Entonces sí ve la opción de desactivarla

  Escenario: Desactivar una empresa matriz desactiva también a sus filiales
    Dado que "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Cuando un Super Admin desactiva "Grupo Koons Holding"
    Entonces "Koons Subsidiaria A" y "Koons Subsidiaria B" también quedan inactivas

  Escenario: Un Cliente inactivo sigue siendo visible mientras nada puede operar sobre él
    Dado que "Koons Subsidiaria A" está inactiva
    Cuando alguien con alcance de lectura la busca en el listado de Clientes
    Entonces la sigue viendo, marcada como inactiva
    Y no ve ninguna acción operativa disponible sobre ella

  Escenario: Reactivar una empresa matriz reactiva también a sus filiales
    Dado que "Grupo Koons Holding" y sus filiales están inactivas
    Cuando un Super Admin reactiva "Grupo Koons Holding"
    Entonces todas sus filiales también quedan activas de nuevo
