import '../core/supabase_client.dart';
import '../utils/money.dart';

Future<List<Map<String, dynamic>>> loadUserCardExpenses(String userId) async {
  final expenses = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase.from('credit_card_transactions')
        .select('id, transaction_type, amount, currency, transaction_date, category_id, description, reference, credit_cards(name)')
        .eq('user_id', userId)
        .eq('is_voided', false)
        .eq('is_receivable_funding', false)
        .inFilter('transaction_type', ['purchase', 'interest', 'fee', 'refund'])
        .order('id').range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    for (final tx in page) {
      final amount = moneyCents(tx['amount']);
      expenses.add({
        'id': tx['id'],
        'transaction_type': 'expense',
        'amount': (tx['transaction_type'] == 'refund' ? -amount : amount) / 100,
        'currency': tx['currency'],
        'transaction_date': tx['transaction_date'],
        'category_id': tx['category_id'],
        'description': tx['description'],
        'reference': tx['reference'],
        'source': 'credit_card',
        'card_transaction_type': tx['transaction_type'],
        'card_name': tx['credit_cards'] is Map
            ? tx['credit_cards']['name']?.toString() : null,
      });
    }
    if (page.length < 500) break;
  }
  return expenses;
}

Future<List<Map<String, dynamic>>> loadUserCardPayments(String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase.from('credit_card_transactions')
        .select('id, credit_card_id, account_id, amount, currency, transaction_date, reference, credit_cards(name)')
        .eq('user_id', userId)
        .eq('is_voided', false)
        .eq('transaction_type', 'payment')
        .order('id').range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) break;
  }
  return rows;
}