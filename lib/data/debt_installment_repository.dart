import '../core/supabase_client.dart';
import 'debt_installment_logic.dart';
import 'card_statement_repository.dart' show statementRows;
export 'debt_installment_logic.dart';

Future<DebtInstallmentData> loadDebtInstallments(String userId) async {
  final rows = await Future.wait([
    statementRows(
      'debt_installments',
      'id,user_id,debt_id,plan_id,number,due_date,currency,amount,notes,is_archived,is_voided',
      userId,
    ),
    _links(userId),
    statementRows(
      'debt_payments',
      'id,debt_id,account_id,currency,principal_amount,interest_amount,fee_amount,payment_date,reference,is_voided',
      userId,
    ),
  ]);
  if (supabase.auth.currentUser?.id != userId) {
    throw StateError('La sesión cambió.');
  }
  return DebtInstallmentData(
    installments: rows[0],
    links: rows[1],
    payments: rows[2],
  );
}

Future<List<Map<String, dynamic>>> _links(String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase
        .from('debt_installment_payments')
        .select('payment_id,installment_id,user_id')
        .eq('user_id', userId)
        .order('payment_id')
        .range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) {
      break;
    }
  }
  return rows;
}
