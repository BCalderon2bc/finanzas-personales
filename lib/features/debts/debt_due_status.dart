import '../../utils/money.dart';

enum DebtDueStatus { none, today, overdue }

DebtDueStatus debtDueStatus(Map<String, dynamic> debt, int principalPaid, DateTime now) {
  if (!['active', 'overdue'].contains(debt['status'])) return DebtDueStatus.none;
  if (moneyCents(debt['original_amount']) - principalPaid <= 0) return DebtDueStatus.none;
  final due = DateTime.tryParse('${debt['due_date']}');
  if (due == null) return DebtDueStatus.none;
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  if (dueDay.isBefore(today)) return DebtDueStatus.overdue;
  if (dueDay == today) return DebtDueStatus.today;
  return DebtDueStatus.none;
}