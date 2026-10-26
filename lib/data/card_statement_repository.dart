import '../core/supabase_client.dart';
import 'card_statement_logic.dart';
export 'card_statement_logic.dart';

Future<List<Map<String,dynamic>>> statementRows(String table,String columns,String userId) async {
  final rows=<Map<String,dynamic>>[];
  final order=table == 'credit_card_statement_payments' ? 'payment_id' : 'id';
  for(var offset=0;;offset+=500) {
    final result=await supabase.from(table).select(columns).eq('user_id',userId)
      .order(order).range(offset,offset+499);
    final page=List<Map<String,dynamic>>.from(result);rows.addAll(page);
    if(page.length<500) { break; }
  }
  return rows;
}

Future<CardStatementData> loadCardStatements(String userId) async {
  final rows=await Future.wait([
    statementRows('credit_card_statements','id,user_id,credit_card_id,currency,closing_date,due_date,balance_due,minimum_due,notes,is_archived,is_voided',userId),
    statementRows('credit_card_statement_payments','payment_id,statement_id,user_id',userId),
    statementRows('credit_card_transactions','id,credit_card_id,transaction_type,amount,currency,transaction_date,reference,is_voided',userId),
  ]);
  if(supabase.auth.currentUser?.id != userId) { throw StateError('La sesión cambió. Actualiza la pantalla.'); }
  return CardStatementData(statements:rows[0],links:rows[1],payments:rows[2]);
}
