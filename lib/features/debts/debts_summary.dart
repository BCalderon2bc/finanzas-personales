import 'package:flutter/material.dart';
import '../../utils/money.dart';
import 'debt_due_status.dart';

class DebtsSummary extends StatelessWidget {
  const DebtsSummary({super.key, required this.debts, required this.principalPaid});
  final List<Map<String, dynamic>> debts;
  final Map<String, int> principalPaid;

  String money(int cents, String currency) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  Widget currencyCard(BuildContext context, String currency, DateTime now) {
    int pending = 0, overdue = 0, today = 0, count = 0;
    for (final debt in debts) {
      if (debt['currency'] != currency || debt['status'] == 'cancelled') continue;
      final paid = principalPaid[debt['id'].toString()] ?? 0;
      final remaining = moneyCents(debt['original_amount']) - paid;
      if (remaining <= 0) continue;
      pending += remaining;
      count++;
      final status = debtDueStatus(debt, paid, now);
      if (status == DebtDueStatus.overdue) overdue += remaining;
      if (status == DebtDueStatus.today) today += remaining;
    }
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(currency == 'USD' ? 'Deudas en dólares' : 'Deudas en córdobas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Capital pendiente'),
        Text(money(pending, currency),
            style: Theme.of(context).textTheme.headlineSmall),
        const Divider(height: 24),
        Text('Capital vencido: ${money(overdue, currency)}',
            style: TextStyle(
                color: overdue > 0 ? Theme.of(context).colorScheme.error : null)),
        Text('Vence hoy: ${money(today, currency)}'),
        const SizedBox(height: 8),
        Text('$count deudas con capital pendiente'),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final nio = currencyCard(context, 'NIO', now);
        final usd = currencyCard(context, 'USD', now);
        return constraints.maxWidth < 600
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nio, usd])
            : Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: nio), Expanded(child: usd)]);
      }),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Incluye capital pendiente de deudas no canceladas, también las pausadas. No incluye intereses ni comisiones pendientes.')),
    ]);
  }
}