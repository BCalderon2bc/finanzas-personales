import '../../utils/card_cash_advance.dart';
import 'package:flutter/material.dart';

import '../../utils/money.dart';
import '../../widgets/category_style.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    this.receiptCount = 0,
    required this.transaction,
    required this.label,
    required this.account,
    required this.destination,
    required this.category,
    this.categoryStyle,
    this.onTap,
  });

  final Map<String, dynamic> transaction;
  final int receiptCount;
  final Map<String, dynamic>? categoryStyle;
  final String label, account, destination, category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final type = transaction['transaction_type'];
    final income = type == 'income' || type == 'deposit';
    final expense = [
      'expense',
      'withdrawal',
      'card_payment',
      'debt_payment',
    ].contains(type);
    final external = [
      'credit_card_payment',
      'debt_payment',
      'receivable_loan',
      cashAdvanceDepositSource,
    ].contains(transaction['source']);
    final color = income
        ? const Color(0xFF35745C)
        : expense
        ? colors.error
        : colors.primary;
    final icon = switch (type) {
      'card_payment' => Icons.credit_card_outlined,
      'debt_payment' => Icons.payments_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      'income' || 'deposit' => Icons.south_west_rounded,
      'expense' || 'withdrawal' => Icons.north_east_rounded,
      _ => Icons.receipt_long_outlined,
    };
    final styledCategory = categoryStyle;
    final useCategory =
        styledCategory != null && (type == 'income' || type == 'expense');
    final visualColor = useCategory
        ? categoryColor(styledCategory['color'], income: income)
        : color;
    final visualIcon = useCategory
        ? categoryIcon(styledCategory['icon'])
        : icon;
    final description = transaction['description']?.toString().trim() ?? '';
    final accountLabel = type == 'transfer'
        ? '$account → $destination'
        : account;
    final currency = transaction['currency']?.toString() ?? 'NIO';
    final cents = moneyCents(transaction['amount']);
    final date = DateTime.tryParse(
      '${transaction['transaction_date']}',
    )?.toLocal();
    final dateLabel = date == null
        ? 'Sin fecha'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final sign = income
        ? '+'
        : expense
        ? '−'
        : '';
    final status = transaction['source'] == cashAdvanceDepositSource
        ? 'Retiro vinculado'
        : external
        ? 'Pago vinculado'
        : transaction['is_reconciled'] == true
        ? 'Conciliado'
        : 'Por conciliar';
    final title = description.isEmpty ? label : description;
    final subtitle = [
      if (description.isNotEmpty) label,
      if (category.isNotEmpty) category,
      status,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(visualIcon, color: visualColor, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '$sign${formatMoneyCents(cents, currency)}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(dateLabel, style: theme.textTheme.bodySmall),
              Text(accountLabel),
              Text(subtitle, style: theme.textTheme.bodySmall),
              if (receiptCount > 0) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.attach_file,
                          color: colors.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                      TextSpan(
                        text: receiptCount == 1
                            ? '  1 comprobante'
                            : '  $receiptCount comprobantes',
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
