import '../utils/money.dart';

/// Positive: I owe the person. Negative: the person owes me.
int personAccountBalance(Iterable<Map<String, dynamic>> entries) {
  var total = 0;
  for (final row in entries) {
    if (row['is_voided'] == true) continue;
    final direction = int.tryParse('${row['direction']}');
    if (direction != 1 && direction != -1) {
      throw StateError('Un movimiento tiene un signo inválido.');
    }
    final cents = moneyCents(row['amount_nio']);
    if (cents <= 0)
      throw StateError('Un movimiento tiene un importe inválido.');
    total += cents * direction!;
    if (total.abs() > 9007199254740991) {
      throw StateError('El saldo excede el rango de precisión.');
    }
  }
  return total;
}

String personBalanceLabel(int cents) => cents > 0
    ? 'Le debes'
    : cents < 0
    ? 'Te debe'
    : 'Están a mano';

String personEntryLabel(Map<String, dynamic> row) {
  final plus = row['direction'].toString() == '1';
  return switch (row['kind']) {
    'payment' => plus ? 'Te pagó (+)' : 'Tú pagaste (−)',
    'opening' =>
      plus ? 'Saldo anterior: le debías (+)' : 'Saldo anterior: te debía (−)',
    _ => plus ? 'Compra de la otra persona (+)' : 'Compra tuya (−)',
  };
}
