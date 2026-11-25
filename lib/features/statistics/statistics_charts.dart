import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../core/app_theme.dart' show primaryColor;


enum ChartGrouping { days, weeks, months, years }

String chartGroupingLabel(ChartGrouping value) => switch (value) {
  ChartGrouping.days => 'Días',
  ChartGrouping.weeks => 'Semanas',
  ChartGrouping.months => 'Meses',
  ChartGrouping.years => 'Años',
};

class ChartGroupingSelector extends StatelessWidget {
  const ChartGroupingSelector({super.key, required this.value, required this.onChanged});
  final ChartGrouping value;
  final ValueChanged<ChartGrouping> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 360) {
        return DropdownButtonFormField<ChartGrouping>(
          value: value,
          decoration: const InputDecoration(labelText: 'Agrupar por', border: OutlineInputBorder(), isDense: true),
          items: ChartGrouping.values.map((v) => DropdownMenuItem(value: v, child: Text(chartGroupingLabel(v)))).toList(),
          onChanged: (next) { if (next != null) onChanged(next); },
        );
      }
      return SegmentedButton<ChartGrouping>(
        segments: ChartGrouping.values.map((v) => ButtonSegment(value: v, label: Text(chartGroupingLabel(v)))).toList(),
        selected: {value}, showSelectedIcon: false,
        onSelectionChanged: (selection) => onChanged(selection.first),
      );
    },
  );
}

List<({String label, int cents})> buildChartBuckets(
  DateTime start, DateTime end, ChartGrouping grouping,
  int Function(DateTime start, DateTime end) total,
) {
  final result = <({String label, int cents})>[];
  DateTime cursor;
  switch (grouping) {
    case ChartGrouping.days: cursor = DateUtils.dateOnly(start); break;
    case ChartGrouping.weeks:
      final day = DateUtils.dateOnly(start);
      cursor = day.subtract(Duration(days: day.weekday - DateTime.monday)); break;
    case ChartGrouping.months: cursor = DateTime(start.year, start.month); break;
    case ChartGrouping.years: cursor = DateTime(start.year); break;
  }
  while (!cursor.isAfter(end)) {
    late DateTime bucketEnd;
    late DateTime next;
    late String label;
    switch (grouping) {
      case ChartGrouping.days:
        bucketEnd = cursor; next = cursor.add(const Duration(days: 1));
        label = '${cursor.day}/${cursor.month}'; break;
      case ChartGrouping.weeks:
        bucketEnd = cursor.add(const Duration(days: 6)); next = cursor.add(const Duration(days: 7));
        label = '${cursor.day}/${cursor.month}'; break;
      case ChartGrouping.months:
        bucketEnd = DateTime(cursor.year, cursor.month + 1, 0); next = DateTime(cursor.year, cursor.month + 1);
        const names = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
        label = names[cursor.month - 1]; break;
      case ChartGrouping.years:
        bucketEnd = DateTime(cursor.year, 12, 31); next = DateTime(cursor.year + 1);
        label = '${cursor.year}'; break;
    }
    final from = cursor.isBefore(start) ? start : cursor;
    final to = bucketEnd.isAfter(end) ? end : bucketEnd;
    result.add((label: label, cents: total(from, to)));
    cursor = next;
  }
  return result;
}

const incomeColor = Color(0xFF277354);
const expenseColor = Color(0xFFB14838);
List<Color> get categoryColors => [
  primaryColor,
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

/// Gráfico mensual de barras para comparar la evolución de un importe.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.title,
    required this.values,
    required this.currency,
    required this.color,
    this.detail,
  });

  final String title;
  final List<({String label, int cents})> values;
  final String currency;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = values.any((value) => value.cents != 0);
    final positiveValues = values.where((value) => value.cents > 0).toList();
    final peak = positiveValues.isEmpty
        ? null
        : positiveValues.reduce((a, b) => a.cents >= b.cents ? a : b);
    final latest = values.isEmpty ? null : values.last;
    final average = values.isEmpty
        ? 0
        : (values.fold<int>(0, (sum, value) => sum + value.cents) /
                  values.length)
              .round();
    final theme = Theme.of(context);

    Widget metric(String label, String value, {String? caption}) =>
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 125, maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(110),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withAlpha(100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 3),
                        Text(detail!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                metric(
                  'Último período',
                  latest == null
                      ? '—'
                      : formatMoneyCents(latest.cents, currency),
                  caption: latest?.label,
                ),
                metric(
                  'Promedio por período',
                  formatMoneyCents(average, currency),
                  caption: 'En el período seleccionado',
                ),
                metric(
                  'Mayor valor',
                  peak == null
                      ? formatMoneyCents(0, currency)
                      : formatMoneyCents(peak.cents, currency),
                  caption: peak == null ? 'Sin actividad' : 'En ${peak.label}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!nonEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 30, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 6),
                    const Text(
                      'No hay datos para mostrar en este período.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Prueba seleccionando otro rango de fechas.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 250,
                child: CustomPaint(
                  painter: _MonthlyBarsPainter(
                    values: values,
                    currency: currency,
                    color: color,
                    textColor: theme.colorScheme.onSurfaceVariant,
                    gridColor: theme.dividerColor,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _MonthlyBarsPainter extends CustomPainter {
  const _MonthlyBarsPainter({
    required this.values,
    required this.currency,
    required this.color,
    required this.textColor,
    required this.gridColor,
  });

  final List<({String label, int cents})> values;
  final String currency;
  final Color color, textColor, gridColor;

  String compact(int cents) {
    // Mostrar centavos: redondear a dos decimales sin perder precisión.
    final rounded = (cents.abs() + 5000) ~/ 10000;
    final whole = (rounded ~/ 100).toString();
    final fraction = (rounded % 100).toString().padLeft(2, '0');
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final symbol = currency == 'USD' ? r'$' : r'C$';
    return '$symbol$grouped.$fraction';
  }

  void drawText(Canvas canvas, String value, Offset offset, TextStyle style,
      {double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 70.0, right = 8.0, top = 18.0, bottom = 34.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final maxValue = values.fold<int>(1, (m, v) => math.max(m, v.cents.abs()));
    final grid = Paint()
      ..color = gridColor.withAlpha(110)
      ..strokeWidth = 1;
    final axisStyle = TextStyle(color: textColor, fontSize: 9);
    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final value = (maxValue * (3 - i) / 3).round();
      drawText(canvas, compact(value), Offset(0, y - 6), axisStyle,
          maxWidth: left - 7);
    }
    final slot = chartWidth / values.length;
    final barWidth = math.min(34.0, slot * .58);
    final barPaint = Paint()..color = color.withAlpha(190);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final barHeight = chartHeight * value.cents.abs() / maxValue;
      final x = left + slot * i + (slot - barWidth) / 2;
      final y = top + chartHeight - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, barPaint);
      canvas.drawCircle(
        Offset(x + barWidth / 2, y),
        4,
        Paint()..color = color.withAlpha(225),
      );
      final valueText = compact(value.cents);
      final valuePainter = TextPainter(
        text: TextSpan(text: valueText, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…',
      )..layout(maxWidth: math.max(24, slot - 2));
      valuePainter.paint(canvas, Offset(x + barWidth / 2 - valuePainter.width / 2, math.max(0, y - 15)));
      final label = value.label;
      final labelStyle = TextStyle(color: textColor, fontSize: 9);
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(22, slot - 2));
      labelPainter.paint(
        canvas,
        Offset(left + slot * i + (slot - labelPainter.width) / 2,
            size.height - bottom + 9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarsPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.currency != currency ||
      oldDelegate.color != color ||
      oldDelegate.textColor != textColor ||
      oldDelegate.gridColor != gridColor;
}
