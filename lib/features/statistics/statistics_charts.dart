import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/money.dart';

const incomeColor = Color(0xFF277354);
const expenseColor = Color(0xFFB14838);
const categoryColors = [
  Color(0xFF2865A2),
  Color(0xFFB14838),
  Color(0xFF277354),
  Color(0xFF7554A3),
  Color(0xFF986416),
  Color(0xFF417885),
];

class StatisticsBars extends StatelessWidget {
  const StatisticsBars({super.key, required this.rows, required this.currency});
  final List<({String label, int cents, Color color})> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final maximum = rows.fold(1, (max, row) => math.max(max, row.cents.abs()));
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(row.label),
                    Text(formatMoneyCents(row.cents, currency)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: row.cents.abs() / maximum,
                  color: row.color,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ExpensePie extends StatelessWidget {
  const ExpensePie({
    super.key,
    required this.categories,
    required this.currency,
  });
  final List<MapEntry<String, int>> categories;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold(0, (sum, entry) => sum + entry.value);
    final items = categories.take(5).toList();
    if (categories.length > 5) {
      items.add(
        MapEntry(
          'Otras categorías',
          categories.skip(5).fold(0, (sum, entry) => sum + entry.value),
        ),
      );
    }
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: Icon(Icons.circle, size: 9, color: categoryColors[i]),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].key),
                      Text(
                        '${formatMoneyCents(items[i].value, currency)} · ${(100 * items[i].value / total).toStringAsFixed(1)} %',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (items.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          legend,
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: 1,
            color: categoryColors.first,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final horizontal = constraints.maxWidth >= 340 * scale;
        final diameter = math.min(
          constraints.maxWidth,
          horizontal ? 112.0 : 128.0,
        );
        final pie = SizedBox.square(
          dimension: diameter,
          child: CustomPaint(
            painter: _PiePainter(
              items.map((entry) => entry.value / total).toList(),
            ),
          ),
        );
        if (horizontal) {
          return Row(
            children: [
              pie,
              const SizedBox(width: 16),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: pie),
            const SizedBox(height: 8),
            legend,
          ],
        );
      },
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.shares);
  final List<double> shares;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = categoryColors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.shares != shares;
}
