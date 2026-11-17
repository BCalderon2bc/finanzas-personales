import '../../widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import '../../data/exchange_rate.dart';
import '../../utils/money.dart';
import '../../data/receivable_loan_logic.dart';

class ReceivableLoansSummary extends StatelessWidget {
  const ReceivableLoansSummary({
    super.key,
    required this.loans,
    required this.payments,
    this.displayCurrency,
    this.exchangeRate,
  });
  final List<Map<String, dynamic>> loans, payments;
  final String? displayCurrency;
  final ExchangeRate? exchangeRate;
  bool get consolidated => displayCurrency != null && exchangeRate != null;
  Widget currencyCard(BuildContext context, String currency) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    int present(int amount, dynamic from) => consolidated
        ? exchangeRate!.convert(amount, from.toString(), currency)
        : amount;
    var pending = 0, overdue = 0, count = 0, interests = 0;
    final active = loans
        .where(
          (l) =>
              l['is_voided'] != true &&
              (consolidated || l['currency'] == currency),
        )
        .toList();
    final ids = active.map((l) => l['id'].toString()).toSet();
    for (final loan in active) {
      final amount = receivablePending(loan, payments);
      pending += present(amount, loan['currency']);
      if (amount > 0) {
        count++;
      }
      if (receivableOverdue(loan, amount, DateTime.now())) {
        overdue += present(amount, loan['currency']);
      }
    }
    for (final p in payments) {
      if (p['is_voided'] != true &&
          (consolidated || p['currency'] == currency) &&
          ids.contains(p['loan_id'].toString())) {
        interests += present(moneyCents(p['interest_amount']), p['currency']);
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            currency == 'USD' ? 'Dólares' : 'Córdobas',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              receivableMoney(pending, currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1 ? '1 préstamo pendiente' : '$count préstamos pendientes',
            style: theme.textTheme.bodySmall,
          ),
          if (overdue > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Vencido: ${receivableMoney(overdue, currency)}',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          if (interests != 0) ...[
            const SizedBox(height: 4),
            Text(
              'Intereses cobrados: ${receivableMoney(interests, currency)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Capital por cobrar',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      AdaptiveColumns(
        minColumnWidth: 145,
        spacing: 8,
        children: [
          if (consolidated)
            currencyCard(context, displayCurrency!)
          else ...[
            currencyCard(context, 'NIO'),
            currencyCard(context, 'USD'),
          ],
        ],
      ),
      if (consolidated)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Total equivalente con la tasa de Configuraciones.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Disponible como efectivo al recibir el pago.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
