import '../core/supabase_client.dart';
import '../utils/money.dart';
import 'payment_agenda_labels.dart' show agendaCardLabel;

Future<List<Map<String, dynamic>>> loadUserCardExpenses(String userId) async {
  final expenses = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase
        .from('credit_card_transactions')
        .select(
          'id, transaction_type, charge_kind, amount, currency, transaction_date, created_at, category_id, description, reference, '
          'credit_cards(card_reference, financial_institutions(name))',
        )
        .eq('user_id', userId)
        .eq('is_voided', false)
        .eq('is_receivable_funding', false)
        .inFilter('transaction_type', ['purchase', 'interest', 'fee', 'refund'])
        .order('id')
        .range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    for (final tx in page) {
      final amount = moneyCents(tx['amount']);
      final card = tx['credit_cards'];
      expenses.add({
        'id': tx['id'],
        'transaction_type': 'expense',
        'amount': (tx['transaction_type'] == 'refund' ? -amount : amount) / 100,
        'currency': tx['currency'],
        'transaction_date': tx['transaction_date'],
        'created_at': tx['created_at'],
        'category_id': tx['category_id'],
        'description': tx['description'],
        'reference': tx['reference'],
        'source': 'credit_card',
        'card_transaction_type': tx['transaction_type'],
        'charge_kind': tx['charge_kind'],
        'card_label': card is Map<String, dynamic>
            ? agendaCardLabel(card, includeName: false)
            : null,
      });
    }
    if (page.length < 500) break;
  }
  return expenses;
}

Future<List<Map<String, dynamic>>> loadUserCardPayments(String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase
        .from('credit_card_transactions')
        .select(
          'id, credit_card_id, account_id, amount, currency, account_debit_amount, account_debit_currency, payment_exchange_rate, transaction_date, created_at, reference, '
          'credit_cards(name, card_reference, financial_institutions(name))',
        )
        .eq('user_id', userId)
        .eq('is_voided', false)
        .eq('transaction_type', 'payment')
        .order('id')
        .range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(
      page.map(
        (p) => {
          ...p,
          'card_amount': p['amount'],
          'card_currency': p['currency'],
          'amount': p['account_debit_amount'] ?? p['amount'],
          'currency': p['account_debit_currency'] ?? p['currency'],
        },
      ),
    );
    if (page.length < 500) break;
  }
  return rows;
}
