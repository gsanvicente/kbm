# language: es
Característica: Activación de cuenta del Tarjetahabiente
  Como Tarjetahabiente recién dado de alta
  Quiero crear mis propias credenciales de acceso sin depender del staff
  Para poder usar el portal de autoservicio por primera vez

  Escenario: Activación exitosa con los datos correctos
    Dado que el staff dio de alta a "Juan Perez" con su email y su número de identificación
    Y "Juan Perez" todavía no tiene una cuenta activada
    Cuando captura su email, su número de identificación y una nueva contraseña de al menos 8 caracteres
    Entonces su cuenta queda activada y entra directo a su portal

  Escenario: Email correcto pero número de identificación incorrecto
    Dado que "Juan Perez" todavía no tiene una cuenta activada
    Cuando captura su email correcto pero un número de identificación equivocado
    Entonces ve el mismo mensaje genérico que si el email no existiera

  Escenario: Un Tarjetahabiente inactivo no puede activar su cuenta
    Dado que "Carlos Ruiz" está desactivado
    Cuando intenta activar su cuenta con sus datos correctos
    Entonces ve el mismo mensaje genérico, sin que se revele que está inactivo

  Escenario: No se puede activar una cuenta ya activada
    Dado que "Ana Torres" ya activó su cuenta anteriormente
    Cuando alguien intenta activarla de nuevo con sus datos correctos
    Entonces ve el mismo mensaje genérico, sin que se revele que ya existía

  Escenario: Cinco intentos fallidos bloquean la activación
    Dado que alguien intentó activar la cuenta de "Juan Perez" con datos incorrectos 5 veces seguidas
    Cuando lo intenta una sexta vez, esta vez con los datos correctos
    Entonces sigue viendo el mismo mensaje genérico, sin poder activar la cuenta

  Escenario: Un Admin Cliente reinicia los intentos de un Tarjetahabiente bloqueado
    Dado que la activación de "Juan Perez" está bloqueada por intentos fallidos
    Y inicié sesión como Admin Cliente de su mismo Cliente
    Cuando pulso "Reiniciar intentos de activación" en su detalle
    Entonces "Juan Perez" puede volver a intentar activar su cuenta

  Escenario: La activación está disponible tanto en web como en mobile
    Dado que "Juan Perez" todavía no tiene una cuenta activada
    Cuando entra a `cardholder/` desde un navegador o desde la app móvil
    Entonces ve el mismo enlace "¿Nuevo? Activa tu cuenta" en ambos
