import '../core/supabase_client.dart';
import 'person_account_repository.dart';
import 'person_account_report.dart';
import 'export_report_models.dart';

Future<ExportReport> loadPersonAccountReport(
  String accountId, {
  DateTime? start,
  DateTime? end,
}) async {
  final uid = personUserId();
  final values = await Future.wait<Object>([
    supabase
        .from('person_accounts')
        .select('id,name,is_active')
        .eq('id', accountId)
        .eq('user_id', uid)
        .single(),
    personRows('person_account_entries', uid, accountId: accountId),
  ]);
  checkPersonSession(uid);
  return personAccountReport(
    account: Map<String, dynamic>.from(values[0] as Map),
    entries: List<Map<String, dynamic>>.from(values[1] as List),
    generatedAt: DateTime.now(),
    start: start,
    end: end,
  );
}
