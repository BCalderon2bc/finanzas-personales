import 'dart:convert';
import 'dart:math';
import '../core/supabase_client.dart';
import 'card_statement_repository.dart' show statementRows;
export 'zero_plan_logic.dart';
import 'zero_plan_logic.dart';

String zeroUser() {
  final id = supabase.auth.currentUser?.id;
  if (id == null) throw StateError('Inicia sesión nuevamente.');
  return id;
}

void zeroSession(String id) {
  if (supabase.auth.currentUser?.id != id)
    throw StateError('La sesión cambió. Vuelve a abrir la pantalla.');
}

Future<ZeroPlanData> loadZeroPlans(String uid) async {
  final rows = await Future.wait([
    statementRows('card_zero_plans', '*', uid),
    statementRows('card_zero_installments', '*', uid),
    statementRows('card_zero_allocations', '*', uid),
    statementRows(
      'credit_card_transactions',
      'id,credit_card_id,account_id,transaction_type,amount,currency,transaction_date,description,is_voided',
      uid,
    ),
  ]);
  zeroSession(uid);
  return ZeroPlanData(
    plans: rows[0],
    installments: rows[1],
    allocations: rows[2],
    transactions: rows[3],
  );
}

String _uuid() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ZeroCommands {
  final pending = <String, String>{};
  Future<dynamic> run(
    String rpc,
    Map<String, dynamic> params, {
    bool operation = false,
  }) async {
    final uid = zeroUser(), key = '$uid:$rpc:${jsonEncode(params)}';
    final id = operation ? pending.putIfAbsent(key, _uuid) : null;
    final result = await supabase.rpc(
      rpc,
      params: {if (id != null) 'p_id': id, ...params},
    );
    zeroSession(uid);
    pending.remove(key);
    return result;
  }
}
