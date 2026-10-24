import 'package:flutter/material.dart';
import '../../utils/money.dart';

class CreditCardsSummary extends StatelessWidget {
  const CreditCardsSummary({
    super.key, required this.cards, required this.balanceFor,
  });
  final List<Map<String, dynamic>> cards;
  final int? Function(Map<String, dynamic>) balanceFor;

  String money(int cents, String currency) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  Widget currencyCard(BuildContext context, String currency) {
    int debt = 0, credit = 0, available = 0, limit = 0, unknown = 0;
    bool activeUnknown = false;
    final selected = cards.where((c) => c['currency'] == currency);
    for (final card in selected) {
      final active = card['is_active'] == true;
      final cardLimit = moneyCents(card['credit_limit']);
      final balance = balanceFor(card);
      if (active) limit += cardLimit;
      if (balance == null) {
        unknown++;
        if (active) activeUnknown = true;
        continue;
      }
      if (balance > 0) debt += balance;
      if (balance < 0) credit -= balance;
      if (active) {
        available += (cardLimit - (balance > 0 ? balance : 0)).clamp(0, cardLimit).toInt();
      }
    }
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(currency == 'USD' ? 'Resumen en dólares' : 'Resumen en córdobas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Deuda registrada: ${unknown > 0 ? 'No calculable' : money(debt, currency)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Saldo a favor: ${unknown > 0 ? 'No calculable' : money(credit, currency)}'),
        const Divider(height: 20),
        Text('Límite de tarjetas activas: ${money(limit, currency)}'),
        Text('Disponible en tarjetas activas: ${activeUnknown ? 'No calculable' : money(available, currency)}'),
        const SizedBox(height: 8),
        Text('${selected.length} tarjetas'),
        if (unknown > 0)
          Text('$unknown tarjetas requieren revisar ajustes o monedas.',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final nio = currencyCard(context, 'NIO');
        final usd = currencyCard(context, 'USD');
        return constraints.maxWidth < 600
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nio, usd])
            : Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: nio), Expanded(child: usd)]);
      }),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('La deuda y el saldo a favor incluyen tarjetas activas e inactivas. El saldo a favor de una tarjeta no se descuenta de la deuda de otra.')),
    ]);
  }
}