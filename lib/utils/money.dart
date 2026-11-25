/// Historical API name retained; values now use millionths, not cents.
const int moneyScale = 1000000;
const int maxExactMoneyUnits = 9007199254740991;

int moneyCents(dynamic value) {
  var text = '$value'.trim().replaceAll(',', '.');
  if (text.contains(RegExp(r'[eE]'))) {
    final n = num.tryParse(text);
    if (n == null || !n.isFinite)
      throw FormatException('Monto inválido: $value');
    final fixed = n.toStringAsFixed(6);
    if (num.tryParse(fixed) != n) {
      throw FormatException('Usa hasta seis decimales: $value');
    }
    text = fixed;
  }
  if (!RegExp(r'^-?\d+(\.\d{1,6})?$').hasMatch(text)) {
    throw FormatException('Monto inválido; usa hasta seis decimales: $value');
  }
  final negative = text.startsWith('-');
  final parts = (negative ? text.substring(1) : text).split('.');
  final whole = BigInt.parse(parts[0]);
  final fraction = BigInt.parse(
    parts.length == 1 ? '0' : parts[1].padRight(6, '0'),
  );
  final units = whole * BigInt.from(moneyScale) + fraction;
  if (units > BigInt.from(maxExactMoneyUnits)) {
    throw FormatException('El monto excede el rango de precisión admitido.');
  }
  return (negative ? -units : units).toInt();
}

Map<String, int> calculateBalances(
  List<Map<String, dynamic>> accounts,
  List<Map<String, dynamic>> transactions, {
  List<Map<String, dynamic>> cardPayments = const [],
  List<Map<String, dynamic>> debtPayments = const [],
}) {
  final balances = <String, int>{
    for (final a in accounts)
      a['id'].toString(): moneyCents(a['opening_balance']),
  };
  for (final tx in transactions) {
    final type = tx['transaction_type'];
    // El esquema no indica la dirección de un ajuste; no inventar su efecto.
    if (type == 'adjustment') {
      throw StateError(
        'Hay ajustes registrados. Debemos definir su efecto antes de calcular el saldo.',
      );
    }
    final origin = tx['account_id'].toString();
    final destination = tx['destination_account_id']?.toString();
    final amount = moneyCents(tx['amount']);
    if (balances.containsKey(origin)) {
      switch (type) {
        case 'income':
        case 'deposit':
          balances[origin] = balances[origin]! + amount;
          break;
        case 'expense':
        case 'withdrawal':
        case 'transfer':
          balances[origin] = balances[origin]! - amount;
          break;
        default:
          throw StateError('Tipo de movimiento desconocido: $type');
      }
    }
    if (type == 'transfer' && balances.containsKey(destination)) {
      balances[destination!] =
          balances[destination]! +
          moneyCents(tx['destination_amount'] ?? tx['amount']);
    }
  }
  final currencies = {
    for (final account in accounts)
      account['id'].toString(): account['currency'],
  };
  for (final payment in cardPayments) {
    final accountId = payment['account_id']?.toString();
    if (!balances.containsKey(accountId)) continue;
    if (currencies[accountId] !=
        (payment['account_debit_currency'] ?? payment['currency'])) {
      throw StateError(
        'La moneda del débito del pago no coincide con su cuenta.',
      );
    }
    balances[accountId!] =
        balances[accountId]! -
        moneyCents(payment['account_debit_amount'] ?? payment['amount']);
  }
  for (final payment in debtPayments) {
    final accountId = payment['account_id']?.toString();
    if (!balances.containsKey(accountId)) continue;
    if (currencies[accountId] != payment['currency']) {
      throw StateError(
        'Un abono de deuda tiene una moneda diferente a su cuenta.',
      );
    }
    balances[accountId!] =
        balances[accountId]! - debtPaymentTotalCents(payment);
  }
  return balances;
}

int debtPaymentTotalCents(Map<String, dynamic> payment) =>
    moneyCents(payment['principal_amount']) +
    moneyCents(payment['interest_amount']) +
    moneyCents(payment['fee_amount']);

// Amounts are stored in millionths. Round only after summing, for display.
// Round to the nearest cent; exact halves round away from zero.
int totalUnitsRounded(int units) {
  const unitsPerCent = moneyScale ~/ 100;
  final absolute = units.abs();
  final cents = absolute ~/ unitsPerCent;
  final remainder = absolute % unitsPerCent;
  final rounded =
      (cents + (remainder >= unitsPerCent ~/ 2 ? 1 : 0)) * unitsPerCent;
  return units < 0 ? -rounded : rounded;
}

String formatAmountCents(int cents) =>
    formatRecordAmountCents(totalUnitsRounded(cents));

String formatRecordAmountCents(int cents) {
  final absolute = cents.abs();
  final whole = (absolute ~/ moneyScale).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  var decimals = (absolute % moneyScale).toString().padLeft(6, '0');
  while (decimals.length > 2 && decimals.endsWith('0')) {
    decimals = decimals.substring(0, decimals.length - 1);
  }

  return '${cents < 0 ? '-' : ''}$whole.$decimals';
}

String formatMoneyCents(int? cents, String currency) {
  if (cents == null) {
    return 'Por revisar';
  }

  final symbol = currency == 'USD' ? '\$' : 'C\$';
  return '$symbol${formatAmountCents(cents)}';
}

// Individual records retain their original precision (up to six decimals).
String formatRecordMoneyCents(int? cents, String currency) {
  if (cents == null) return 'Por revisar';
  final symbol = currency == 'USD' ? r'$' : r'C$';
  return '$symbol${formatRecordAmountCents(cents)}';
}
