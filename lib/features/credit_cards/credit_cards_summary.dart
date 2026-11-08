import 'package:flutter/material.dart';

import '../../widgets/adaptive_layout.dart';
import 'credit_card_balances.dart';

class CreditCardsSummary extends StatelessWidget {
  const CreditCardsSummary({
    super.key,
    required this.cards,
    required this.balanceFor,
  });

  final List<Map<String, dynamic>> cards;
  final int? Function(Map<String, dynamic>, String) balanceFor;

  Widget currencyCard(BuildContext context, String currency) {
    var debt = 0, credit = 0, unknown = 0;
    for (final card in cards) {
      final balance = balanceFor(card, currency);
      if (balance == null) {
        unknown++;
        continue;
      }
      if (balance > 0) {
        debt += balance;
      }
      if (balance < 0) {
        credit -= balance;
      }
    }

    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currency == 'USD' ? 'Dólares · USD' : 'Córdobas · NIO',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Deuda total', style: theme.textTheme.bodyMedium),
            Text(
              unknown > 0 ? 'Por revisar' : cardMoney(debt, currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo a favor · ${unknown > 0 ? 'Por revisar' : cardMoney(credit, currency)}',
            ),
            if (unknown > 0)
              Text(
                unknown == 1
                    ? '1 tarjeta con ajustes pendientes de revisión.'
                    : '$unknown tarjetas con ajustes pendientes de revisión.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Deuda total de tus tarjetas', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Incluye tarjetas activas e inactivas. Los saldos a favor se muestran por separado.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        AdaptiveColumns(
          minColumnWidth: 280,
          children: [
            currencyCard(context, 'NIO'),
            currencyCard(context, 'USD'),
          ],
        ),
      ],
    );
  }
}
