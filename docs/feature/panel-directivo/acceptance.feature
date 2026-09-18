# language: es
Característica: Panel directivo ("Inicio")
  Como Super Admin o Admin Cliente
  Quiero ver un resumen ejecutivo de saldos, pendientes y actividad al iniciar sesión
  Para saber cómo está mi empresa (o todas) sin entrar Cliente por Cliente

  Escenario: Super Admin ve cifras agregadas de todas las empresas
    Dado que inicié sesión como Super Admin
    Cuando entro al panel directivo ("Inicio")
    Entonces el saldo de Concentradoras mostrado es la suma de todos los Clientes
    Y el saldo cargado en tarjetas mostrado es la suma de todas las tarjetas

  Escenario: Admin Cliente con filiales ve un desglose por empresa
    Dado que inicié sesión como Admin Cliente de "Grupo Koons Holding"
    Y "Koons Subsidiaria A" y "Koons Subsidiaria B" son hijas de "Grupo Koons Holding"
    Cuando entro al panel directivo
    Entonces veo la sección "Desglose por empresa"
    Y veo una fila por cada una de las tres empresas

  Escenario: Admin Cliente sin filiales no ve la sección de desglose
    Dado que inicié sesión como Admin Cliente de "Koons Subsidiaria A"
    Y "Koons Subsidiaria A" no tiene empresas hijas
    Cuando entro al panel directivo
    Entonces no veo la sección "Desglose por empresa"
    Y las cifras mostradas corresponden solo a "Koons Subsidiaria A"

  Escenario: Operador y Auditor no tienen acceso al panel directivo
    Dado que inicié sesión como Operador o como Auditor
    Entonces no veo "Inicio" en el menú lateral
    Y sigo aterrizando en la sección "Clientes" al iniciar sesión

  Escenario: Una operación pendiente de aprobación aparece en "Requiere tu atención"
    Dado que existe una operación de saldo pendiente de aprobación en mi alcance
    Cuando entro al panel directivo
    Entonces la veo listada en "Requiere tu atención"
    Y al tocarla navego a la sección "Operaciones de saldo", pestaña "Pendientes de aprobación"

  Escenario: Un depósito pendiente de conciliar aparece en "Requiere tu atención" y navega al hub
    Dado que existe un depósito pendiente en la Colectora de un Cliente en mi alcance
    Cuando entro al panel directivo
    Entonces lo veo listado en "Requiere tu atención"
    Y al tocarlo navego a la sección "Operaciones de saldo" con la pestaña
      "Depósitos por conciliar" ya seleccionada

  Escenario: La gráfica de volumen deja claro que es un dato ilustrativo
    Dado que inicié sesión como Admin Cliente
    Cuando entro al panel directivo
    Entonces veo la gráfica "Volumen de operaciones — últimas 12 semanas"
    Y veo un aviso de que es un dato ilustrativo, no transacciones reales
