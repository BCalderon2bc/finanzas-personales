import '../core/supabase_client.dart';

Future<List<Map<String, dynamic>>> loadAdditionalCards(
  String cardId,
  String userId, {
  bool includeControls = false,
}) async {
  const base = 'id,holder_name,last_four,credit_limit,is_active';
  final columns = includeControls
      ? '$base,allows_international,allows_online,merchant_restrictions'
      : base;
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final page = await supabase
        .from('credit_card_additionals')
        .select(columns)
        .eq('credit_card_id', cardId)
        .eq('user_id', userId)
        .order('holder_name')
        .order('id')
        .range(offset, offset + 499);
    rows.addAll(page);
    if (page.length < 500) break;
  }
  if (supabase.auth.currentUser?.id != userId) {
    throw StateError('La sesión cambió. Actualiza la pantalla.');
  }
  return rows;
}
