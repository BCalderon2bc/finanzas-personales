import '../../data/exchange_rate.dart';
import 'package:flutter/material.dart';
import '../../data/export_report_models.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import 'export_reports_page.dart';

class ConsolidatedExpensesPanel extends StatelessWidget {
  const ConsolidatedExpensesPanel({
    super.key,
    required this.movements,
    required this.start,
    required this.end,
    this.exchangeRate,
  });
  final List<ExportMovement> movements;
  final DateTime start, end;
  final ExchangeRate? exchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = consolidatedExpensesReport(
      movements,
      start,
      end,
      'all',
      DateTime.now(),
    );
    int nativeTotal(String currency) => report.totals
        .singleWhere(
          (t) => t.currency == currency && t.label == 'Gasto neto total',
        )
        .cents;
    final rate = exchangeRate;
    final selected = movements.where((m) => inReportRange(m.date, start, end));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Gastos consolidados', style: theme.textTheme.titleLarge),
            Text(
              '${reportDate(start)} – ${reportDate(end)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AdaptiveColumns(
              minColumnWidth: 260,
              spacing: 16,
              children: [
                for (final currency in ['USD', 'NIO'])
                  Builder(
                    builder: (context) {
                      final total = report.totals
                          .singleWhere(
                            (t) =>
                                t.currency == currency &&
                                t.label == 'Gasto neto total',
                          )
                          .cents;
                      final capital = report.totals
                          .singleWhere(
                            (t) =>
                                t.currency == currency &&
                                t.label.startsWith('Capital'),
                          )
                          .cents;
                      final groups = <String, int>{
                        'Cuentas y efectivo': 0,
                        'Tarjetas de crédito': 0,
                        'Intereses y cargos de préstamos': 0,
                      };
                      for (final m in selected.where(
                        (m) => m.currency == currency,
                      )) {
                        final type = '${m.values[1]}';
                        final group = type == 'Abono de préstamo'
                            ? 'Intereses y cargos de préstamos'
                            : type.contains('tarjeta') ||
                                  type.toLowerCase().contains('retiro')
                            ? 'Tarjetas de crédito'
                            : 'Cuentas y efectivo';
                        groups[group] = groups[group]! + m.expense;
                      }
                      final positiveTotal = groups.values.fold<int>(
                        0,
                        (n, v) => n + (v > 0 ? v : 0),
                      );
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: .05,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              currency == 'USD' ? 'Dólares' : 'Córdobas',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              formatMoneyCents(total, currency),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final entry in groups.entries) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatMoneyCents(entry.value, currency),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: positiveTotal == 0 || entry.value <= 0
                                    ? 0
                                    : entry.value / positiveTotal,
                                minHeight: 4,
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              'Capital pagado de cuotas y préstamos: ${formatMoneyCents(capital, currency)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: .2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total combinado · ambas monedas',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (rate != null) ...[
                    AdaptiveColumns(
                      minColumnWidth: 180,
                      spacing: 12,
                      maxColumns: 2,
                      children: [
                        for (final currency in ['USD', 'NIO'])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency == 'USD'
                                    ? 'Equivalente en dólares'
                                    : 'Equivalente en córdobas',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                formatMoneyCents(
                                  nativeTotal(currency) +
                                      rate.convert(
                                        nativeTotal(
                                          currency == 'USD' ? 'NIO' : 'USD',
                                        ),
                                        currency == 'USD' ? 'NIO' : 'USD',
                                        currency,
                                      ),
                                  currency,
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tasa del sistema: C\$ ${rate.decimal} por \$1. Son dos equivalencias del mismo total; excluye el capital pagado.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    Text(
                      'Configura la tasa del sistema para calcular el total combinado.',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Gastos menos devoluciones. Los pagos de tarjeta no se suman otra vez; el capital de préstamos se muestra separado.',
              style: theme.textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExportReportsPage(
                      initialKind: 'consolidated_expenses',
                      initialStart: start,
                      initialEnd: end,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver detalle y exportar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
