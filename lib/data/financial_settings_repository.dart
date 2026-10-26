import '../core/supabase_client.dart';
import 'exchange_rate.dart';

class FinancialSettings {
  const FinancialSettings({required this.rate, this.updatedAt});
  final ExchangeRate rate;
  final DateTime? updatedAt;
}

Future<FinancialSettings?> loadFinancialSettings() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Debes iniciar sesión nuevamente.');
  }
  final row = await supabase.from('user_financial_settings')
      .select('usd_to_nio, updated_at').eq('user_id', userId).maybeSingle();
  if (supabase.auth.currentUser?.id != userId) {
    throw StateError('La sesión cambió. Actualiza la pantalla.');
  }
  if (row == null) {
    return null;
  }
  final rate = ExchangeRate.tryParse('${row['usd_to_nio']}');
  if (rate == null) {
    throw StateError('La tasa guardada no es válida. Actualízala en Configuraciones.');
  }
  return FinancialSettings(rate: rate,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toLocal());
}

Future<void> saveFinancialSettings(ExchangeRate rate, String expectedUserId) async {
  if (supabase.auth.currentUser?.id != expectedUserId) {
    throw StateError('La sesión cambió. Abre nuevamente Configuraciones.');
  }
  await supabase.from('user_financial_settings').upsert({
    'user_id': expectedUserId,
    'usd_to_nio': rate.decimal,
  }, onConflict: 'user_id').select('user_id').single();
  if (supabase.auth.currentUser?.id != expectedUserId) {
    throw StateError('La sesión cambió. Abre nuevamente Configuraciones.');
  }
}
