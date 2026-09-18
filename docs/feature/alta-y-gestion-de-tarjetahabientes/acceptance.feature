# language: es
Característica: Alta, edición y desactivación de Tarjetahabientes
  Como Super Admin o Admin Cliente
  Quiero dar de alta, editar y desactivar/reactivar un Tarjetahabiente
  Respetando mi propio alcance y sin dejar tarjetas operables de más

  Escenario: Admin Cliente da de alta un nuevo Tarjetahabiente de su propia empresa
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" crea un nuevo Tarjetahabiente desde la pestaña de Tarjetahabientes de "Koons Subsidiaria A"
    Entonces el nuevo Tarjetahabiente queda ligado a "Koons Subsidiaria A"
    Y aparece de inmediato en el listado de ese Cliente y en el listado global

  Escenario: Operador y Auditor no tienen la opción de crear un Tarjetahabiente
    Dado que inicié sesión como Operador o como Auditor
    Cuando veo la pestaña de Tarjetahabientes de un Cliente
    Entonces no veo ningún botón para crear un Tarjetahabiente nuevo

  Escenario: CURP es obligatorio solo para nacionalidad Mexicana
    Dado que estoy completando el formulario de alta de un Tarjetahabiente
    Cuando elijo una nacionalidad distinta de "Mexicana"
    Entonces puedo continuar sin capturar CURP
    Cuando elijo "Mexicana" como nacionalidad
    Entonces el formulario exige un CURP

  Escenario: El RFC de un Tarjetahabiente admite 13 caracteres, no 12
    Dado que estoy completando el formulario de alta de un Tarjetahabiente
    Cuando capturo un RFC de 13 caracteres
    Entonces el formulario lo acepta como válido

  Escenario: Editar un Tarjetahabiente activo funciona igual que hoy
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Y "Juan Perez" está activo
    Cuando "Carlos" edita el teléfono de "Juan Perez"
    Entonces el cambio se refleja de inmediato en el detalle y en el listado

  Escenario: No se puede editar un Tarjetahabiente inactivo
    Dado que "Juan Perez" está inactivo
    Cuando "Carlos" ve el detalle de "Juan Perez"
    Entonces no ve ningún botón para editarlo

  Escenario: Desactivar un Tarjetahabiente pide confirmación explícita
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Y "Juan Perez" está activo
    Cuando "Carlos" pulsa "Desactivar" sobre "Juan Perez"
    Entonces se le pide confirmar antes de aplicar el cambio

  Escenario: Desactivar un Tarjetahabiente bloquea sus tarjetas activas con el motivo correcto
    Dado que "Juan Perez" está activo y tiene una tarjeta activa
    Cuando se desactiva a "Juan Perez"
    Entonces su tarjeta pasa a estado "Bloqueada"
    Y el motivo de bloqueo registrado es "tarjetahabiente inactivo"

  Escenario: Desactivar un Tarjetahabiente no sobrescribe un bloqueo manual previo
    Dado que "Maria Gomez" tiene una tarjeta bloqueada manualmente por el staff
    Cuando se desactiva a "Maria Gomez"
    Entonces esa tarjeta sigue con motivo de bloqueo "manual", sin cambiar

  Escenario: No se puede asignar una tarjeta nueva a un Tarjetahabiente inactivo
    Dado que "Juan Perez" está inactivo
    Cuando un Admin Cliente intenta asignarle una tarjeta disponible
    Entonces la operación se rechaza

  Escenario: No se puede desbloquear una tarjeta mientras su Tarjetahabiente esté inactivo
    Dado que "Juan Perez" está inactivo y una de sus tarjetas quedó bloqueada por esa razón
    Cuando un Admin Cliente intenta desbloquear esa tarjeta
    Entonces la operación se rechaza

  Escenario: Reactivar un Tarjetahabiente no desbloquea sus tarjetas automáticamente
    Dado que "Juan Perez" está inactivo y tiene una tarjeta bloqueada por esa razón
    Cuando se reactiva a "Juan Perez"
    Entonces esa tarjeta sigue bloqueada
    Pero un Admin Cliente ya puede desbloquearla manualmente si lo decide

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
