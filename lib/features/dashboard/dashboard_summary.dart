import '../../utils/money.dart';

class CurrencySummary {
  int balance = 0, income = 0, expense = 0;
  int get net => income - expense;
}
class DashboardSummary {
  DashboardSummary(this.currencies, this.recent, this.accountNames, this.month);
  final Map<String, CurrencySummary> currencies;
  final List<Map<String, dynamic>> recent;
  final Map<String, String> accountNames;
  final DateTime month;


  factory DashboardSummary.calculate(List<Map<String, dynamic>> accounts,
      List<Map<String, dynamic>> transactions, DateTime now, {
        List<Map<String, dynamic>> cardExpenses = const [],
        List<Map<String, dynamic>> cardPayments = const [],
        List<Map<String, dynamic>> debtPayments = const [],
      }) {
    final totals = {'NIO': CurrencySummary(), 'USD': CurrencySummary()};
    final balances = calculateBalances(
      accounts, transactions, cardPayments: cardPayments, debtPayments: debtPayments,
    );
    final names = <String, String>{};
    for (final account in accounts) {
      final id = account['id'].toString();
      names[id] = account['name']?.toString() ?? 'Cuenta';
      if (account['is_active'] == true) {
        final total = totals[account['currency']];
        if (total != null) total.balance += balances[id] ?? 0;
      }
    }
    final dated = <MapEntry<DateTime, Map<String, dynamic>>>[];
    for (final tx in transactions) {
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      if (date == null) throw FormatException('Un movimiento tiene una fecha inválida.');
      dated.add(MapEntry(date, tx));
      if (date.year != now.year || date.month != now.month) continue;
      final total = totals[tx['currency']];
      if (total == null) continue;
      if (tx['transaction_type'] == 'income') total.income += moneyCents(tx['amount']);
      if (tx['transaction_type'] == 'expense') total.expense += moneyCents(tx['amount']);
    }
    for (final expense in cardExpenses) {
      final date = DateTime.tryParse('${expense['transaction_date']}')?.toLocal();
      if (date == null) throw FormatException('Un movimiento de tarjeta tiene una fecha inválida.');
      if (date.year != now.year || date.month != now.month) continue;
      final total = totals[expense['currency']];
      if (total != null) total.expense += moneyCents(expense['amount']);
    }
    for (final payment in debtPayments) {
      final date = DateTime.tryParse('${payment['payment_date']}')?.toLocal();
      if (date == null) throw FormatException('Un abono tiene una fecha inválida.');
      if (date.year != now.year || date.month != now.month) continue;
      final total = totals[payment['currency']];
      if (total != null) {
        total.expense += moneyCents(payment['interest_amount']) + moneyCents(payment['fee_amount']);
      }
    }
    dated.sort((a, b) {
      final byDate = b.key.compareTo(a.key);
      return byDate != 0 ? byDate : a.value['id'].toString().compareTo(b.value['id'].toString());
    });
    return DashboardSummary(totals, dated.take(5).map((e) => e.value).toList(), names, DateTime(now.year, now.month));
  }
}
String formatMoney(int cents, String currency) => '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';
