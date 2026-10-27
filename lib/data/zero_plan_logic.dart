import '../utils/money.dart';

String zeroDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String zeroDateLabel(dynamic value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  return d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

DateTime zeroMonthlyDate(DateTime first, int offset) => DateTime(
  first.year,
  first.month + offset,
  first.day
      .clamp(1, DateTime(first.year, first.month + offset + 1, 0).day)
      .toInt(),
);
List<int> zeroSplit(int total, int count, {int? monthly}) {
  if (count < 1 || count > 120 || total <= 0)
    throw ArgumentError('Plan inválido.');
  final quota = monthly ?? total ~/ count, last = total - quota * (count - 1);
  if (quota <= 0 || last <= 0)
    throw ArgumentError('La cuota mensual no corresponde al monto y al plazo.');
  return List.generate(count, (i) => i == count - 1 ? last : quota);
}

class ZeroPlanData {
  const ZeroPlanData({
    required this.plans,
    required this.installments,
    required this.allocations,
    required this.transactions,
  });
  final List<Map<String, dynamic>> plans,
      installments,
      allocations,
      transactions;
  List<Map<String, dynamic>> forPlan(String id) =>
      installments.where((i) => i['plan_id'] == id).toList()
        ..sort((a, b) => (a['number'] as num).compareTo(b['number'] as num));
  Map<String, dynamic>? payment(dynamic id) =>
      transactions.where((t) => t['id'] == id).firstOrNull;
  bool live(Map<String, dynamic> a) =>
      a['is_removed'] != true &&
      payment(a['payment_id'])?['is_voided'] == false;
  int paid(Map<String, dynamic> i) => i['historical_paid'] == true
      ? moneyCents(i['amount'])
      : allocations
            .where((a) => a['installment_id'] == i['id'] && live(a))
            .fold<int>(0, (s, a) => s + moneyCents(a['amount']));
  int remaining(Map<String, dynamic> i) => (moneyCents(i['amount']) - paid(i))
      .clamp(0, moneyCents(i['amount']))
      .toInt();
  int pending(String id) =>
      forPlan(id).fold<int>(0, (s, i) => s + remaining(i));
  int unassigned(Map<String, dynamic> p) =>
      (moneyCents(p['amount']) -
              allocations
                  .where((a) => a['payment_id'] == p['id'] && live(a))
                  .fold<int>(0, (s, a) => s + moneyCents(a['amount'])))
          .clamp(0, moneyCents(p['amount']))
          .toInt();
}
