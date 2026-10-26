import '../credit_cards/credit_card_balances.dart';
import 'dashboard_period.dart';
export 'dashboard_period.dart';

enum DashboardTarget {
  accounts,
  transactions,
  categories,
  budgets,
  debts,
  cards,
  reports,
}

class DashboardCurrency {
  int cash = 0;
  int income = 0;
  int expense = 0;
  int previousIncome = 0;
  int previousExpense = 0;
  int loans = 0;
  int overdue = 0;
  int dueToday = 0;
  int overdueCount = 0;
  int todayCount = 0;
  int cardDebt = 0;
  int cardCredit = 0;
  int activeAccounts = 0;
  int? cardAvailable = 0;
  int exceededBudgets = 0;
  int movements = 0;
  bool cardKnown = true;

  final categories = <String, int>{};

  int get net => income - expense;
  int get previousNet => previousIncome - previousExpense;
  int? get liabilities => cardKnown ? loans + cardDebt : null;
  int? get position => cardKnown ? cash + cardCredit - loans - cardDebt : null;
}

class DashboardEvent {
  const DashboardEvent(
    this.id,
    this.date,
    this.title,
    this.detail,
    this.currency,
    this.cents,
    this.flow,
    this.target, [
    this.entityId,
    this.categoryId,
  ]);

  final String id;
  final DateTime date;
  final String title;
  final String detail;
  final String currency;
  final int cents;
  final int flow;
  final DashboardTarget target;
  final String? entityId;
  final String? categoryId;
}

class DashboardOverview {
  DashboardOverview(this.month, {DashboardPeriod? period, DateTime? loadedAt})
    : period = period ?? DashboardPeriod.forMonth(month),
      loadedAt = loadedAt ?? DateTime.now();

  final DateTime month;
  final DateTime loadedAt;
  final DashboardPeriod period;

  final currencies = {'NIO': DashboardCurrency(), 'USD': DashboardCurrency()};

  final categoryNames = <String, String>{};
  final categoryStyles = <String, Map<String, dynamic>>{};
  final accounts = <Map<String, dynamic>>[];
  final budgets = <Map<String, dynamic>>[];
  final events = <DashboardEvent>[];
}

String dashboardMoney(int? cents, String currency) =>
    cardMoney(cents, currency);

String dashboardMonth(DateTime date) {
  const names = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  return '${names[date.month - 1]} ${date.year}';
}
