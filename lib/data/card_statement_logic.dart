import '../utils/money.dart';

DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
DateTime? statementDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? null : DateTime(date.year, date.month, date.day);
}

String shortStatementDate(dynamic value) {
  final d = statementDate(value);
  return d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

int daysUntil(DateTime date, DateTime today) =>
    calendarDay(date).difference(calendarDay(today)).inDays;
DateTime nextCalendarDay(int day, DateTime today) {
  DateTime inMonth(int y, int m) {
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day.clamp(1, last).toInt());
  }

  final current = inMonth(today.year, today.month);
  return daysUntil(current, today) >= 0
      ? current
      : inMonth(today.year, today.month + 1);
}

bool isCurrentStatement(Map<String, dynamic> row) =>
    row['is_archived'] != true && row['is_voided'] != true;

/// Pairs separately saved currencies when they describe the same cut.
/// Each row keeps its own ID for payments, edits and existing documents.
List<List<Map<String, dynamic>>> groupCardStatements(
  Iterable<Map<String, dynamic>> rows,
) {
  final documents = <(Object?, Object?), List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final key = (row['credit_card_id'], row['statement_group_id'] ?? row['id']);
    documents.putIfAbsent(key, () => []).add(row);
  }

  final result = <List<Map<String, dynamic>>>[];
  final byDates =
      <(Object?, Object?, Object?, Object?), List<Map<String, dynamic>>>{};
  for (final group in documents.values) {
    final row = group.first;
    if (group.length != 1 ||
        row['is_voided'] == true ||
        (row['currency'] != 'NIO' && row['currency'] != 'USD')) {
      result.add(group);
      continue;
    }
    final dates = (
      row['credit_card_id'],
      row['closing_date'],
      row['due_date'],
      row['bonus_payment_date'],
    );
    byDates.putIfAbsent(dates, () => []).add(row);
  }
  for (final candidates in byDates.values) {
    if (candidates.length == 2 &&
        candidates.first['currency'] != candidates.last['currency']) {
      result.add(candidates);
    } else {
      result.addAll(candidates.map((row) => [row]));
    }
  }
  for (final group in result) {
    group.sort((a, b) => '${a['currency']}'.compareTo('${b['currency']}'));
  }
  result.sort((a, b) {
    final byDate = '${b.first['closing_date']}'.compareTo(
      '${a.first['closing_date']}',
    );
    return byDate == 0
        ? '${a.first['id']}'.compareTo('${b.first['id']}')
        : byDate;
  });
  return result;
}

class StatementProgress {
  const StatementProgress({
    required this.statement,
    required this.paid,
    required this.remaining,
    required this.minimumRemaining,
    required this.known,
    this.balanceCredit = 0,
    this.minimumCredit = 0,
  });
  final Map<String, dynamic> statement;
  final int paid;
  final int balanceCredit, minimumCredit;
  final int? remaining, minimumRemaining;
  final bool known;
  int get balance => moneyCents(statement['balance_due']);
  int get adjustedBalance =>
      (balance - balanceCredit).clamp(0, balance).toInt();
  int get excessLinked => paid > adjustedBalance ? paid - adjustedBalance : 0;
  bool get settled => known && remaining == 0;
}

StatementProgress calculateStatementProgress(
  Map<String, dynamic> statement,
  List<Map<String, dynamic>> links,
  List<Map<String, dynamic>> payments, [
  List<Map<String, dynamic>> credits = const [],
]) {
  final byId = {for (final p in payments) '${p['id']}': p};
  var paid = 0, known = true;
  final seen = <String>{};
  for (final link in links) {
    if ('${link['statement_id']}' != '${statement['id']}') {
      continue;
    }
    final id = '${link['payment_id']}';
    if (!seen.add(id)) {
      continue;
    }
    final p = byId[id];
    if (p == null) {
      known = false;
      continue;
    }
    if (p['is_voided'] == true) {
      continue;
    }
    if (p['transaction_type'] != 'payment' ||
        p['currency'] != statement['currency'] ||
        '${p['credit_card_id']}' != '${statement['credit_card_id']}') {
      known = false;
      continue;
    }
    paid += moneyCents(p['amount']);
  }
  var balanceCredit = 0, minimumCredit = 0;
  final seenRefunds = <String>{};
  for (final c in credits) {
    if (c['is_removed'] == true ||
        '${c['statement_id']}' != '${statement['id']}')
      continue;
    final t = byId['${c['refund_id']}'];
    if (t == null) {
      known = false;
      continue;
    }
    if (t['is_voided'] == true) continue;
    final b = moneyCents(c['balance_credit']),
        m = moneyCents(c['minimum_credit']);
    if (!seenRefunds.add('${t['id']}') ||
        t['transaction_type'] != 'refund' ||
        t['currency'] != statement['currency'] ||
        '${t['credit_card_id']}' != '${statement['credit_card_id']}' ||
        b < 0 ||
        m < 0 ||
        b > moneyCents(t['amount']) ||
        m > moneyCents(t['amount'])) {
      known = false;
      continue;
    }
    balanceCredit += b;
    minimumCredit += m;
  }
  final balance = moneyCents(statement['balance_due']);
  final minimum = statement['minimum_due'] == null
      ? null
      : moneyCents(statement['minimum_due']);
  if (balanceCredit > balance ||
      (minimumCredit > 0 && (minimum == null || minimumCredit > minimum)))
    known = false;
  return StatementProgress(
    statement: statement,
    paid: paid,
    known: known,
    balanceCredit: balanceCredit,
    minimumCredit: minimumCredit,
    remaining: known
        ? (balance - balanceCredit - paid).clamp(0, balance).toInt()
        : null,
    minimumRemaining: known && minimum != null
        ? (minimum - minimumCredit - paid).clamp(0, minimum).toInt()
        : null,
  );
}

class CardStatementData {
  const CardStatementData({
    required this.statements,
    required this.links,
    required this.payments,
    this.credits = const [],
  });
  final List<Map<String, dynamic>> statements, links, payments;
  final List<Map<String, dynamic>> credits;
  StatementProgress progress(Map<String, dynamic> s) =>
      calculateStatementProgress(s, links, payments, credits);
  List<Map<String, dynamic>> currentFor(String cardId, {String? currency}) =>
      statements
          .where(
            (s) =>
                '${s['credit_card_id']}' == cardId &&
                s['is_voided'] != true &&
                s['is_archived'] != true &&
                (currency == null || s['currency'] == currency),
          )
          .toList()
        ..sort((a, b) => '${a['currency']}'.compareTo('${b['currency']}'));
  List<Map<String, dynamic>> payableFor(String cardId, String currency) =>
      currentFor(cardId, currency: currency).where((s) {
        final p = progress(s);
        return p.known && !p.settled;
      }).toList();
}
