import 'package:flutter/material.dart';

import '../../utils/money.dart';
import '../../widgets/category_style.dart';

class TransactionHistoryHeader extends StatelessWidget {
  const TransactionHistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        child: const _HistoryColumns(
          date: Text('Fecha'),
          description: Text('Descripción'),
          account: Text('Cuenta'),
          amount: Text('Monto', textAlign: TextAlign.end),
        ),
      ),
    );
  }
}

class _HistoryColumns extends StatelessWidget {
  const _HistoryColumns({
    required this.date,
    required this.description,
    required this.account,
    required this.amount,
    this.action = const SizedBox.shrink(),
  });

  final Widget date, description, account, amount, action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Expanded(flex: 2, child: date),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: description),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: account),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: amount),
        const SizedBox(width: 8),
        SizedBox(width: 20, child: action),
      ],
    ),
  );
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    this.receiptCount = 0,
    this.table = false,
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
  final bool table;
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
    ].contains(transaction['source']);
    final color = income
        ? const Color(0xFF14684D)
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
    final status = external
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
    final chevron = Icon(
      Icons.chevron_right_rounded,
      color: colors.onSurfaceVariant,
      size: 20,
    );

    Widget amount({TextAlign? align}) => Text(
      '$sign${formatMoneyCents(cents, currency)}',
      textAlign: align,
      style: theme.textTheme.titleMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );

    Widget receipt() => Tooltip(
      message: '$receiptCount comprobantes',
      child: Icon(Icons.attach_file, size: 16, color: colors.onSurfaceVariant),
    );

    if (table) {
      return Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: _HistoryColumns(
              date: Text(dateLabel, style: theme.textTheme.bodySmall),
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              account: Text(
                accountLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              amount: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (receiptCount > 0) receipt(),
                  Flexible(child: amount(align: TextAlign.end)),
                ],
              ),
              action: chevron,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: visualColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(visualIcon, color: visualColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    amount(),
                    const SizedBox(height: 3),
                    Text(
                      '$dateLabel · $accountLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (receiptCount > 0) receipt(),
              chevron,
            ],
          ),
        ),
      ),
    );
  }
}
