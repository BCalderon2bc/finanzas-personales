import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

class DashboardMonthlyBalance extends StatelessWidget {
  const DashboardMonthlyBalance({
    super.key,
    required this.data,
    required this.currency,
  });
  final DashboardOverview data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final summary = data.currencies[currency]!;
    final income = summary.income;
    final expense = summary.expense;
    final net = income - expense;
    final difference = net - summary.previousNet;
    final maximum = [
      income.abs(),
      expense.abs(),
    ].reduce((a, b) => a > b ? a : b);
    final positive = net >= 0;
    final color = positive ? const Color(0xFF059669) : const Color(0xFFDC2626);

    Widget bar(String label, int amount, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              Text(
                dashboardMoney(amount, currency),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: maximum == 0 ? 0 : amount.abs() / maximum,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              color: color,
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Balance del período',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.period.label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            bar('Ingresos', income, const Color(0xFF059669)),
            bar(
              expense < 0
                  ? 'Gastos netos · devoluciones superiores'
                  : 'Gastos netos',
              expense,
              const Color(0xFFF97316),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: positive
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultado: ingresos menos gastos',
                    style: TextStyle(color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dashboardMoney(net, currency),
                    style: TextStyle(
                      color: color,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    difference == 0
                        ? 'Sin diferencia frente al período anterior.'
                        : '${difference > 0 ? 'Mejoró' : 'Disminuyó'} '
                              '${dashboardMoney(difference.abs(), currency)} '
                              'frente al período anterior.',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Las barras comparan magnitudes. El resultado excluye transferencias y pagos de capital.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
