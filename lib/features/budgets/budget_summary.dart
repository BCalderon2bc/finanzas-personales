import 'package:flutter/material.dart';
import '../../utils/money.dart';

class BudgetSummary extends StatelessWidget {
  const BudgetSummary({super.key, required this.budgets, required this.spent});
  final List<Map<String, dynamic>> budgets;
  final Map<String, int> spent;

  String money(int cents, String currency) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  Widget currencyCard(BuildContext context, String currency) {
    final selected = budgets.where((b) => b['currency'] == currency);
    final categories = <String>{};
    int limit = 0, used = 0, exceeded = 0;
    for (final budget in selected) {
      final amount = moneyCents(budget['budget_amount']);
      final key = '${budget['category_id']}|$currency';
      final expense = spent[key] ?? 0;
      limit += amount;
      if (categories.add(key)) used += expense;
      if (expense > amount) exceeded++;
    }
    final remaining = limit - used;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(currency == 'USD' ? 'Resumen en dólares' : 'Resumen en córdobas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Presupuestado: ${money(limit, currency)}'),
        Text('Gastado: ${money(used, currency)}'),
        const SizedBox(height: 8),
        Text(remaining < 0
            ? 'Exceso neto: ${money(-remaining, currency)}'
            : 'Disponible neto: ${money(remaining, currency)}',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: remaining < 0 ? Theme.of(context).colorScheme.error : null)),
        const Divider(height: 20),
        Text('${selected.length} presupuestos · $exceeded excedidos',
            style: TextStyle(
                color: exceeded > 0 ? Theme.of(context).colorScheme.error : null)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final nio = currencyCard(context, 'NIO');
        final usd = currencyCard(context, 'USD');
        return constraints.maxWidth < 600
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nio, usd])
            : Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: nio), Expanded(child: usd)]);
      }),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('El resumen incluye únicamente las categorías presupuestadas de este mes.')),
    ]);
  }
}