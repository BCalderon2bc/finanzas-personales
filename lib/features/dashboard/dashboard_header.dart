import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key, required this.monthLabel, required this.currency,
    required this.loading, required this.onPrevious, required this.onNext,
    required this.onCurrent, required this.onCurrencyChanged,
  });
  final String monthLabel, currency;
  final bool loading;
  final VoidCallback onPrevious, onNext, onCurrent;
  final ValueChanged<String> onCurrencyChanged;

  String get greeting {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      Wrap(spacing: 12, runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Mes anterior',
                    onPressed: loading ? null : onPrevious,
                    icon: const Icon(Icons.chevron_left_rounded)),
                SizedBox(width: 136, child: Text(monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(tooltip: 'Mes siguiente',
                    onPressed: loading ? null : onNext,
                    icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'NIO', label: Text('Córdobas')),
                ButtonSegment(value: 'USD', label: Text('Dólares')),
              ],
              selected: {currency},
              onSelectionChanged: (selection) => onCurrencyChanged(selection.first),
            ),
            TextButton.icon(
              onPressed: loading ? null : onCurrent,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Mes actual'),
            ),
          ]),
      const SizedBox(height: 14),
      const Text(
        'Ingresos, gastos y presupuestos del mes seleccionado. Saldos y deudas según los registros vigentes.',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5),
      ),
    ],
  );
}