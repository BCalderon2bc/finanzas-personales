import '../core/supabase_client.dart';

Future<List<Map<String, dynamic>>> loadUserTransactions(String userId) async {
  const pageSize = 500;
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += pageSize) {
    final result = await supabase.from('transactions')
        .select('id, account_id, destination_account_id, category_id, '
            'transaction_type, amount, currency, transaction_date, description, reference')
        .eq('user_id', userId)
        .order('transaction_date', ascending: false)
        .order('id')
        .range(offset, offset + pageSize - 1);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < pageSize) break;
  }
  return rows;
}
