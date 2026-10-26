import 'package:flutter/material.dart';
import 'credit_card_balances.dart';

class CreditCardsSummary extends StatelessWidget {
  const CreditCardsSummary({super.key, required this.cards, required this.balanceFor});
  final List<Map<String, dynamic>> cards;
  final int? Function(Map<String, dynamic>, String) balanceFor;
  Widget currencyCard(BuildContext context, String currency) {
    var debt = 0, credit = 0, unknown = 0;
    for (final card in cards) {
      final balance = balanceFor(card, currency);
      if (balance == null) { unknown++; continue; }
      if (balance > 0) { debt += balance; }
      if (balance < 0) { credit -= balance; }
    }
    return Card(child: Padding(padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(currency == 'USD' ? 'Dólares' : 'Córdobas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text('Deuda: ${unknown > 0 ? 'Por revisar' : cardMoney(debt, currency)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text('Saldo a favor: ${unknown > 0 ? 'Por revisar' : cardMoney(credit, currency)}'),
        if (unknown > 0) Text('$unknown tarjetas con ajustes pendientes de revisión.'),
      ])));
  }
  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) { return const SizedBox.shrink(); }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) => box.maxWidth < 600
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [currencyCard(context, 'NIO'), currencyCard(context, 'USD')])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: currencyCard(context, 'NIO')), Expanded(child: currencyCard(context, 'USD'))])),
      const SizedBox(height: 8),
      const Text('Incluye tarjetas activas e inactivas. Los saldos a favor se muestran por separado. '
        'Consulta el disponible del límite compartido en el detalle de cada tarjeta.',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    ]);
  }
}
