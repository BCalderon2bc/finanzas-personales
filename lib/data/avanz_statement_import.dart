import 'period_logic.dart';

typedef AvanzAmounts = ({int minimum, int? overdue, int balance});
typedef AvanzStatement = ({
  DateTime closing,
  DateTime? bonus,
  DateTime due,
  String? cardEnding,
  Map<String, AvanzAmounts> amounts,
});

AvanzStatement? parseAvanzStatement(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll(RegExp(r'[\s\u00a0]+'), ' ');
  if (!normalized.contains('avanzbanc.com')) return null;

  const day = r'(\d{2}/\d{2}/\d{4})';
  const amount = r'((?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2})';
  final header = RegExp(
    'fecha de corte $day (?:fecha de pago para bonificar $day )?'
    'fecha maxima de pago $day cordobas dolares '
    'pago minimo $amount $amount (?:pago atrasado $amount $amount )?'
    'pago de contado $amount $amount(?![0-9.,])',
  ).firstMatch(normalized);
  if (header == null) return null;

  DateTime? date(String? value) {
    if (value == null) return null;
    final parts = value.split('/').map(int.parse).toList();
    final result = DateTime(parts[2], parts[1], parts[0]);
    return result.year >= 1900 &&
            result.year <= 2200 &&
            result.month == parts[1] &&
            result.day == parts[0]
        ? result
        : null;
  }

  int? cents(int index) {
    final value = header.group(index);
    return value == null
        ? null
        : int.tryParse(value.replaceAll(RegExp(r'[,.]'), ''));
  }

  final closing = date(header.group(1));
  final bonus = date(header.group(2));
  final due = date(header.group(3));
  if (closing == null ||
      due == null ||
      due.isBefore(closing) ||
      (header.group(2) != null &&
          (bonus == null || !includesDay(bonus, closing, due)))) {
    return null;
  }
  final amounts = <String, AvanzAmounts>{};
  for (var i = 0; i < 2; i++) {
    final minimum = cents(4 + i),
        overdue = cents(6 + i),
        balance = cents(8 + i);
    if (minimum == null ||
        balance == null ||
        minimum > balance ||
        balance > 99999999999999 ||
        (header.group(6 + i) != null &&
            (overdue == null || overdue > 99999999999999))) {
      return null;
    }
    amounts[i == 0 ? 'NIO' : 'USD'] = (
      minimum: minimum,
      overdue: overdue,
      balance: balance,
    );
  }
  final cardEnding = RegExp(
    r'no\. de tarjeta\s+[0-9* x]*[*x]\s*(\d{4})(?!\d)',
  ).firstMatch(normalized)?.group(1);
  return (
    closing: closing,
    bonus: bonus,
    due: due,
    cardEnding: cardEnding,
    amounts: amounts,
  );
}
