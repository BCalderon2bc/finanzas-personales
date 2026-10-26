import '../core/supabase_client.dart';
import 'receivable_loan_repository.dart';

Future<List<Map<String, dynamic>>> loadUserTransactions(String userId) async {
  const pageSize = 500;
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += pageSize) {
    final result = await supabase.from('transactions')
      .select('id, account_id, destination_account_id, category_id, transaction_type, amount, '
        'currency, transaction_date, description, reference, is_reconciled')
      .eq('user_id', userId).order('transaction_date', ascending: false).order('id')
      .range(offset, offset + pageSize - 1);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < pageSize) { break; }
  }
  rows.addAll(await loadReceivableAccountMovements(userId));
  if (supabase.auth.currentUser?.id != userId) { throw StateError('La sesión cambió. Actualiza la pantalla.'); }
  rows.sort((a, b) {
    final first = DateTime.tryParse('${a['transaction_date']}');
    final second = DateTime.tryParse('${b['transaction_date']}');
    if (first == null) { return second == null ? 0 : 1; }
    if (second == null) { return -1; }
    final byDate = second.compareTo(first);
    return byDate != 0 ? byDate : a['id'].toString().compareTo(b['id'].toString());
  });
  return rows;
}
