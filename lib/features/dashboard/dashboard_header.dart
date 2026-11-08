import 'package:flutter/material.dart';

import '../../widgets/adaptive_layout.dart';
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget dateButton(String title, DateTime date, VoidCallback onTap) =>
        OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            minimumSize: const Size(0, 44),
          ),
          child: Text(
            '$title · ${DashboardPeriod.dateLabel(date)}',
            textAlign: TextAlign.center,
          ),
        );

    final dates = AdaptiveColumns(
      minColumnWidth: 130,
      spacing: 8,
      children: [
        dateButton('Desde', period.start, onFrom),
        dateButton('Hasta', period.end, onUntil),
      ],
    );
    final options = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'NIO', label: Text('Córdobas')),
            ButtonSegment(value: 'USD', label: Text('Dólares')),
          ],
          selected: {currency},
          onSelectionChanged: (values) => onCurrencyChanged(values.first),
        ),
        TextButton(
          onPressed: loading ? null : onCurrent,
          child: const Text('Mes actual'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            if (constraints.maxWidth >= 740 * scale.clamp(1, 1.6)) {
              return Row(
                children: [
                  SizedBox(width: 340.0 * scale.clamp(1.0, 1.6), child: dates),
                  const SizedBox(width: 12),
                  Expanded(child: options),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [dates, const SizedBox(height: 4), options],
            );
          },
        ),
        Text(
          'Comparación: ${period.previous.label}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
