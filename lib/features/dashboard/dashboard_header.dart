import 'package:flutter/material.dart';
import 'dashboard_period.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.period,
    required this.currency,
    required this.loading,
    required this.onFrom,
    required this.onUntil,
    required this.onCurrent,
    required this.onCurrencyChanged,
  });
  final DashboardPeriod period;
  final String currency;
  final bool loading;
  final VoidCallback onFrom, onUntil, onCurrent;
  final ValueChanged<String> onCurrencyChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          Widget field(String label, DateTime value, VoidCallback onTap) =>
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: loading ? null : onTap,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 12)),
                          Text(
                            DashboardPeriod.dateLabel(value),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          final from = field('Desde', period.start, onFrom),
              until = field('Hasta', period.end, onUntil);
          return box.maxWidth < 350
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [from, const SizedBox(height: 10), until],
                )
              : Row(
                  children: [
                    Expanded(child: from),
                    const SizedBox(width: 10),
                    Expanded(child: until),
                  ],
                );
        },
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'NIO', label: Text('Córdobas')),
              ButtonSegment(value: 'USD', label: Text('Dólares')),
            ],
            selected: {currency},
            onSelectionChanged: (s) => onCurrencyChanged(s.first),
          ),
          TextButton.icon(
            onPressed: loading ? null : onCurrent,
            icon: const Icon(Icons.today_outlined),
            label: const Text('Mes actual'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Ingresos, gastos y actividad del rango seleccionado. Saldos, deudas y próximos pagos corresponden a los registros vigentes.',
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
      ),
      const SizedBox(height: 5),
      Text(
        'Comparación: ${period.previous.label}${period.isFullMonth ? ' · mes anterior' : ' · ${period.days} días anteriores'}.',
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
    ],
  );
}
