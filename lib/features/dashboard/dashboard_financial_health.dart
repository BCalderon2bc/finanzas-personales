import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

const _blue = Color(0xFF2563EB);
const _green = Color(0xFF087F5B);
const _red = Color(0xFFB42318);
const _amber = Color(0xFFB45309);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class DashboardFinancialHealth extends StatelessWidget {
  const DashboardFinancialHealth({
    super.key,
    required this.data,
    required this.currency,
  });

  final DashboardOverview data;
  final String currency;

  String money(int value) => dashboardMoney(value, currency);

  @override
  Widget build(BuildContext context) {
    final c = data.currencies[currency]!;
    final debt = c.liabilities;

    final savingsBalance = data.accounts
        .where(
          (a) =>
              a['currency'] == currency &&
              a['account_type'] == 'savings' &&
              a['is_active'] == true,
        )
        .fold<int>(0, (sum, a) => sum + (a['balance_cents'] as int));

    final savings = math.max(0, savingsBalance);
    final covered = debt == null ? 0 : math.min(savings, debt);
    final uncovered = debt == null ? 0 : math.max(0, debt - savings);
    final coverage = debt != null && debt > 0
        ? (savings / debt * 100).clamp(0.0, 100.0)
        : null;

    final income = math.max(0, c.income);
    final expense = math.max(0, c.expense);
    final consumed = math.min(income, expense);
    final remainingIncome = math.max(0, income - expense);
    final spendingRatio = income > 0 ? expense / income : null;

    final positiveCategories =
        c.categories.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    const palette = [
      _blue,
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFFDB2777),
      Color(0xFFF59E0B),
      Color(0xFF94A3B8),
    ];

    final categorySlices = <_Slice>[];

    for (var i = 0; i < positiveCategories.length && i < 5; i++) {
      final entry = positiveCategories[i];
      categorySlices.add(
        _Slice(
          entry.key == 'none'
              ? 'Sin categoría'
              : data.categoryNames[entry.key] ?? 'Categoría no disponible',
          entry.value,
          palette[i],
        ),
      );
    }

    final otherCategories = positiveCategories
        .skip(5)
        .fold<int>(0, (sum, e) => sum + e.value);

    if (otherCategories > 0) {
      categorySlices.add(
        _Slice('Otras categorías', otherCategories, palette.last),
      );
    }

    final positiveCategoryTotal = positiveCategories.fold<int>(
      0,
      (sum, e) => sum + e.value,
    );

    final hasNegativeCategories = c.categories.values.any((value) => value < 0);

    final monthlyColor = spendingRatio == null
        ? _blue
        : spendingRatio > 1
        ? _red
        : spendingRatio >= 0.8
        ? _amber
        : _green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _blue.withAlpha(16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.monitor_heart_outlined, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Así van tus finanzas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.period.label} · $currency',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _statusCard(
          c: c,
          debt: debt,
          savings: savings,
          savingsBalance: savingsBalance,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1050
                ? 3
                : box.maxWidth >= 680
                ? 2
                : 1;
            final width = (box.maxWidth - 16 * (columns - 1)) / columns;

            final panels = [
              _ChartPanel(
                title: 'Tu período en números',
                subtitle: 'Gastos frente a ingresos registrados',
                icon: Icons.insights_outlined,
                center: income == 0
                    ? '—'
                    : '${(expense / income * 100).toStringAsFixed(0)}%',
                centerLabel: 'de tus ingresos',
                centerColor: monthlyColor,
                slices: [
                  _Slice('Ingreso consumido', consumed, monthlyColor),
                  _Slice('Ingreso restante', remainingIncome, _green),
                ],
                emptyText: 'Sin ingresos positivos para comparar.',
                legend: [
                  _Legend('Ingresos', money(c.income), _blue),
                  _Legend('Gasto neto', money(c.expense), monthlyColor),
                  _Legend(
                    c.net < 0 ? 'Déficit del período' : 'Resultado del período',
                    money(c.net.abs()),
                    c.net < 0 ? _red : _green,
                  ),
                ],
                footer: c.expense < 0
                    ? 'Las devoluciones superan los gastos registrados.'
                    : spendingRatio == null
                    ? 'Registra ingresos para comparar el gasto del período.'
                    : spendingRatio > 1
                    ? 'Gastaste ${money(c.expense - c.income)} más de lo que ingresó.'
                    : 'El resultado del período no equivale al saldo disponible de tus cuentas.',
              ),
              _ChartPanel(
                title: 'Ahorros frente a deudas',
                subtitle: 'Cobertura con tus cuentas de ahorro activas',
                icon: Icons.savings_outlined,
                center: debt == null
                    ? '—'
                    : debt == 0
                    ? 'Sin deuda'
                    : '${coverage!.toStringAsFixed(0)}%',
                centerLabel: debt == null
                    ? 'requiere revisión'
                    : debt == 0
                    ? 'registrada'
                    : 'deuda cubierta',
                centerColor: debt == null
                    ? _muted
                    : debt == 0 || savings >= debt
                    ? _green
                    : _amber,
                slices: debt == null || debt == 0
                    ? const []
                    : [
                        _Slice('Cubierta con ahorro', covered, _green),
                        _Slice('Sin cubrir con ahorro', uncovered, _amber),
                      ],
                emptyText: debt == null
                    ? 'Revisa los ajustes de tus tarjetas.'
                    : 'No tienes deuda registrada en esta moneda.',
                legend: [
                  _Legend('Ahorro disponible', money(savings), _green),
                  _Legend(
                    'Deuda total',
                    debt == null ? 'Por revisar' : money(debt),
                    _amber,
                  ),
                  if (debt != null)
                    _Legend(
                      savings >= debt
                          ? 'Ahorro sobre la deuda'
                          : 'Falta para cubrirla',
                      money((savings - debt).abs()),
                      savings >= debt ? _green : _amber,
                    ),
                ],
                footer:
                    'Compara saldos actuales. Incluye capital de préstamos '
                    'y deuda de tarjetas; excluye intereses futuros. '
                    'Es una comparación, no una indicación de pagar todo hoy.',
              ),
              _ChartPanel(
                title: '¿Dónde se va tu dinero?',
                subtitle: 'Distribución del gasto neto positivo',
                icon: Icons.donut_large_outlined,
                center: '${positiveCategories.length}',
                centerLabel: 'categorías',
                centerColor: _blue,
                slices: categorySlices,
                emptyText: 'Sin categorías con gasto neto positivo.',
                legend: categorySlices.map((slice) {
                  final percentage = positiveCategoryTotal == 0
                      ? 0.0
                      : slice.value / positiveCategoryTotal * 100;
                  return _Legend(
                    slice.label,
                    '${money(slice.value)} · ${percentage.toStringAsFixed(0)}%',
                    slice.color,
                  );
                }).toList(),
                footer: hasNegativeCategories
                    ? 'Las categorías con devoluciones netas negativas no '
                          'participan en este gráfico. Sí se incluyen en el gasto neto del período.'
                    : 'Incluye categorías con gasto neto positivo. '
                          'Los porcentajes corresponden a su suma.',
              ),
            ];

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: panels
                  .map((panel) => SizedBox(width: width, child: panel))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _statusCard({
    required DashboardCurrency c,
    required int? debt,
    required int savings,
    required int savingsBalance,
  }) {
    final hasMonthlyActivity = c.income != 0 || c.expense != 0;
    final alerts = <String>[];

    if (c.overdueCount > 0) {
      alerts.add(
        '${c.overdueCount} deudas tienen capital vencido: ${money(c.overdue)}.',
      );
    }

    if (c.todayCount > 0) {
      alerts.add('${c.todayCount} deudas vencen hoy: ${money(c.dueToday)}.');
    }

    if (c.cash < 0) {
      alerts.add('El saldo total de tus cuentas activas es negativo.');
    }

    if (savingsBalance < 0) {
      alerts.add('El saldo conjunto de tus cuentas de ahorro es negativo.');
    }

    if (!c.cardKnown) {
      alerts.add('Hay ajustes de tarjeta que requieren revisión.');
    }

    final deficit = hasMonthlyActivity && c.net < 0;
    final color = deficit || c.cash < 0 || c.overdueCount > 0
        ? _red
        : alerts.isNotEmpty
        ? _amber
        : hasMonthlyActivity
        ? _green
        : _blue;

    final title = deficit
        ? 'Tus gastos superan tus ingresos este período'
        : hasMonthlyActivity
        ? 'Tu período mantiene un resultado positivo o equilibrado'
        : 'Aún falta actividad para evaluar este período';

    final description = deficit
        ? 'La diferencia es de ${money(-c.net)}. '
              'Revisa las categorías con mayor gasto para identificar dónde ajustar.'
        : hasMonthlyActivity
        ? 'Ingresos menos gastos: ${money(c.net)}. '
              'Este resultado incluye los movimientos registrados del rango seleccionado.'
        : 'Al registrar ingresos y gastos podrás ver cómo evoluciona el período.';

    final savingsText = debt == null
        ? 'La comparación entre ahorro y deuda está pendiente de revisión.'
        : debt == 0
        ? 'No tienes deuda registrada en esta moneda.'
        : savings >= debt
        ? 'Tus ahorros registrados alcanzan para cubrir la deuda de esta moneda.'
        : 'Tus ahorros cubren ${(savings / debt * 100).toStringAsFixed(0)}% '
              'de la deuda registrada en esta moneda.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                color == _red
                    ? Icons.warning_amber_rounded
                    : Icons.insights_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 8),
          Text(savingsText, style: const TextStyle(height: 1.5)),
          if (alerts.isNotEmpty) ...[
            const Divider(height: 24),
            for (final alert in alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $alert',
                  style: TextStyle(color: color, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _Legend {
  const _Legend(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.center,
    required this.centerLabel,
    required this.centerColor,
    required this.slices,
    required this.emptyText,
    required this.legend,
    required this.footer,
  });

  final String title, subtitle, center, centerLabel, emptyText, footer;
  final IconData icon;
  final Color centerColor;
  final List<_Slice> slices;
  final List<_Legend> legend;

  Widget compactPanel(BuildContext context) {
    final hasValues = slices.any((slice) => slice.value > 0);
    final chart = Semantics(
      label: '$title: $center $centerLabel',
      child: SizedBox(
        width: 110,
        height: 110,
        child: CustomPaint(
          painter: _DonutPainter(slices),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(21),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        center,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: centerColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        centerLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final values = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: legend
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 17.5) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 12),
                    values,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  chart,
                  const SizedBox(width: 16),
                  Expanded(child: values),
                ],
              );
            },
          ),
          if (!hasValues)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                emptyText,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Cómo se calcula',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  footer,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 650 ||
        MediaQuery.textScalerOf(context).scale(14) > 17.5) {
      return compactPanel(context);
    }
    final hasValues = slices.any((slice) => slice.value > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Semantics(
                label: '$title: $center $centerLabel',
                child: CustomPaint(
                  painter: _DonutPainter(slices),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              center,
                              style: TextStyle(
                                color: centerColor,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            centerLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!hasValues) ...[
            const SizedBox(height: 14),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),
          for (final item in legend)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 6,
                    child: Text(
                      item.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 26),
          Text(
            footer,
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.slices);

  final List<_Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 19.0;
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFF1F5F9);
    canvas.drawCircle(center, radius, paint);

    final positive = slices.where((slice) => slice.value > 0).toList();
    final total = positive.fold<int>(0, (sum, slice) => sum + slice.value);

    if (total == 0) {
      return;
    }

    var start = -math.pi / 2;

    for (final slice in positive) {
      final sweep = slice.value / total * math.pi * 2;
      final gap = positive.length > 1 ? math.min(0.035, sweep * 0.15) : 0.0;

      paint.color = slice.color;
      canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
