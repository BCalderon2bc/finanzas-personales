import '../core/supabase_client.dart';
import '../utils/money.dart';

Future<List<Map<String, dynamic>>> loadUserDebtPayments(String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase
        .from('debt_payments')
        .select(
          'id, debt_id, account_id, principal_amount, interest_amount, '
          'fee_amount, insurance_amount, currency, payment_date, created_at, reference, debts(description)',
        )
        .eq('user_id', userId)
        .eq('is_voided', false)
        .order('id')
        .range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) break;
  }
  return rows;
}

List<Map<String, dynamic>> debtPaymentExpenses(
  List<Map<String, dynamic>> payments,
) {
  final expenses = <Map<String, dynamic>>[];
  for (final payment in payments) {
    final interest = moneyCents(payment['interest_amount']);
    final fees = moneyCents(payment['fee_amount']);
    if (interest + fees <= 0) continue;
    final debt = payment['debts'];
    final name = debt is Map ? debt['description']?.toString() ?? '' : '';
    expenses.add({
      'id': payment['id'],
      'transaction_type': 'expense',
      'amount': (interest + fees) / 100,
      'currency': payment['currency'],
      'transaction_date': payment['payment_date'],
      'created_at': payment['created_at'],
      'category_id': null,
      'description': name.isEmpty
          ? 'Costos de deuda'
          : 'Costos de deuda: $name',
      'reference': payment['reference'],
      'source': 'debt_payment',
      'interest_amount': payment['interest_amount'],
      'fee_amount': payment['fee_amount'],
      'insurance_amount': payment['insurance_amount'] ?? 0,
    });
  }
  return expenses;
}
