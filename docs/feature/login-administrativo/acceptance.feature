# language: es
Característica: Login administrativo
  Como usuario de staff (Super Admin, Admin Cliente, Operador o Auditor)
  Quiero iniciar sesión con mi email y contraseña
  Para acceder a la consola administrativa con mi rol y alcance

  Escenario: Login exitoso con credenciales válidas
    Dado que "admin.subA@koons.test" es un usuario activo con rol "client_admin"
    Cuando inicia sesión con su contraseña correcta
    Entonces obtiene una sesión válida con rol "client_admin"
    Y es redirigido al panel principal

  Escenario: Contraseña incorrecta
    Dado que "admin.subA@koons.test" es un usuario activo
    Cuando intenta iniciar sesión con una contraseña incorrecta
    Entonces la sesión se rechaza
    Y el mensaje de error no indica si el email existe o no

  Escenario: Email inexistente
    Cuando alguien intenta iniciar sesión con un email que no existe
    Entonces la sesión se rechaza
    Y el mensaje de error es igual al de contraseña incorrecta

  Escenario: Usuario inactivo
    Dado que "usuario.inactivo@koons.test" existe pero está marcado como inactivo
    Cuando intenta iniciar sesión con su contraseña correcta
    Entonces la sesión se rechaza
