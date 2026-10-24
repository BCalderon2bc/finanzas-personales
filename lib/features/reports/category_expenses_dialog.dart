import 'package:flutter/material.dart';
import '../../utils/money.dart';

class CategoryExpensesDialog extends StatelessWidget {
  const CategoryExpensesDialog({
    super.key, required this.name, required this.currency, required this.expenses,
  });
  final String name, currency;
  final List<Map<String, dynamic>> expenses;

  String money(int cents) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  String dateText(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = List<Map<String, dynamic>>.from(expenses)
      ..sort((a, b) {
        final first = DateTime.tryParse('${a['transaction_date']}');
        final second = DateTime.tryParse('${b['transaction_date']}');
        if (first == null) return second == null ? 0 : 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });
    final total = rows.fold<int>(0, (sum, tx) => sum + moneyCents(tx['amount']));
    const cardTypes = {
      'purchase': 'Compra', 'interest': 'Intereses',
      'fee': 'Comisión', 'refund': 'Devolución',
    };

    return AlertDialog(
      title: Text(name),
      content: SizedBox(
        width: 520, height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Gasto neto: ${money(total)}',
              style: Theme.of(context).textTheme.titleMedium),
          Text('${rows.length} movimientos'),
          const Divider(),
          Expanded(child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final tx = rows[index];
              final card = tx['source'] == 'credit_card';
              final debtPayment = tx['source'] == 'debt_payment';
              final description = tx['description']?.toString().trim() ?? '';
              final reference = tx['reference']?.toString().trim() ?? '';
              final cardName = tx['card_name']?.toString().trim() ?? '';
              final label = debtPayment ? 'Intereses y comisiones de deuda'
                  : card ? cardTypes[tx['card_transaction_type']] ?? 'Tarjeta'
                  : 'Gasto de cuenta';
              final amount = moneyCents(tx['amount']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(debtPayment ? Icons.payments_outlined
                      : card ? Icons.credit_card : Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(description.isEmpty ? label : description,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${dateText(tx['transaction_date'])} · $label'),
                    if (card && cardName.isNotEmpty) Text(cardName),
                    Text(money(amount), style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: amount < 0 ? Colors.green : null)),
                    if (debtPayment) ...[
                      Text('Intereses: ${money(moneyCents(tx['interest_amount']))}'),
                      Text('Comisiones: ${money(moneyCents(tx['fee_amount']))}'),
                    ],
                    if (reference.isNotEmpty) SelectableText('Referencia: $reference'),
                  ],
                  )),
                ]),
              );
            },
          )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}