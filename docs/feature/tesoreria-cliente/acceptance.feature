# language: es
Característica: Tesorería del Cliente (Cuenta Concentradora y Cuenta Colectora)
  Como Operador de Saldos o Admin Cliente
  Quiero registrar y conciliar depósitos hacia la Cuenta Concentradora de mi Cliente
  Para que las Dispersiones tengan una fuente real de fondos

  Escenario: Registrar un depósito lo deja pendiente, sin afectar la Concentradora
    Dado que "Ana" es Operador de "Koons Subsidiaria A"
    Cuando "Ana" registra un depósito de 1000 con referencia "SPEI-001" en la Colectora de "Koons Subsidiaria A"
    Entonces el depósito queda en estado "pending"
    Y el saldo de la Cuenta Concentradora de "Koons Subsidiaria A" no cambia

  Escenario: Conciliar un depósito lo mueve a la Concentradora, tras confirmar
    Dado que existe un depósito en estado "pending" de 1000 en la Colectora de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" pulsa "Conciliar" y confirma el diálogo
    Entonces el depósito queda en estado "reconciled"
    Y el saldo de la Cuenta Concentradora de "Koons Subsidiaria A" aumenta en 1000

  Escenario: Cancelar la confirmación de conciliar no mueve nada
    Dado que existe un depósito en estado "pending" de 1000 en la Colectora de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" pulsa "Conciliar" y cancela el diálogo
    Entonces el depósito sigue en estado "pending"
    Y el saldo de la Cuenta Concentradora de "Koons Subsidiaria A" no cambia

  Escenario: Operador no puede conciliar un depósito
    Dado que existe un depósito en estado "pending" en la Colectora de "Koons Subsidiaria A"
    Y inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Tesorería" de "Koons Subsidiaria A"
    Entonces veo el depósito pendiente pero no el botón "Conciliar"

  Escenario: Auditor solo puede consultar la Tesorería
    Dado que inicié sesión como Auditor
    Cuando veo la pestaña "Tesorería" de un Cliente dentro de mi alcance
    Entonces no veo el botón "Registrar depósito" ni el botón "Conciliar"

  Escenario: Cada Cliente tiene su propia Concentradora y Colectora
    Dado que "Koons Subsidiaria A" y "Koons Subsidiaria B" son Clientes distintos
    Cuando se concilia un depósito en la Colectora de "Koons Subsidiaria A"
    Entonces el saldo de la Cuenta Concentradora de "Koons Subsidiaria B" no cambia

  Escenario: Admin Cliente ve el saldo de su Concentradora en el encabezado
    Dado que "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" inicia sesión
    Entonces el encabezado muestra el saldo de la Cuenta Concentradora de "Koons Subsidiaria A"

  Escenario: Super Admin no ve ningún saldo en el encabezado
    Dado que inicié sesión como Super Admin
    Cuando veo el encabezado
    Entonces no se muestra ningún saldo de Concentradora

  Escenario: Operador y Auditor no ven el indicador de saldo en el encabezado
    Dado que inicié sesión como Operador o como Auditor
    Cuando veo el encabezado
    Entonces no se muestra ningún saldo de Concentradora

  Escenario: Conciliar está disponible tanto desde Tesorería como desde el hub de Operaciones de saldo
    Dado que existe un depósito en estado "pending" de 1000 en la Colectora de "Koons Subsidiaria A"
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" concilia ese depósito desde la pestaña "Tesorería" de "Koons Subsidiaria A"
    Entonces el saldo de la Cuenta Concentradora de "Koons Subsidiaria A" aumenta en 1000
    Y el mismo resultado se obtiene si en cambio lo concilia desde la pestaña
      "Depósitos por conciliar" del hub "Operaciones de saldo"

  Escenario: El hipervínculo del Panel directivo abre directo la pestaña de depósitos
    Dado que "Carlos" es Admin Cliente y ve el Panel directivo ("Inicio")
    Y hay un depósito pendiente listado en "Requiere tu atención"
    Cuando "Carlos" toca ese depósito
    Entonces navega a "Operaciones de saldo" con la pestaña "Depósitos por conciliar" ya seleccionada

  Escenario: No se puede registrar ni conciliar un depósito de un Cliente inactivo
    Dado que "Koons Subsidiaria A" está inactiva
    Cuando alguien con sesión activa intenta registrar o conciliar un depósito de "Koons Subsidiaria A"
    Entonces la acción se rechaza

  # --- Estado de cuenta para directivos (ADR-0022) ---

  Escenario: Admin Cliente ve el Estado de cuenta con una fila por filial
    Dado que "Koons Subsidiaria A" tiene dos filiales
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" ve la pestaña "Tesorería" > "Estado de cuenta"
    Entonces ve una fila de resumen por cada una de las dos filiales, más la suya propia

  Escenario: Expandir una fila del Estado de cuenta muestra el detalle cronológico combinado
    Dado que "Koons Subsidiaria A" tiene un depósito conciliado y una Dispersión en el periodo
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" expande la fila de "Koons Subsidiaria A" en el Estado de cuenta
    Entonces ve ambos movimientos en un solo listado, ordenados por fecha

  Escenario: Operador y Auditor no ven el Estado de cuenta para directivos
    Dado que inicié sesión como Operador de "Koons Subsidiaria A"
    Cuando veo la pestaña "Tesorería" de "Koons Subsidiaria A"
    Entonces no veo la sección "Estado de cuenta"

  Escenario: Descargar el Estado de cuenta exporta exactamente lo que está en pantalla
    Dado que "Carlos" tiene el Estado de cuenta de "Koons Subsidiaria A" filtrado a un rango de fechas
    Cuando "Carlos" pulsa "Descargar"
    Entonces el PDF contiene solo los movimientos de ese rango, no el historial completo
    Y el PDF muestra el branding de KBM/Koons, el nombre del Cliente y quién lo generó

  Escenario: Un Tarjetahabiente puede descargar su propio estado de cuenta
    Dado que "Juan" tiene movimientos en su Cuenta Individual
    Cuando "Juan" pulsa "Descargar estado de cuenta" en su portal
    Entonces recibe un PDF con sus movimientos, su nombre y su CLABE completa

  Escenario: Staff puede descargar el estado de cuenta de un Tarjetahabiente sin ninguna tarjeta asignada
    Dado que "Ana" no tiene ninguna tarjeta asignada pero sí tiene un depósito SPEI
    Y "Carlos" es Admin Cliente de "Koons Subsidiaria A"
    Cuando "Carlos" ve la ficha de "Ana" y pulsa "Descargar estado de cuenta"
    Entonces recibe un PDF con el depósito de "Ana" y "Generado por" muestra el email de "Carlos"
