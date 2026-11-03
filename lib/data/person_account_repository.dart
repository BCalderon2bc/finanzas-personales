import '../core/supabase_client.dart';
export 'person_account_logic.dart';

String personUserId() {
  final id = supabase.auth.currentUser?.id;
  if (id == null) throw StateError('Debes iniciar sesión nuevamente.');
  return id;
}

void checkPersonSession(String id) {
  if (supabase.auth.currentUser?.id != id)
    throw StateError('La sesión cambió. Abre nuevamente esta pantalla.');
}

Future<List<Map<String, dynamic>>> personRows(
  String table,
  String userId, {
  String? accountId,
  bool includeShared = false,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    var query = supabase.from(table).select();
    if (!includeShared) query = query.eq('user_id', userId);
    if (accountId != null) query = query.eq('person_account_id', accountId);
    final result = await query.order('id').range(offset, offset + 499);
    checkPersonSession(userId);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) break;
  }
  return rows;
}

Future<List<Map<String, dynamic>>> personShares(
  String uid, {
  String? accountId,
}) async {
  final rows = await supabase.rpc(
    'person_share_list',
    params: {'p_account': accountId},
  );
  checkPersonSession(uid);
  return List<Map<String, dynamic>>.from(rows as List);
}
