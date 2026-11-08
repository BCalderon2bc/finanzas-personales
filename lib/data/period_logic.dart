import '../utils/money.dart';

String isoDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool includesDay(DateTime date, DateTime start, DateTime end) =>
    !dayOnly(date).isBefore(dayOnly(start)) &&
    !dayOnly(date).isAfter(dayOnly(end));

DateTime budgetStart(Map<String, dynamic> budget) =>
    DateTime.parse('${budget['start_date'] ?? budget['month']}');

DateTime budgetEnd(Map<String, dynamic> budget) {
  final value = budget['end_date'];
  if (value != null) return DateTime.parse('$value');
  final start = budgetStart(budget);
  return DateTime(start.year, start.month + 1, 0);
}

int budgetSpent(
  Map<String, dynamic> budget,
  Iterable<Map<String, dynamic>> expenses,
) {
  final start = budgetStart(budget), end = budgetEnd(budget);
  var total = 0;
  for (final tx in expenses) {
    if (tx['is_voided'] == true ||
        tx['transaction_type'] != 'expense' ||
        tx['category_id'] != budget['category_id'] ||
        tx['currency'] != budget['currency'])
      continue;
    final date = DateTime.parse('${tx['transaction_date']}').toLocal();
    if (includesDay(date, start, end)) total += moneyCents(tx['amount']);
  }
  return total;
}

bool recurringInMonth(Map<String, dynamic> expense, DateTime month) {
  final start = DateTime.parse('${expense['starts_on']}');
  final end = expense['ends_on'] == null
      ? null
      : DateTime.parse('${expense['ends_on']}');
  return expense['is_active'] == true &&
      !start.isAfter(DateTime(month.year, month.month + 1, 0)) &&
      (end == null || !end.isBefore(DateTime(month.year, month.month)));
}

DateTime recurringDue(Map<String, dynamic> expense, DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0).day;
  final day = int.parse('${expense['due_day']}').clamp(1, last);
  return DateTime(month.year, month.month, day);
}
