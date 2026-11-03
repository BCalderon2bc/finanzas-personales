class GuideStep {
  const GuideStep(this.target, this.title, this.text);
  final String target, title, text;
}

const guideCatalog = <String, List<GuideStep>>{
  'dashboard': [
    GuideStep(
      'menu',
      'Todo comienza en el menú',
      'Desde aquí puedes abrir cuentas, movimientos, tarjetas, deudas y reportes. Al terminar la guía podrás tocar las opciones.',
    ),
    GuideStep(
      'period',
      'Elige qué quieres revisar',
      'Selecciona desde y hasta qué fecha ver tu actividad. La moneda del resumen permite presentar los totales con la tasa configurada; los movimientos conservan su moneda.',
    ),
    GuideStep(
      'metrics',
      'Tu situación financiera',
      'Aquí se reúnen dinero disponible, ingresos, gastos y obligaciones. Una transferencia entre tus cuentas no representa ingreso ni gasto personal.',
    ),
    GuideStep(
      'upcoming',
      'Próximos pagos',
      'Revisa concepto, banco, moneda y vencimiento. Abre el pago correspondiente cuando termines el recorrido.',
    ),
    GuideStep(
      'quick',
      'Abre un módulo',
      'Estos accesos te llevan a las pantallas principales. En cada una encontrarás su propia guía en el botón de ayuda.',
    ),
    GuideStep(
      'help',
      'Siempre puedes volver',
      'Toca ? y elige Guía interactiva para continuar o repetir el recorrido. Leer ayuda conserva las explicaciones completas.',
    ),
  ],
  'accounts': [
    GuideStep(
      'title',
      'Tu dinero por cuenta',
      'Crea una cuenta por banco, efectivo o billetera y respeta la moneda real de cada una.',
    ),
    GuideStep(
      'add',
      'Registrar una cuenta',
      'Este botón abre el formulario. El saldo inicial debe ser lo que tenías antes del primer movimiento que vas a registrar.',
    ),
    GuideStep(
      'wallet',
      'Selecciona una cuenta',
      'Toca una tarjeta para ver sus datos. Los saldos se calculan con apertura, movimientos, transferencias y pagos.',
    ),
    GuideStep(
      'details',
      'Datos y saldo',
      'Aquí puedes revisar y editar la cuenta. Copiar datos bancarios copia las instrucciones para recibir una transferencia; no mueve dinero.',
    ),
    GuideStep(
      'help',
      'Revisar antes de ajustar',
      'Si el saldo no coincide con el banco, revisa apertura y movimientos antes de registrar dinero otra vez. Puedes repetir esta guía desde ?.',
    ),
  ],
  'movements': [
    GuideStep(
      'title',
      'Historial de tu dinero',
      'Aquí aparecen ingresos, gastos, transferencias y pagos de otros módulos, con los últimos ingresados primero.',
    ),
    GuideStep(
      'balances',
      'Saldos separados',
      'Córdobas y dólares se mantienen separados. Estos saldos incluyen las operaciones registradas desde tus cuentas.',
    ),
    GuideStep(
      'filters',
      'Encuentra un registro',
      'Filtra por cuenta, tipo, fechas o texto. La fecha de un movimiento puede ser anterior al día en que lo ingresaste.',
    ),
    GuideStep(
      'add',
      'Nuevo movimiento',
      'Abre este formulario para ingresos, gastos y transferencias. En el formulario también tendrás una guía de sus campos.',
    ),
    GuideStep(
      'help',
      'Editar y conciliar',
      'Toca un movimiento para ver sus acciones. Conciliar lo protege: primero retira la conciliación para editarlo o eliminarlo. Los pagos de otros módulos se gestionan desde su origen.',
    ),
  ],
  'movement_form': [
    GuideStep(
      'type',
      '¿Qué ocurrió?',
      'Ingreso es dinero que recibes; gasto es un consumo; transferencia mueve dinero entre tus propias cuentas. La guía explica: no guardará ninguna operación.',
    ),
    GuideStep(
      'origin',
      'Cuenta de origen',
      'Selecciona la cuenta que recibe el ingreso o desde la que sale el gasto o transferencia. El monto principal usa su moneda.',
    ),
    GuideStep(
      'destination',
      '¿A dónde va?',
      'El destino debe ser otra cuenta tuya. Puedes transferir entre cuentas en córdobas o dólares.',
    ),
    GuideStep(
      'amount',
      'Monto que sale o entra',
      'Escribe un importe positivo y con hasta dos decimales. En una transferencia corresponde a lo que sale de origen.',
    ),
    GuideStep(
      'rate',
      'Revisa la conversión',
      'Escribe córdobas por US\$1. Por ejemplo, US\$10 a tasa 36.50 recibe C\$365.00. Comprueba el monto recibido antes de guardar.',
    ),
    GuideStep(
      'date',
      'Fecha de la operación',
      'Usa la fecha real del movimiento. El historial seguirá mostrando primero los últimos registros ingresados.',
    ),
    GuideStep(
      'save',
      'Revisión final',
      'Al terminar la guía, revisa tipo, cuentas, monto, tasa y fecha. Solo al tocar Guardar registrarás la operación. Las comisiones bancarias se registran como gasto aparte.',
    ),
  ],
  'cards': [
    GuideStep(
      'title',
      'Una tarjeta, dos monedas',
      'Una tarjeta puede tener deuda en córdobas y dólares y un límite compartido. La moneda del límite no cambia la moneda de tus deudas.',
    ),
    GuideStep(
      'add',
      'Agregar tarjeta',
      'Registra el límite y la deuda inicial anterior al historial. No incluyas otra vez compras ya registradas.',
    ),
    GuideStep(
      'wallet',
      'Tu tarjetero',
      'Al entrar se selecciona la primera tarjeta del orden visible. Puedes elegir otra para ver sus detalles.',
    ),
    GuideStep(
      'details',
      'Compras, pagos e historial',
      'Las compras aumentan deuda; pagos y reembolsos la reducen. Desde este panel también puedes abrir tasa cero e historial.',
    ),
    GuideStep(
      'periods',
      'Corte y mínimo',
      'El estado de cuenta tiene moneda, corte, vencimiento, saldo y mínimo propios. Vincular un pago clasifica un pago existente: no debe duplicarlo.',
    ),
    GuideStep(
      'help',
      'Disponible estimado',
      'La tasa del límite sirve para estimar el disponible. En tasa cero usa el modo de registro correcto para no duplicar capital. Cada pantalla tiene ayuda propia.',
    ),
  ],
  'zero': [
    GuideStep(
      'title',
      'Planes tasa cero',
      'Aquí distribuyes una compra en cuotas y controlas lo pendiente sin duplicar la deuda.',
    ),
    GuideStep(
      'explanation',
      'Capital y disponible',
      'El capital pendiente ya forma parte de la deuda según el modo de registro. Las cuotas no vuelven a sumarlo.',
    ),
    GuideStep(
      'add',
      'Registrar el plan',
      'Indica compra, moneda, número de cuotas y las ya pagadas. Compra nueva, incluida y saldo inicial tienen efectos diferentes: lee la explicación del formulario.',
    ),
    GuideStep(
      'voided',
      'Consultar anulados',
      'Este filtro permite revisar planes anulados sin tratarlos como deuda vigente.',
    ),
    GuideStep(
      'help',
      'Aplicar pagos a cuotas',
      'Vincula un pago que ya registraste. No crees otro pago para representar la misma cuota. Si la cuota forma parte del corte, revisa su vínculo con el corte.',
    ),
  ],
  'people': [
    GuideStep(
      'title',
      'Cuentas entre personas',
      'Este módulo lleva una cuenta de compras, pagos y saldos anteriores entre tú y otra persona.',
    ),
    GuideStep(
      'add',
      'Agregar persona',
      'Crea su cuenta para comenzar el historial. No es lo mismo que una cuenta bancaria.',
    ),
    GuideStep(
      'filter',
      'Encuentra la cuenta',
      'Puedes consultar las cuentas activas o archivadas. Abre una persona para ver su saldo y movimientos.',
    ),
    GuideStep(
      'help',
      'Entender el signo',
      'Positivo: tú le debes a esa persona. Negativo: esa persona te debe a ti. El reporte utiliza los nombres para explicar quién paga y quién recibe.',
    ),
  ],
  'person_detail': [
    GuideStep(
      'title',
      'Historial con esta persona',
      'Esta pantalla reúne las operaciones de una sola cuenta con una persona.',
    ),
    GuideStep(
      'balance',
      'Quién debe a quién',
      'El saldo usa las compras y pagos con su signo. Los movimientos en dólares conservan su conversión histórica a córdobas.',
    ),
    GuideStep(
      'add',
      'Registrar una operación',
      'Ingresa compra, pago o saldo anterior y revisa su dirección. No se guardará nada durante la guía.',
    ),
    GuideStep(
      'closures',
      'Cierres acordados',
      'Un cierre guarda una revisión del saldo y protege los movimientos incluidos. Las correcciones posteriores deben respetar ese historial.',
    ),
    GuideStep(
      'help',
      'Exportar y revisar',
      'Desde Exportar puedes generar un estado con nombres, importes con signo y alternativas de pago en córdobas o dólares según la tasa indicada.',
    ),
  ],
  'reports': [
    GuideStep(
      'kind',
      'Elige el reporte',
      'Puedes exportar movimientos, deudas, presupuestos, tarjetas y cuentas con personas. Cada reporte conserva su significado y moneda.',
    ),
    GuideStep(
      'currency',
      'Una o ambas monedas',
      'Elige NIO, USD o ambas. Los totales se presentan separados; no se suman monedas distintas sin una conversión explícita.',
    ),
    GuideStep(
      'person',
      'Cuenta con una persona',
      'Selecciona a la persona y revisa tu nombre. El archivo indicará quién debe pagar y quién recibir.',
    ),
    GuideStep(
      'rate',
      'Alternativas de pago',
      'La tasa de pago convierte el saldo completo a dólares para presentar una alternativa al pago en córdobas. No cambia las tasas históricas.',
    ),
    GuideStep(
      'prepare',
      'Prepara los archivos',
      'Primero genera PDF y Excel. Preparar un reporte no registra pagos ni modifica saldos.',
    ),
    GuideStep(
      'files',
      'Descargar o compartir',
      'Después de prepararlo, estos controles permiten guardar o compartir. En Safari usa HTTPS; si el navegador no admite compartir archivos, usa Descargar.',
    ),
  ],
  'debts': [
    GuideStep(
      'title',
      'Lo que debes',
      'Registra préstamos y obligaciones con instituciones o personas, en su moneda real.',
    ),
    GuideStep(
      'summary',
      'Capital pendiente',
      'Aquí se resume el capital. Las cuotas programadas pueden incluir intereses y no se suman otra vez al capital.',
    ),
    GuideStep(
      'search',
      'Encuentra una deuda',
      'Busca por descripción o acreedor y usa los filtros de estado.',
    ),
    GuideStep(
      'add',
      'Nueva deuda',
      'Al registrar revisa importe, moneda, acreedor y vencimiento. Los abonos distinguen capital, intereses y comisiones.',
    ),
    GuideStep(
      'help',
      'Pagos y cuotas',
      'Gestiona los abonos desde la deuda. Vincular un abono a una cuota clasifica ese abono; no debe crear otra salida de dinero.',
    ),
  ],
  'receivables': [
    GuideStep(
      'title',
      'Dinero que te deben',
      'Este módulo registra préstamos que tú entregaste y sus recuperaciones.',
    ),
    GuideStep(
      'summary',
      'Lo pendiente por cobrar',
      'El capital entregado disminuye con los cobros vigentes. Los intereses cobrados se distinguen del capital recuperado.',
    ),
    GuideStep(
      'search',
      'Busca a la persona',
      'Filtra por persona, descripción o estado para encontrar el préstamo.',
    ),
    GuideStep(
      'add',
      'Registrar dinero prestado',
      'Indica origen y moneda. Si el módulo ya aplica el cobro a tu cuenta, no vuelvas a ingresarlo manualmente.',
    ),
    GuideStep(
      'help',
      'Revisar o corregir',
      'Anular conserva el historial. Eliminar retira el registro bajo las condiciones que muestre la app. La guía no ejecuta ninguna de esas acciones.',
    ),
  ],
  'budgets': [
    GuideStep(
      'title',
      'Planifica tus gastos',
      'Un presupuesto compara gastos de una categoría contra un límite mensual y en una moneda.',
    ),
    GuideStep(
      'month',
      'Mes a revisar',
      'Cambia el mes para consultar sus límites y gastos. No modifica movimientos históricos.',
    ),
    GuideStep(
      'add',
      'Crear un presupuesto',
      'Selecciona categoría, moneda y límite. Crear el presupuesto no retira dinero de tus cuentas.',
    ),
    GuideStep(
      'help',
      'Interpretar el disponible',
      'Disponible es límite menos gasto neto de esa categoría. Las devoluciones reducen el gasto; NIO y USD permanecen separados.',
    ),
  ],
  'settings': [
    GuideStep(
      'title',
      'Configuración de la app',
      'Aquí configuras la tasa general usada en las vistas que combinan monedas.',
    ),
    GuideStep(
      'rate',
      'Córdobas por un dólar',
      'Escribe una tasa positiva. Por ejemplo, 36.50 significa C\$36.50 por US\$1.',
    ),
    GuideStep(
      'save',
      'Guardar la configuración',
      'Guardar cambia esta preferencia. No recalcula las tasas históricas de movimientos que tienen su propia tasa.',
    ),
    GuideStep(
      'help',
      'Tasas de operaciones',
      'Una transferencia o pago entre monedas puede usar la tasa que realmente aplicó tu banco. Compruébala antes de guardar la operación.',
    ),
  ],

  'account_form': [
    GuideStep(
      'name',
      'Identifica la cuenta',
      'Escribe un nombre que te permita distinguir banco y moneda.',
    ),
    GuideStep(
      'currency',
      'Moneda real',
      'Elige la moneda de la cuenta. No uses este campo para convertir su saldo.',
    ),
    GuideStep(
      'opening',
      'Saldo antes del historial',
      'Registra lo que tenías antes del primer movimiento que ingresarás. No sumes otra vez ingresos que ya registraste.',
    ),
    GuideStep(
      'number',
      'Datos para copiar',
      'Número de cuenta, titular e IBAN son datos para compartir instrucciones bancarias. Revisa el formato de tu banco.',
    ),
    GuideStep(
      'save',
      'Guardar solo cuando revises',
      'Al terminar el recorrido revisa los campos y pulsa Guardar. La guía no crea cuentas.',
    ),
  ],
  'card_form': [
    GuideStep(
      'name',
      'Nombre de tu tarjeta',
      'Usa un nombre que distinga banco, producto y tarjeta. Los últimos cuatro dígitos son opcionales.',
    ),
    GuideStep(
      'currency',
      'Moneda del límite',
      'El límite es compartido entre las deudas NIO y USD. Esta moneda solo indica cómo se expresa el límite.',
    ),
    GuideStep(
      'limit',
      'Límite total',
      'Introduce el límite que informa el banco en la moneda elegida.',
    ),
    GuideStep(
      'rate',
      'Disponible estimado',
      'Esta tasa se usa para estimar el uso del límite compartido; no convierte tus deudas.',
    ),
    GuideStep(
      'opening',
      'Deuda previa',
      'Ingresa lo que debías antes del historial, en cada moneda. Los movimientos existentes se suman a estos valores.',
    ),
    GuideStep(
      'save',
      'Revisa antes de guardar',
      'Comprueba límite, tasa, saldos iniciales y fechas de corte y pago. La guía no modifica la tarjeta.',
    ),
  ],
  'person_form': [
    GuideStep(
      'kind',
      'Tipo de operación',
      'Distingue compra, pago y saldo anterior. Cada uno tiene un efecto específico en la cuenta.',
    ),
    GuideStep(
      'direction',
      'Elige quién y el efecto',
      'Positivo: aumenta lo que tú debes. Negativo: aumenta lo que la otra persona te debe. Revisa los nombres del selector.',
    ),
    GuideStep(
      'currency',
      'Moneda original',
      'Selecciona la moneda en la que ocurrió el movimiento.',
    ),
    GuideStep(
      'amount',
      'Importe positivo',
      'Escribe el monto sin signo; el selector de quién/efecto determina si suma o resta.',
    ),
    GuideStep(
      'rate',
      'Conversión histórica',
      'Para USD guarda la tasa de ese movimiento. No se reemplazará por la tasa general al generar reportes.',
    ),
    GuideStep(
      'save',
      'Confirmación final',
      'Revisa quién compró o pagó, moneda, tasa y fecha antes de guardar. La guía no registra movimientos.',
    ),
  ],
  'zero_form': [
    GuideStep(
      'mode',
      'Origen del plan',
      'Compra nueva agrega la compra; YA incluido evita duplicar deuda; NO incluido incorpora solo lo pendiente. Elige según lo que ya existe en la tarjeta.',
    ),
    GuideStep(
      'original_amount',
      'Monto completo de la compra',
      'Indica el valor original, aunque ya hayas pagado algunas cuotas.',
    ),
    GuideStep(
      'total_installments',
      'Cuotas totales',
      'Escribe el número total contratado, incluyendo las cuotas ya pagadas.',
    ),
    GuideStep(
      'historical_paid',
      'Cuotas ya pagadas',
      'Cuenta solo las cuotas completas pagadas antes de registrarlo en la app.',
    ),
    GuideStep(
      'save',
      'Revisar y guardar',
      'Comprueba moneda, importe, cuotas y fechas. Las explicaciones del formulario describen el efecto de esta operación. La guía no guarda ni aplica pagos.',
    ),
  ],

  'statements': [
    GuideStep(
      'title',
      'Cortes y pagos',
      'Cada corte pertenece a una tarjeta, moneda y fecha. No es lo mismo que la deuda actual de la tarjeta.',
    ),
    GuideStep(
      'explanation',
      'Copia lo que dice el banco',
      'Saldo y mínimo deben coincidir con el estado de cuenta. Registrar el corte no vuelve a cargar la deuda.',
    ),
    GuideStep(
      'add',
      'Registrar nuevo corte',
      'Indica moneda, fecha de corte, vencimiento, saldo y mínimo. Luego revisa antes de guardar.',
    ),
    GuideStep(
      'history',
      'Consultar el historial',
      'Activa este filtro para revisar períodos históricos. Los pagos y reversiones vinculados explican lo pendiente.',
    ),
    GuideStep(
      'help',
      'Aplicar un pago o una reversión',
      'Vincular un pago existente no crea otro débito. Una reversión puede bajar saldo y mínimo según lo que aplicó el banco.',
    ),
  ],
  'card_history': [
    GuideStep(
      'title',
      'Historial de la tarjeta',
      'Los últimos registros ingresados aparecen primero, aunque su fecha efectiva sea anterior.',
    ),
    GuideStep(
      'currency',
      'Una moneda a la vez',
      'Puedes consultar córdobas, dólares o ambas. El signo indica si aumenta o reduce la deuda.',
    ),
    GuideStep(
      'state',
      'Vigentes y anulados',
      'Los anulados conservan el historial pero no se consideran deuda vigente.',
    ),
    GuideStep(
      'type',
      'Encuentra el movimiento',
      'Filtra compras, pagos, reembolsos, comisiones o intereses.',
    ),
    GuideStep(
      'help',
      'Corregir un pago',
      'Un pago puede distinguir monto aplicado a la tarjeta y débito bancario. Revisa moneda y tasa al editarlo; sus vínculos pueden limitar cambios.',
    ),
  ],
};
