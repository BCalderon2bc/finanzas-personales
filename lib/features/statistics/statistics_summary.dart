import '../../data/exchange_rate.dart';
import '../../data/export_report_models.dart';

class StatisticsSummary {
  StatisticsSummary({
    required Iterable<ExportMovement> movements,
    required Map<String, String> categories,
    required DateTime start,
    required DateTime end,
    required String currency,
    required ExchangeRate rate,
  }) {
    final first = _day(start), last = _day(end);
    dayCount = last.difference(first).inDays + 1;
    final byCategory = <String, int>{};
    final incomeByCategory = <String, int>{};
    for (final row in movements) {
      if (row.income == 0 && row.expense == 0) {
        continue;
      }
      final day = _day(row.date);
      if (day.isBefore(first) || day.isAfter(last)) continue;
      movementCount++;
      final rowIncome = rate.convert(row.income, row.currency, currency);
      final rowExpense = rate.convert(row.expense, row.currency, currency);
      final name = categories[row.categoryId] ?? 'Sin categoría';
      if (row.income > 0) {
        incomeCount++;
        if (rowIncome > 0)
          incomeByCategory.update(
            name,
            (value) => value + rowIncome,
            ifAbsent: () => rowIncome,
          );
      }
      income += rowIncome;
      netExpenses += rowExpense;
      if (row.expense < 0) refunds -= rowExpense;
      if (row.expense > 0) {
        grossExpenses += rowExpense;
        expenseCount++;
        if (rowExpense > largestExpense) largestExpense = rowExpense;
        if (rowExpense > 0)
          byCategory.update(
            name,
            (amount) => amount + rowExpense,
            ifAbsent: () => rowExpense,
          );
      }
    }
    expenseCategories = _rank(byCategory);
    incomeCategories = _rank(incomeByCategory);
  }

  int income = 0, netExpenses = 0, grossExpenses = 0, refunds = 0;
  int movementCount = 0, incomeCount = 0, expenseCount = 0, largestExpense = 0;
  late final int dayCount;
  int get dailyNetExpense => (netExpenses / dayCount).round();
  late final List<MapEntry<String, int>> incomeCategories;

  static List<MapEntry<String, int>> _rank(Map<String, int> values) =>
      values.entries.toList()..sort((a, b) {
        final amount = b.value.compareTo(a.value);
        return amount == 0 ? a.key.compareTo(b.key) : amount;
      });
  int get balance => income - netExpenses;
  late final List<MapEntry<String, int>> expenseCategories;

  static DateTime _day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}
