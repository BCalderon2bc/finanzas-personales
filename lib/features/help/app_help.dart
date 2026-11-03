import 'package:flutter/material.dart';
import 'interactive_guide.dart';
import 'guide_destinations.dart';
export 'interactive_guide.dart';

const appHelp = <String, (String, String)>{
  'start': (
    'Primeros pasos',
    '1. Crea tus cuentas en la moneda real de cada una.\n2. Registra el saldo que tenían antes del historial que comenzarás a ingresar.\n3. Agrega ingresos, gastos y transferencias.\n4. Registra tarjetas y deudas existentes con sus saldos iniciales.\n5. Comprueba los saldos contra el banco. No registres dos veces el mismo pago o compra.\n\nCórdobas y dólares se mantienen separados; una tasa solo convierte cuando la operación lo requiere.',
  ),
  'accounts': (
    'Cuentas y efectivo',
    'Cada cuenta representa dinero en un banco, efectivo o billetera. El saldo es saldo inicial más entradas, menos salidas y pagos realizados desde esa cuenta.\n\nIngresa como saldo inicial lo que tenías antes del primer movimiento registrado. Un ingreso posterior sí se registra en Movimientos.\n\nLos datos para copiar una cuenta sirven para compartir instrucciones bancarias. Revisa titular, número, IBAN y moneda antes de enviarlos.',
  ),
  'movements': (
    'Ingresos, gastos y transferencias',
    'Ingreso: dinero que recibes. Gasto: dinero que sale por un consumo. Transferencia: dinero que mueves entre tus propias cuentas; no cuenta como ingreso ni gasto personal.\n\nSelecciona origen y destino. Si son de monedas diferentes, escribe la tasa en córdobas por US\$1.\nEjemplo: US\$100 a tasa 36.50 recibe C\$3,650.00. C\$365.00 a tasa 36.50 recibe US\$10.00. El importe recibido se redondea a dos decimales.\n\nComprueba el resumen antes de guardar. Las comisiones del banco se registran como gasto aparte.\n\nConciliar significa que verificaste el movimiento contra el banco; quita la conciliación antes de editar o eliminar.',
  ),
  'cards': (
    'Tarjetas de crédito',
    'Una tarjeta puede tener deuda en córdobas y dólares y un único límite compartido. La tasa del límite estima el disponible; no convierte tus deudas.\n\nLas compras, intereses y comisiones aumentan deuda; pagos y reembolsos la reducen. Un pago puede salir de una cuenta en otra moneda usando su tasa.\n\nDeuda inicial: lo que debías antes del historial registrado. No incluyas otra vez compras que ya registraste. El saldo a favor se muestra como deuda negativa.\n\nEl corte y el mínimo son obligaciones del estado de cuenta. No confundas saldo actual, pago de contado y mínimo pendiente.',
  ),
  'zero': (
    'Planes tasa cero',
    'Registra monto original, número de cuotas, moneda y cuotas ya pagadas.\n\nCompra nueva: genera la compra completa. Compra ya incluida: describe cuotas de una deuda que ya está registrada. Saldo inicial: incorpora lo pendiente al saldo de apertura. Elige el modo que corresponda para no duplicar deuda.\n\nVincular un pago a una cuota clasifica un pago existente; no vuelve a descontarlo de tu cuenta. Al anular un pago, su cuota vuelve a quedar pendiente según sus vínculos vigentes.',
  ),
  'statements': (
    'Cortes, mínimos y reversiones',
    'Registra lo que indica el estado de cuenta: moneda, corte, vencimiento, saldo y mínimo. Vincula los pagos al corte correspondiente.\n\nUna reversión de anualidad o comisión se registra como reembolso. Si el banco también redujo el mínimo, clasifica el crédito en el corte e indica cuánto disminuye el saldo y cuánto el mínimo. No registres otro pago para representar la misma reversión.',
  ),
  'debts': (
    'Deudas y préstamos',
    'Este módulo registra dinero que debes a una institución o persona. Distingue capital, intereses y comisiones de cada abono.\n\nLas cuotas son pagos programados. Vincular un abono a una cuota no debe crear otro egreso. Revisa moneda, cuenta de salida y fecha antes de confirmar. El saldo de capital y el total de cuotas pueden diferir por intereses.',
  ),
  'receivables': (
    'Préstamos por cobrar',
    'Aquí registras dinero que prestaste y que te deben devolver. Indica persona, monto, moneda y origen del dinero.\n\nUn cobro recupera dinero prestado; no debe duplicarse como un ingreso manual si el módulo ya lo aplica a tu cuenta. Anular conserva el historial; eliminar retira el registro según las condiciones que indique la pantalla.',
  ),
  'people': (
    'Cuentas con personas',
    'Registra compras, pagos y saldos anteriores entre tú y otra persona.\n\nSaldo positivo: tú le debes a esa persona. Saldo negativo: esa persona te debe a ti. El reporte utiliza ambos nombres para indicar quién paga y quién recibe.\n\nLos movimientos en dólares conservan su tasa registrada; el saldo neto del módulo se expresa en córdobas. Un cierre conserva una revisión del historial; los movimientos incluidos quedan protegidos. Las correcciones posteriores se registran después del cierre.',
  ),
  'budgets': (
    'Presupuestos y categorías',
    'Un presupuesto limita gastos de una categoría durante un mes y en una moneda. Las categorías ayudan a ordenar ingresos y gastos.\n\nCompara gasto neto con límite. Las devoluciones reducen el gasto correspondiente. Los dólares y córdobas se comparan por separado. Crear un presupuesto no mueve dinero de tus cuentas.',
  ),
  'reports': (
    'Reportes, descargar y compartir',
    'Elige tipo, moneda y fechas; luego pulsa Preparar reportes. Después puedes Descargar o Compartir el PDF y el Excel.\n\nCrédito: muestra deuda por tarjeta, con compras, pagos y reembolsos. Débito: muestra los movimientos de la cuenta vinculada; no identifica qué tarjeta física se usó. Si varias tarjetas apuntan a la misma cuenta, el total se cuenta una sola vez.\n\nLos reportes conservan la moneda original. En cuentas con personas, los importes tienen signo y Total suma/resta en córdobas. El recuadro indica alternativas de pago en córdobas o dólares usando la tasa que elijas. En tarjetas, Saldo incluye apertura y movimientos anteriores al período.\n\nPara compartir en iPhone, abre la web en Safari mediante HTTPS y pulsa Compartir después de preparar el archivo. Si el navegador no admite compartir archivos, descárgalo y compártelo desde Archivos. Cancelar la hoja de compartir no envía nada.',
  ),
  'settings': (
    'Configuración y tasas',
    'La tasa se expresa en córdobas por un dólar. Usa la tasa aplicada por el banco cuando transfieres o pagas entre monedas.\n\nCambiar la tasa general no debe recalcular movimientos históricos que tienen una tasa guardada. La tasa del límite de una tarjeta es solo una estimación del disponible.',
  ),
  'dashboard': (
    'Resumen principal',
    'El resumen reúne cuentas, deudas y actividad del período seleccionado. Los próximos pagos muestran su concepto y banco cuando están registrados.\n\nUna transferencia entre tus cuentas no aumenta ingresos ni gastos personales. Los pagos de tarjetas reducen dinero y deuda; la compra es la que representa el consumo.\n\nSi un saldo no coincide, actualiza la pantalla y revisa apertura, fecha, moneda, anulaciones y pagos vinculados antes de crear un ajuste o repetir un movimiento.',
  ),
};

class AppHelpButton extends StatelessWidget {
  const AppHelpButton({super.key, required this.topic});
  final String topic;
  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.maybeOf(context);
    return GuideAnchor(
      id: 'help',
      child: IconButton(
        tooltip: 'Ayuda y guía interactiva',
        icon: const Icon(Icons.help_outline),
        onPressed: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scope != null)
                    ListTile(
                      leading: const Icon(Icons.explore_outlined),
                      title: const Text('Guía interactiva'),
                      subtitle: const Text(
                        'Continuar el recorrido paso a paso',
                      ),
                      onTap: () => Navigator.pop(ctx, 'guide'),
                    ),
                  if (scope != null)
                    ListTile(
                      leading: const Icon(Icons.replay),
                      title: const Text('Repetir guía desde el inicio'),
                      onTap: () => Navigator.pop(ctx, 'restart'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Leer ayuda de esta pantalla'),
                    onTap: () => Navigator.pop(ctx, 'read'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Manual y todas las guías'),
                    onTap: () => Navigator.pop(ctx, 'manual'),
                  ),
                ],
              ),
            ),
          );
          if (!context.mounted) return;
          if (action == 'guide' || action == 'restart') {
            await scope?.start(restart: action == 'restart');
          }
          if (action == 'manual')
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AppManualPage(initialTopic: topic),
              ),
            );
          if (action == 'read') {
            final item = appHelp[topic] ?? appHelp['start']!;
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(item.$1),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      item.$2,
                      key: PageStorageKey('help-dialog-text-$topic'),
                    ),
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class AppManualPage extends StatefulWidget {
  const AppManualPage({super.key, this.initialTopic});
  final String? initialTopic;
  @override
  State<AppManualPage> createState() => _AppManualPageState();
}

class _AppManualPageState extends State<AppManualPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manual de Mi Billete')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          key: const PageStorageKey('mi-billete-manual-scroll-v2'),
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Manual y guías interactivas · aprende con tu app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            for (final entry in appHelp.entries)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey(entry.key),
                  initiallyExpanded:
                      entry.key == (widget.initialTopic ?? 'start'),
                  title: Text(entry.value.$1),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      // EditableText guarda su desplazamiento como double.
                      // Su clave debe ser distinta de la expansión (bool).
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(
                            entry.value.$2,
                            key: PageStorageKey('manual-text-${entry.key}'),
                          ),
                          if (hasGuideDestination(entry.key)) ...[
                            const SizedBox(height: 12),
                            FutureBuilder<bool>(
                              future: GuideProgress(
                                guideUserId(),
                              ).completed(entry.key),
                              builder: (_, snapshot) => Text(
                                snapshot.data == true
                                    ? 'Guía completada · puedes repetirla'
                                    : 'Guía disponible',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await openGuideDestination(context, entry.key);
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.explore_outlined),
                              label: const Text(
                                'Abrir pantalla e iniciar guía',
                              ),
                            ),
                          ],
                          if (entry.key == 'zero')
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Para su guía: abre una tarjeta → Planes tasa cero → ? → Guía interactiva.',
                              ),
                            ),
                          if (entry.key == 'people')
                            const Text(
                              'Cada cuenta con una persona también tiene su propio recorrido en el botón ?.',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
