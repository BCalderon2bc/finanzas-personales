import '../../data/exchange_rate.dart';
import 'dashboard_overview.dart';

/// Crea una vista equivalente. Nunca modifica los registros ni el original.
DashboardOverview convertDashboard(
  DashboardOverview source,
  String target,
  ExchangeRate rate,
) {
  final result = DashboardOverview(
    source.month,
    period: source.period,
    loadedAt: source.loadedAt,
  );
  final total = result.currencies[target];
  if (total == null) {
    throw ArgumentError('Moneda de presentación inválida.');
  }
  result.categoryNames.addAll(source.categoryNames);
  result.categoryStyles.addAll(source.categoryStyles);

  for (final entry in source.currencies.entries) {
    final c = entry.value;
    int convert(int value) => rate.convert(value, entry.key, target);
    total.cash += convert(c.cash);
    total.income += convert(c.income);
    total.expense += convert(c.expense);
    total.previousIncome += convert(c.previousIncome);
    total.previousExpense += convert(c.previousExpense);
    total.loans += convert(c.loans);
    total.overdue += convert(c.overdue);
    total.dueToday += convert(c.dueToday);
    total.cardDebt += convert(c.cardDebt);
    total.cardCredit += convert(c.cardCredit);
    total.cardAvailable = total.cardAvailable == null || c.cardAvailable == null
        ? null
        : total.cardAvailable! + convert(c.cardAvailable!);
    total.cardKnown = total.cardKnown && c.cardKnown;
    total.overdueCount += c.overdueCount;
    total.todayCount += c.todayCount;
    total.activeAccounts += c.activeAccounts;
    total.exceededBudgets += c.exceededBudgets;
    total.movements += c.movements;
    for (final category in c.categories.entries) {
      total.categories[category.key] =
          (total.categories[category.key] ?? 0) + convert(category.value);
    }
  }
  for (final account in source.accounts) {
    final currency = account['currency'].toString();
    result.accounts.add({
      ...account,
      'currency': target,
      'balance_cents': rate.convert(
        account['balance_cents'] as int,
        currency,
        target,
      ),
    });
  }
  for (final budget in source.budgets) {
    final currency = budget['currency'].toString();
    result.budgets.add({
      ...budget,
      'name': '${budget['name']} · $currency',
      'currency': target,
      'limit_cents': rate.convert(
        budget['limit_cents'] as int,
        currency,
        target,
      ),
      'spent_cents': rate.convert(
        budget['spent_cents'] as int,
        currency,
        target,
      ),
    });
  }
  for (final event in source.events) {
    final original = event.currency == target
        ? ''
        : ' · Original: ${dashboardMoney(event.cents, event.currency)}';
    result.events.add(
      DashboardEvent(
        event.id,
        event.date,
        event.title,
        '${event.detail}$original',
        target,
        rate.convert(event.cents, event.currency, target),
        event.flow,
        event.target,
        event.entityId,
        event.categoryId,
      ),
    );
  }
  result.accounts.sort(
    (a, b) => (b['balance_cents'] as int).compareTo(a['balance_cents'] as int),
  );
  return result;
}
