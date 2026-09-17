# language: es
Característica: Detalle y gestión de Tarjetahabiente
  Como Admin Cliente o Super Admin
  Quiero ver y editar la información de un tarjetahabiente, o desactivarlo
  Para mantener sus datos correctos sin depender del backend real

  Escenario: Admin Cliente edita la información de un tarjetahabiente de su alcance
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Y veo el detalle de "Juan Perez"
    Cuando actualizo su teléfono
    Entonces el cambio se refleja de inmediato en el detalle y en el listado

  Escenario: Admin Cliente desactiva un tarjetahabiente
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Y veo el detalle de "Juan Perez", que está activo
    Cuando lo desactivo
    Entonces su estado pasa a "Inactivo"
    Y no se me pide ninguna aprobación para hacerlo

  Escenario: Operador ve el detalle pero no puede editar ni desactivar
    Dado que inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo el detalle de "Juan Perez"
    Entonces veo su información
    Pero no veo controles para editar ni desactivar

  Escenario: Auditor ve el detalle pero no puede editar ni desactivar
    Dado que inicié sesión como Auditor de "Koons Subsidiaria A"
    Cuando veo el detalle de "Juan Perez"
    Entonces veo su información
    Pero no veo controles para editar ni desactivar
