import '../utils/card_cash_advance.dart';
import '../core/supabase_client.dart';
import '../utils/entry_order.dart';
import 'receivable_loan_repository.dart';

Future<List<Map<String, dynamic>>> loadUserTransactions(String userId) async {
  const pageSize = 500;
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += pageSize) {
    final result = await supabase
        .from('transactions')
        .select(
          'id, account_id, destination_account_id, category_id, transaction_type, amount, '
          'currency, expense_kind, transaction_date, description, reference, is_reconciled, created_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + pageSize - 1);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < pageSize) {
      break;
    }
  }
  // Una transferencia FX equivale a una salida y una entrada en una sola fila.
  for (var offset = 0; ; offset += pageSize) {
    final result = await supabase
        .from('app_fx_transfers')
        .select()
        .eq('user_id', userId)
        .order('id')
        .range(offset, offset + pageSize - 1);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(
      page.map(
        (row) => <String, dynamic>{
          ...row,
          'transaction_type': 'transfer',
          'source': 'fx_transfer',
        },
      ),
    );
    if (page.length < pageSize) break;
  }
  // The card record is the source of truth for the associated cash deposit.
  for (var offset = 0; ; offset += pageSize) {
    final result = await supabase
        .from('credit_card_transactions')
        .select(
          'id,cash_advance_account_id,cash_advance_fee,amount,currency,transaction_date,created_at,reference,description',
        )
        .eq('user_id', userId)
        .eq('charge_kind', cardCashAdvance)
        .eq('is_voided', false)
        .not('cash_advance_account_id', 'is', null)
        .order('id')
        .range(offset, offset + pageSize - 1);
    for (final row in result) {
      rows.add({
        ...row,
        'account_id': row['cash_advance_account_id'],
        'amount': cardCashAdvancePrincipal(row) / 100,
        'transaction_type': 'deposit',
        'description': row['description'] == null
            ? 'Efectivo recibido de tarjeta'
            : 'Efectivo recibido de tarjeta · ${row['description']}',
        'source': cashAdvanceDepositSource,
      });
    }
    if (result.length < pageSize) break;
  }
  rows.addAll(await loadReceivableAccountMovements(userId));
  if (supabase.auth.currentUser?.id != userId) {
    throw StateError('La sesión cambió. Actualiza la pantalla.');
  }
  rows.sort(compareNewestEntry);
  return rows;
}
