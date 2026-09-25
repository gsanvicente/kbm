# language: es
Característica: Reportes de staff — Pagos SPEI, Depósitos y Beneficiarios de Pago
  Como Admin Cliente, Operador o Auditor
  Quiero consultar el historial de SPEI y los Beneficiarios de Pago de mis Tarjetahabientes
  Para dar soporte y revisar cumplimiento (PLD/AML) sin depender de que el Tarjetahabiente me lo muestre

  Escenario: Cualquier rol de staff ve el historial completo de Pagos SPEI dentro de su alcance
    Dado que "Juan" (Tarjetahabiente de "Koons Subsidiaria A") tiene un pago SPEI "executed" y otro "rejected"
    Y inicié sesión como Auditor de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Entonces veo ambos pagos de "Juan", cualquiera que sea su estatus

  Escenario: El historial de Pagos SPEI nunca muestra pagos de otro Cliente fuera de alcance
    Dado que "Juan" es de "Koons Subsidiaria A" y "Maria" es de "Koons Subsidiaria B"
    Y "Maria" tiene un pago SPEI "executed"
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A", sin descendientes
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Entonces no veo el pago de "Maria"

  Escenario: Depósitos SPEI se ven agregados, sin concepto de estatus pendiente
    Dado que "Juan" recibió dos depósitos SPEI
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Depósitos SPEI"
    Entonces veo ambos depósitos con su referencia del proveedor

  Escenario: Beneficiarios muestra la CLABE enmascarada por default
    Dado que "Juan" registró un Beneficiario "Mamá" con una CLABE válida
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Beneficiarios"
    Entonces veo a "Mamá" en la lista con su CLABE enmascarada
    Y no veo ningún botón "Revelar CLABE completa"

  Escenario: Solo Admin Cliente o Super Admin pueden revelar la CLABE completa
    Dado que "Juan" registró un Beneficiario "Mamá"
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la fila de "Mamá" en "Reportes" > "Beneficiarios"
    Y pulso "Revelar CLABE completa"
    Entonces veo la CLABE completa de "Mamá"
    Y queda una entrada en el registro de auditoría por esa revelación

  Escenario: La actividad de un Beneficiario cuenta solo pagos ejecutados
    Dado que "Juan" le hizo a "Mamá" un pago "executed" de 500 y otro "rejected" de 2000
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la fila de "Mamá" en "Reportes" > "Beneficiarios"
    Entonces el monto total mostrado es 500, no 2500
    Y el conteo de pagos mostrado es 1, no 2

  Escenario: La misma CLABE registrada por dos Tarjetahabientes distintos activa la alerta
    Dado que "Juan" (de "Koons Subsidiaria A") registró la CLABE "072180000118359719" como Beneficiario
    Y "Carlos" (de "Koons Subsidiaria B") registró esa misma CLABE como Beneficiario, por separado
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la fila del Beneficiario de "Juan" en "Reportes" > "Beneficiarios"
    Entonces veo el ícono de alerta de CLABE compartida
    Pero no veo ningún dato de "Carlos" ni de "Koons Subsidiaria B" en esa fila

  Escenario: Operador y Auditor nunca ven la pestaña de Tesorería para directivos
    Dado que inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la ficha de "Koons Subsidiaria A" > pestaña "Tesorería"
    Entonces no veo la sección "Estado de cuenta" con resumen por filial

  Escenario: No se puede registrar ni editar un Beneficiario desde admin/
    Dado que inicié sesión como Super Admin
    Cuando veo la pestaña "Reportes" > "Beneficiarios"
    Entonces no veo ningún botón para agregar, editar o eliminar un Beneficiario

  Escenario: Filtrar Pagos SPEI por Cliente narrows la lista a esa filial
    Dado que "Juan" es de "Koons Subsidiaria A" y "Maria" es de "Koons Subsidiaria B"
    Y ambos tienen pagos SPEI "executed"
    Y inicié sesión como Super Admin
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Y filtro por Cliente "Koons Subsidiaria A"
    Entonces veo el pago de "Juan" pero no el de "Maria"

  Escenario: Filtrar Beneficiarios por "Solo con alerta activa" oculta a los que no comparten CLABE
    Dado que "Mamá" comparte su CLABE con otro Tarjetahabiente y "Casero" no
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Beneficiarios"
    Y activo el chip "Solo con alerta activa"
    Entonces veo a "Mamá" pero no a "Casero"

  Escenario: Buscar por Tarjetahabiente en Beneficiarios filtra por nombre
    Dado que "Juan" y "Ana" registraron cada uno un Beneficiario distinto
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Beneficiarios"
    Y escribo "Juan" en "Buscar Tarjetahabiente"
    Entonces veo solo el Beneficiario registrado por "Juan"

  Escenario: Buscar por beneficiario en Pagos SPEI filtra por alias
    Dado que "Juan" tiene un pago a "Mamá" y otro a "Casero"
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Y escribo "Mamá" en "Buscar beneficiario"
    Entonces veo solo el pago hecho a "Mamá"

  Escenario: Pagos SPEI muestra la CLABE enmascarada, a diferencia de la cola de Aprobaciones
    Dado que "Juan" tiene un pago SPEI "executed" a "Mamá"
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Entonces veo la CLABE de "Mamá" enmascarada
    Pero cuando veo la cola "Aprobaciones" > "Pagos SPEI" para un pago pendiente
    Entonces ahí sí veo la CLABE completa

  Escenario: Descargar Pagos SPEI exporta exactamente la lista filtrada, con branding y CLABE enmascarada
    Dado que "Juan" es de "Koons Subsidiaria A" y "Maria" es de "Koons Subsidiaria B"
    Y ambos tienen pagos SPEI "executed"
    Y inicié sesión como Super Admin
    Cuando veo la pestaña "Reportes" > "Pagos SPEI"
    Y filtro por Cliente "Koons Subsidiaria A"
    Y pulso "Descargar"
    Entonces el PDF contiene solo el pago de "Juan", no el de "Maria"
    Y el PDF muestra el branding de KBM/Koons, quién lo generó, y los filtros activos
    Y la CLABE en el PDF está enmascarada

  Escenario: Descargar Beneficiarios respeta qué filas ya se revelaron en pantalla
    Dado que "Mamá" y "Casero" son Beneficiarios de "Juan"
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Y ya revelé la CLABE completa de "Mamá" en la pestaña "Beneficiarios"
    Cuando pulso "Descargar"
    Entonces el PDF muestra la CLABE completa de "Mamá" pero la de "Casero" sigue enmascarada

  Escenario: Staff descarga los Movimientos de una tarjeta individual desde el detalle de esa tarjeta
    Dado que la tarjeta "**** **** **** 1234" de "Juan" tiene movimientos
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Movimientos" de esa tarjeta
    Y pulso "Descargar"
    Entonces recibo un PDF que identifica la tarjeta y a "Juan", no toda su Cuenta Individual

  Escenario: Reportes > Movimientos permite buscar un Tarjetahabiente y descargar su Cuenta Individual sin navegar hasta él
    Dado que "Juan" es Tarjetahabiente de "Koons Subsidiaria A" y tiene movimientos en su Cuenta Individual
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Movimientos"
    Y el alcance seleccionado es "Tarjetahabiente"
    Y busco y selecciono a "Juan"
    Entonces veo el saldo y los movimientos de su Cuenta Individual, y puedo pulsar "Descargar"

  Escenario: Reportes > Movimientos permite ver los movimientos de una tarjeta puntual de ese Tarjetahabiente
    Dado que "Juan" tiene dos tarjetas, cada una con sus propios movimientos
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Movimientos", busco y selecciono a "Juan"
    Y expando una de sus tarjetas en "Ver por tarjeta"
    Entonces veo solo los movimientos de esa tarjeta, no los de su Cuenta Individual completa ni los de su otra tarjeta

  Escenario: Reportes > Movimientos permite buscar un Cliente y descargar su Estado de cuenta sin navegar hasta él
    Dado que "Koons Subsidiaria A" tiene movimientos en su Cuenta Concentradora
    Y inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la pestaña "Reportes" > "Movimientos"
    Y cambio el alcance seleccionado a "Cliente (Concentradora)"
    Y busco y selecciono "Koons Subsidiaria A"
    Entonces veo el saldo y los movimientos de su Cuenta Concentradora, y puedo pulsar "Descargar"

  Escenario: Los botones de descarga en el detalle de cada entidad siguen funcionando igual
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Cuando veo la ficha de un Tarjetahabiente y pulso "Descargar estado de cuenta"
    Entonces recibo el mismo PDF que si lo hubiera descargado desde "Reportes" > "Movimientos"
