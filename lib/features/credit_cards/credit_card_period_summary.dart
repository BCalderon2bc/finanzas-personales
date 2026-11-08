import 'package:flutter/material.dart';

import '../../data/card_statement_logic.dart';
import '../../widgets/adaptive_layout.dart';
import '../../utils/money.dart';
import 'credit_card_balances.dart';

class CreditCardPeriodSummary extends StatelessWidget {
  const CreditCardPeriodSummary({
    super.key,
    required this.cardId,
    required this.data,
    required this.onManage,
  });

  final String cardId;
  final CardStatementData data;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final current = data.currentFor(cardId);
    final first = current.firstOrNull;
    final sharedDates =
        first != null &&
        current.every(
          (row) =>
              row['closing_date'] == first['closing_date'] &&
              row['due_date'] == first['due_date'] &&
              row['bonus_payment_date'] == first['bonus_payment_date'],
        );
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cortes de esta tarjeta',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              first == null
                  ? 'Esta tarjeta no tiene cortes vigentes.'
                  : 'Consulta cuánto falta por pagar en cada moneda.',
              style: theme.textTheme.bodyMedium,
            ),
            if (first != null && sharedDates) ...[
              const SizedBox(height: 12),
              _StatementDates(statement: first),
            ],
            if (current.isNotEmpty) ...[
              const SizedBox(height: 14),
              AdaptiveColumns(
                minColumnWidth: 280,
                children: [
                  for (final statement in current)
                    _CurrencyPeriod(
                      key: ValueKey(statement['id']),
                      progress: data.progress(statement),
                      showDates: !sharedDates,
                      now: now,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'El importe del corte ya forma parte de la deuda de esta tarjeta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.arrow_forward),
                iconAlignment: IconAlignment.end,
                label: const Text('Ver cortes y pagos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementDates extends StatelessWidget {
  const _StatementDates({required this.statement});

  final Map<String, dynamic> statement;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 4,
    children: [
      Text(
        'Fecha máxima de pago · ${shortStatementDate(statement['due_date'])}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      Text('Corte · ${shortStatementDate(statement['closing_date'])}'),
      if (statement['bonus_payment_date'] != null)
        Text(
          'Para bonificar · ${shortStatementDate(statement['bonus_payment_date'])}',
        ),
    ],
  );
}

class _CurrencyPeriod extends StatelessWidget {
  const _CurrencyPeriod({
    super.key,
    required this.progress,
    required this.showDates,
    required this.now,
  });

  final StatementProgress progress;
  final bool showDates;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final statement = progress.statement;
    final currency = '${statement['currency']}';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final due = statementDate(statement['due_date']);
    final past = due != null && daysUntil(due, now) < 0;
    final late = past && (progress.minimumRemaining ?? 0) > 0;
    final status = !progress.known
        ? 'Por revisar'
        : progress.settled
        ? 'Corte cubierto'
        : late
        ? 'Mínimo vencido'
        : progress.minimumRemaining == 0
        ? 'Mínimo cubierto'
        : past
        ? 'Fecha de pago pasada'
        : 'Vigente';
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  currency == 'USD' ? 'Dólares · USD' : 'Córdobas · NIO',
                  style: theme.textTheme.titleMedium,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: late
                        ? colors.errorContainer
                        : colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      status,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: late
                            ? colors.onErrorContainer
                            : colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Mínimo pendiente', style: theme.textTheme.bodyMedium),
            Text(
              statement['minimum_due'] == null
                  ? 'Sin registrar'
                  : cardMoney(progress.minimumRemaining, currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showDates) ...[
              const SizedBox(height: 8),
              _StatementDates(statement: statement),
            ],
            const SizedBox(height: 8),
            Text('Saldo al corte · ${cardMoney(progress.balance, currency)}'),
            Text(
              'Saldo pendiente · ${cardMoney(progress.remaining, currency)}',
              style: theme.textTheme.bodySmall,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 10),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Ver desglose'),
              children: [
                Text(
                  'Mínimo informado · ${statement['minimum_due'] == null ? 'Sin registrar' : cardMoney(moneyCents(statement['minimum_due']), currency)}',
                ),
                Text(
                  'Pagos vinculados · ${cardMoney(progress.paid, currency)}',
                ),
                if (progress.balanceCredit > 0)
                  Text(
                    'Reversiones al saldo · ${cardMoney(progress.balanceCredit, currency)}',
                  ),
                if (progress.minimumCredit > 0)
                  Text(
                    'Reversiones al mínimo · ${cardMoney(progress.minimumCredit, currency)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
