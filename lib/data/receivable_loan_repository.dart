import '../core/supabase_client.dart';
import 'receivable_loan_logic.dart';

class ReceivableLoanData {
  const ReceivableLoanData(this.loans, this.payments);
  final List<Map<String, dynamic>> loans, payments;
}

Future<List<Map<String, dynamic>>> _receivableRows(String table, String columns, String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase.from(table).select(columns).eq('user_id', userId)
      .order('id').range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) { break; }
  }
  return rows;
}

Future<ReceivableLoanData> loadReceivableLoanData(String userId) async {
  final rows = await Future.wait([
    _receivableRows('receivable_loans', 'id, user_id, borrower_name, description, principal_amount, '
      'currency, account_id, credit_card_id, card_transaction_id, is_historical, loan_date, due_date, reference, is_voided, void_reason, voided_at', userId),
    _receivableRows('receivable_loan_payments', 'id, loan_id, account_id, principal_amount, interest_amount, '
      'currency, payment_date, reference, is_voided, void_reason, voided_at', userId),
  ]);
  return ReceivableLoanData(rows[0], rows[1]);
}

Future<List<Map<String, dynamic>>> loadReceivableAccountMovements(String userId) async {
  final data = await loadReceivableLoanData(userId);
  return receivableAccountMovements(data.loans, data.payments);
}
