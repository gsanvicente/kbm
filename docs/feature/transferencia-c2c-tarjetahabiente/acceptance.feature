# language: es
Característica: Transferencia C2C del Tarjetahabiente
  Como Tarjetahabiente
  Quiero transferir saldo directo a la tarjeta de otro Tarjetahabiente de mi misma empresa
  Sin pasar por aprobación de nadie ni tocar la Cuenta Concentradora

  Escenario: Transferencia exitosa a una tarjeta válida del mismo Cliente
    Dado que "Juan Perez" y "Ana Torres" son Tarjetahabientes de "Koons Subsidiaria A"
    Y la tarjeta de "Juan Perez" tiene saldo de 500
    Cuando "Juan Perez" transfiere 100 al número completo de la tarjeta de "Ana Torres"
    Entonces ve una confirmación con el nombre "Ana Torres" antes de enviar
    Y al confirmar, el saldo de "Juan Perez" disminuye en 100
    Y el saldo de "Ana Torres" aumenta en 100
    Y la operación se ejecuta de inmediato, sin pasar por aprobación

  Escenario: Nunca toca la Cuenta Concentradora del Cliente
    Dado que "Juan Perez" transfiere a "Ana Torres" dentro de "Koons Subsidiaria A"
    Cuando la transferencia se ejecuta
    Entonces el saldo de la Cuenta Concentradora de "Koons Subsidiaria A" no cambia

  Escenario: Un número de tarjeta de otro Cliente no resuelve ningún destino
    Dado que "Juan Perez" es Tarjetahabiente de "Koons Subsidiaria A"
    Y "Maria Gomez" tiene una tarjeta en "Koons Subsidiaria B"
    Cuando "Juan Perez" escribe el número completo de la tarjeta de "Maria Gomez"
    Entonces no se encuentra ninguna coincidencia dentro de "Koons Subsidiaria A"
    Y el mensaje de error es el mismo que si el número no existiera en absoluto

  Escenario: Un número con formato inválido da el mismo error genérico
    Dado que "Juan Perez" está en el formulario de transferencia
    Cuando escribe un número que no corresponde a ninguna tarjeta real
    Entonces ve el mismo mensaje de error genérico, sin indicar el motivo específico

  Escenario: Límite de intentos fallidos bloquea intentos repetidos
    Dado que "Juan Perez" ya lleva 4 intentos fallidos en su sesión
    Cuando falla un quinto intento
    Entonces el formulario queda bloqueado hasta que "Juan Perez" vuelva a iniciar sesión

  Escenario: Transferir a otra tarjeta propia tampoco resuelve ningún destino
    Dado que "Sofia Ramirez" tiene dos tarjetas propias
    Cuando escribe el número completo de su otra tarjeta como destino
    Entonces no se encuentra ninguna coincidencia
    Y el mensaje de error es el mismo que si el número no existiera en absoluto

  Escenario: Transferencia con saldo insuficiente falla sin tocar ningún ledger
    Dado que la tarjeta de "Juan Perez" tiene saldo de 50
    Cuando intenta transferir 100 a la tarjeta de "Ana Torres"
    Entonces la operación falla
    Y ni el saldo de "Juan Perez" ni el de "Ana Torres" cambian

  Escenario: El PAN completo nunca queda persistido
    Dado que "Juan Perez" completó una transferencia usando el número completo de una tarjeta
    Cuando se revisa la base de datos y los logs del backend después de la operación
    Entonces no aparece el número completo de la tarjeta en ningún lado, solo el `masked_pan` y el hash
