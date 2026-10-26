import '../utils/money.dart';

DateTime calendarDay(DateTime value) => DateTime.utc(value.year,value.month,value.day);
DateTime? statementDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? null : DateTime(date.year,date.month,date.day);
}
String shortStatementDate(dynamic value) {
  final d = statementDate(value);
  return d == null ? 'Sin fecha' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}
int daysUntil(DateTime date, DateTime today) => calendarDay(date).difference(calendarDay(today)).inDays;
DateTime nextCalendarDay(int day, DateTime today) {
  DateTime inMonth(int y,int m) {
    final last = DateTime(y,m+1,0).day;
    return DateTime(y,m,day.clamp(1,last).toInt());
  }
  final current = inMonth(today.year,today.month);
  return daysUntil(current,today) >= 0 ? current : inMonth(today.year,today.month+1);
}

class StatementProgress {
  const StatementProgress({required this.statement, required this.paid,
    required this.remaining, required this.minimumRemaining, required this.known});
  final Map<String,dynamic> statement;
  final int paid;
  final int? remaining, minimumRemaining;
  final bool known;
  int get balance => moneyCents(statement['balance_due']);
  int get excessLinked => paid > balance ? paid-balance : 0;
  bool get settled => known && remaining == 0;
}

StatementProgress calculateStatementProgress(Map<String,dynamic> statement,
    List<Map<String,dynamic>> links,List<Map<String,dynamic>> payments) {
  final byId = {for(final p in payments) '${p['id']}':p};
  var paid=0,known=true;
  final seen=<String>{};
  for(final link in links) {
    if('${link['statement_id']}' != '${statement['id']}') { continue; }
    final id='${link['payment_id']}';
    if(!seen.add(id)) { continue; }
    final p=byId[id];
    if(p == null) { known=false; continue; }
    if(p['is_voided'] == true) { continue; }
    if(p['transaction_type'] != 'payment' || p['currency'] != statement['currency'] ||
        '${p['credit_card_id']}' != '${statement['credit_card_id']}') {
      known=false; continue;
    }
    paid += moneyCents(p['amount']);
  }
  final balance=moneyCents(statement['balance_due']);
  final minimum=statement['minimum_due'] == null ? null : moneyCents(statement['minimum_due']);
  return StatementProgress(statement:statement,paid:paid,known:known,
    remaining:known ? (balance-paid).clamp(0,balance).toInt() : null,
    minimumRemaining:known && minimum != null ? (minimum-paid).clamp(0,minimum).toInt() : null);
}

class CardStatementData {
  const CardStatementData({required this.statements,required this.links,required this.payments});
  final List<Map<String,dynamic>> statements,links,payments;
  StatementProgress progress(Map<String,dynamic> s) => calculateStatementProgress(s,links,payments);
  List<Map<String,dynamic>> currentFor(String cardId,{String? currency}) => statements.where((s) =>
    '${s['credit_card_id']}' == cardId && s['is_voided'] != true && s['is_archived'] != true &&
    (currency == null || s['currency'] == currency)).toList()
    ..sort((a,b) => '${a['currency']}'.compareTo('${b['currency']}'));
  List<Map<String,dynamic>> payableFor(String cardId,String currency) => currentFor(cardId,currency:currency)
    .where((s) { final p=progress(s); return p.known && !p.settled; }).toList();
}
