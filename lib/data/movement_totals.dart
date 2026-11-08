import '../utils/money.dart';

class MovementTotals {
  int income = 0, expenses = 0, cardPayments = 0, debtPayments = 0;
  int deposits = 0, withdrawals = 0, transfers = 0, adjustments = 0;
}

Map<String, MovementTotals> movementTotals(
  Iterable<Map<String, dynamic>> rows, {
  bool includeDebtCharges = true,
}) {
  final totals = {
    for (final c in ['NIO', 'USD']) c: MovementTotals(),
  };
  for (final row in rows) {
    if (row['is_voided'] == true) continue;
    final group = totals[row['currency']];
    if (group == null) throw StateError('Moneda no admitida en el historial.');
    final amount = moneyCents(row['amount']);
    switch (row['transaction_type']) {
      case 'income':
        group.income += amount;
      case 'expense':
        group.expenses += amount;
      case 'card_payment':
        group.cardPayments += amount;
      case 'debt_payment':
        group.debtPayments += amount;
        if (includeDebtCharges) {
          group.expenses +=
              moneyCents(row['interest_amount'] ?? 0) +
              moneyCents(row['fee_amount'] ?? 0);
        }
      case 'deposit':
        group.deposits += amount;
      case 'withdrawal':
        group.withdrawals += amount;
      case 'transfer':
        group.transfers += amount;
      case 'adjustment':
        group.adjustments += amount;
    }
  }
  return totals;
}
