import '../../data/transaction_repository.dart';
import '../../core/supabase_client.dart';
import 'dashboard_models.dart';
import 'dashboard_aggregation.dart';
export 'dashboard_models.dart';

Future<List<Map<String, dynamic>>> _dashboardRows(
  String table,
  String columns,
  String userId,
) async {
  final rows = <Map<String, dynamic>>[];

  for (var offset = 0; ; offset += 500) {
    final result = await supabase
        .from(table)
        .select(columns)
        .eq('user_id', userId)
        .order('id')
        .range(offset, offset + 499);

    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);

    if (page.length < 500) {
      break;
    }
  }

  return rows;
}

Future<DashboardOverview> loadDashboardOverview(
  DateTime month, {
  DateTime? until,
}) async {
  final period = until == null
      ? DashboardPeriod.forMonth(month)
      : DashboardPeriod(month, until);
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw StateError('Debes iniciar sesión nuevamente.');
  }

  final rows = await Future.wait([
    _dashboardRows(
      'accounts',
      'id, name, account_type, currency, opening_balance, is_active',
      user.id,
    ),
    loadUserTransactions(user.id),
    _dashboardRows('categories', 'id, name, icon, color', user.id),
    _dashboardRows(
      'budgets',
      'id, category_id, currency, budget_amount, month',
      user.id,
    ),
    _dashboardRows(
      'debts',
      'id, description, currency, original_amount, status, due_date',
      user.id,
    ),
    _dashboardRows(
      'debt_payments',
      'id, debt_id, account_id, principal_amount, interest_amount, '
          'fee_amount, currency, payment_date, is_voided',
      user.id,
    ),
    _dashboardRows(
      'credit_cards',
      'id, name, currency, credit_limit, opening_balance, '
          'opening_balance_nio, opening_balance_usd, '
          'limit_exchange_rate, is_active',
      user.id,
    ),
    _dashboardRows(
      'credit_card_transactions',
      'id, credit_card_id, account_id, category_id, '
          'transaction_type, amount, currency, transaction_date, '
          'description, is_voided, is_receivable_funding, account_debit_amount, account_debit_currency, payment_exchange_rate',
      user.id,
    ),
  ]);

  if (supabase.auth.currentUser?.id != user.id) {
    throw StateError('La sesión cambió. Actualiza el panel.');
  }

  return buildDashboardOverview(period, rows: rows, today: DateTime.now());
}
