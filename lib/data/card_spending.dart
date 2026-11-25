import '../utils/money.dart';
import 'exchange_rate.dart';
import 'payment_agenda_labels.dart';
import '../utils/card_cash_advance.dart';
import 'period_logic.dart';

typedef CardSpending = ({
  String cardId,
  String label,
  String bank,
  String tier,
  ExchangeRate? cardExchangeRate,
  String currency,
  int cents,
});

/// Gastos de tarjeta vigentes, descontando devoluciones y sin sumar pagos.
int cardSpendingCents(Map<String, dynamic> movement) {
  if (movement['is_voided'] == true ||
      movement['is_receivable_funding'] == true) {
    return 0;
  }
  final type = movement['transaction_type'];
  if (type == 'refund') return -moneyCents(movement['amount']);

  // Los retiros de efectivo se reflejan como gasto únicamente por su comisión,
  // igual que en los reportes; el principal no es consumo de compra.
  if (isCardCashAdvance(movement)) return cardCashAdvanceFee(movement);

  return switch (type) {
    'purchase' || 'interest' || 'fee' => moneyCents(movement['amount']),
    _ => 0,
  };
}

List<CardSpending> cardSpendingForPeriod({
  required Iterable<Map<String, dynamic>> cards,
  required Iterable<Map<String, dynamic>> movements,
  required DateTime start,
  required DateTime end,
}) {
  final cardsById = {for (final card in cards) card['id'].toString(): card};
  final ratesByCardId = {
    for (final entry in cardsById.entries)
      entry.key: ExchangeRate.tryParse(
        entry.value['limit_exchange_rate']?.toString() ?? '',
      ),
  };
  final totals = <(String, String), int>{
    for (final id in cardsById.keys)
      for (final currency in ['NIO', 'USD']) (id, currency): 0,
  };
  for (final movement in movements) {
    final date = DateTime.tryParse(
      '${movement['transaction_date']}',
    )?.toLocal();
    if (date == null || !includesDay(date, start, end)) continue;
    final cardId = movement['credit_card_id']?.toString();
    final currency = movement['currency']?.toString();
    if (cardId == null || (currency != 'USD' && currency != 'NIO')) continue;
    final cents = cardSpendingCents(movement);
    if (cents == 0) continue;
    final key = (cardId, currency!);
    totals.update(key, (amount) => amount + cents, ifAbsent: () => cents);
  }
  return totals.entries.map((entry) {
    final (id, currency) = entry.key;
    final card = cardsById[id];
    final institution = card?['financial_institutions'];
    final tier = card?['card_tier']?.toString().trim().toLowerCase() ?? '';
    final product = card?['card_product']?.toString().toLowerCase() ?? '';
    return (
      cardId: id,
      label: card == null
          ? 'Tarjeta no disponible'
          : agendaCardLabel(card, includeName: false),
      bank: institution is Map ? institution['name']?.toString() ?? '' : '',
      tier: tier.isEmpty || tier == 'unspecified'
          ? product.split('_').last
          : tier,
      currency: currency,
      cents: entry.value,
      cardExchangeRate: ratesByCardId[id],
    );
  }).toList();
}
