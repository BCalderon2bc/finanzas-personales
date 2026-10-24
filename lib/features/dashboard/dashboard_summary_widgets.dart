import 'package:flutter/material.dart';
import '../../utils/money.dart';
import 'dashboard_summary.dart';

class CurrencySummaryCard extends StatelessWidget {
  const CurrencySummaryCard({super.key, required this.currency, required this.summary});
  final String currency;
  final CurrencySummary summary;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(currency == 'USD' ? 'Dólares' : 'Córdobas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text('Saldo registrado · cuentas activas'),
      Text(formatMoney(summary.balance, currency), style: Theme.of(context).textTheme.headlineSmall),
      const Divider(height: 24),
      _row(context, 'Ingresos del mes', summary.income, Colors.green),
      _row(context, 'Gastos del mes', summary.expense, Theme.of(context).colorScheme.error),
      _row(context, 'Diferencia del mes', summary.net, summary.net < 0 ? Theme.of(context).colorScheme.error : null),
    ]),
  ));
  Widget _row(BuildContext context, String label, int amount, Color? color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Expanded(child: Text(label)), const SizedBox(width: 8),
      Flexible(child: Text(formatMoney(amount, currency), textAlign: TextAlign.right,
        style: TextStyle(color: color, fontWeight: FontWeight.w600))),
    ]),
  );
}
class RecentTransactionCard extends StatelessWidget {
  const RecentTransactionCard({super.key, required this.transaction, required this.accountNames, required this.onTap});
  final Map<String, dynamic> transaction;
  final Map<String, String> accountNames;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final type = tx['transaction_type'];
    final income = type == 'income' || type == 'deposit';
    final expense = type == 'expense' || type == 'withdrawal';
    final label = switch (type) {
      'income' => 'Ingreso', 'expense' => 'Gasto', 'transfer' => 'Transferencia',
      'deposit' => 'Depósito', 'withdrawal' => 'Retiro', _ => 'Movimiento',
    };
    final description = tx['description']?.toString().trim() ?? '';
    final date = DateTime.parse(tx['transaction_date'].toString()).toLocal();
    final dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final origin = accountNames[tx['account_id'].toString()] ?? 'Cuenta no disponible';
    final destination = accountNames[tx['destination_account_id'].toString()] ?? 'Cuenta no disponible';
    return Card(child: ListTile(
      onTap: onTap, leading: Icon(income ? Icons.arrow_downward : expense ? Icons.arrow_upward : Icons.swap_horiz),
      title: Text(description.isEmpty ? label : description, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$dateText · $label'),
        Text(type == 'transfer' ? '$origin → $destination' : origin),
        Text('${income ? '+' : expense ? '−' : ''}${formatMoney(moneyCents(tx['amount']), tx['currency'].toString())}',
          style: TextStyle(fontWeight: FontWeight.bold,
            color: income ? Colors.green : expense ? Theme.of(context).colorScheme.error : null)),
      ]),
      trailing: const Icon(Icons.chevron_right),
    ));
  }
}
