import 'package:flutter/material.dart';
import '../../utils/money.dart';
import 'expense_report_widgets.dart';

class CategoryExpensesDialog extends StatelessWidget {
  const CategoryExpensesDialog({
    super.key, required this.name, required this.currency, required this.expenses,
  });
  final String name, currency;
  final List<Map<String, dynamic>> expenses;

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
    int charges = 0, refunds = 0;
    for (final tx in rows) {
      final amount = moneyCents(tx['amount']);
      if (amount < 0) {
        refunds += -amount;
      } else {
        charges += amount;
      }
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 580, height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(children: [
              Expanded(child: Text(name, style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Cerrar', onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              ExpenseReportSummary(
                  currency: currency, chargesCents: charges,
                  refundsCents: refunds, count: rows.length, compact: true),
              const SizedBox(height: 20),
              const Text('Detalle de movimientos',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Text('No hay movimientos para mostrar.'),
              ...rows.map((tx) => ExpenseDetailTile(
                  transaction: tx, currency: currency)),
            ],
          )),
        ]),
      ),
    );
  }
}