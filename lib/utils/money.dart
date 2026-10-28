int moneyCents(dynamic value) {
  final amount = num.tryParse('$value');
  if (amount == null || !amount.isFinite) {
    throw FormatException('Monto inválido: $value');
  }
  return (amount * 100).round();
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
      balances[destination!] = balances[destination]! + amount;
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

String formatAmountCents(int cents) {
  final absolute = cents.abs();
  final whole = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final decimals = (absolute % 100).toString().padLeft(2, '0');

  return '${cents < 0 ? '-' : ''}$whole.$decimals';
}

String formatMoneyCents(int? cents, String currency) {
  if (cents == null) {
    return 'Por revisar';
  }

  final symbol = currency == 'USD' ? 'US\$' : 'C\$';
  return '$symbol ${formatAmountCents(cents)}';
}
