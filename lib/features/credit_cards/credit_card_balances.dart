import '../../utils/money.dart';
import '../../utils/card_cash_advance.dart';

const cardCurrencies = ['NIO', 'USD'];
const cardEffects = {
  'purchase': 1,
  'interest': 1,
  'fee': 1,
  'payment': -1,
  'refund': -1,
};

const cardPointsRedemption = 'points_redemption';
const cardPointsRedemptionLabel = 'Redención de puntos';

String cardMovementType(Object? transactionType, Object? chargeKind) =>
    switch (chargeKind) {
      'insurance' => 'insurance',
      cardPointsRedemption => cardPointsRedemption,
      _ => transactionType.toString(),
    };

String cardMoney(int? cents, String currency) =>
    formatMoneyCents(cents, currency);

int cardOpening(Map<String, dynamic> card, String currency) {
  final value = card['opening_balance_${currency.toLowerCase()}'];
  if (value != null) {
    return moneyCents(value);
  }
  return card['currency'] == currency
      ? moneyCents(card['opening_balance'] ?? 0)
      : 0;
}

int? cardBalance(
  Map<String, dynamic> card,
  Iterable<Map<String, dynamic>> transactions,
  String currency, {
  bool forLimit = false,
}) {
  var balance = cardOpening(card, currency);
  for (final tx in transactions) {
    if (tx['credit_card_id'].toString() != card['id'].toString() ||
        tx['is_voided'] == true) {
      continue;
    }
    if (!cardCurrencies.contains(tx['currency'])) {
      return null;
    }
    if (tx['currency'] != currency) {
      continue;
    }
    final effect = cardEffects[tx['transaction_type']];
    if (effect == null) {
      return null;
    }
    var amount = moneyCents(tx['amount']);
    if (forLimit && tx['excludes_from_limit'] == true) {
      if (isCardCashAdvance(tx)) {
        amount -= cardCashAdvanceFee(tx);
      } else if (tx['transaction_type'] == 'interest' ||
          tx['transaction_type'] == 'fee') {
        continue;
      }
    }
    balance += effect * amount;
  }
  return balance;
}

// Estimación del uso del único límite. Los saldos a favor no compensan otra moneda.
int? cardLimitUsed(Map<String, dynamic> card, int? nio, int? usd) {
  if (nio == null || usd == null) {
    return null;
  }
  final n = nio > 0 ? nio : 0;
  final u = usd > 0 ? usd : 0;
  final base = card['currency'].toString();
  final foreign = base == 'USD' ? n : u;
  if (foreign == 0) {
    return base == 'USD' ? u : n;
  }
  final rate = double.tryParse('${card['limit_exchange_rate']}');
  if (rate == null || !rate.isFinite || rate <= 0) {
    return null;
  }
  final converted = base == 'USD' ? n / rate : u * rate;
  if (!converted.isFinite) {
    return null;
  }
  return (base == 'USD' ? u : n) + converted.round();
}

int? cardUsed(
  Map<String, dynamic> card,
  Iterable<Map<String, dynamic>> transactions,
) => cardLimitUsed(
  card,
  cardBalance(card, transactions, 'NIO', forLimit: true),
  cardBalance(card, transactions, 'USD', forLimit: true),
);

int? cardAvailable(Map<String, dynamic> card, int? used) {
  if (used == null) {
    return null;
  }
  final limit = moneyCents(card['credit_limit']);
  return (limit - used).clamp(0, limit).toInt();
}
