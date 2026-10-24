import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../widgets/category_style.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key, required this.transaction, required this.label,
    required this.account, required this.destination,
    required this.category, this.categoryStyle, this.onTap,
  });
  final Map<String, dynamic> transaction;
  final Map<String, dynamic>? categoryStyle;
  final String label, account, destination, category;
  final VoidCallback? onTap;

  Widget badge(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
        color: color.withAlpha(14), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
      ],
      Flexible(child: Text(text, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w600))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF087F5B);
    const red = Color(0xFFB42318);
    const blue = Color(0xFF2563EB);
    const muted = Color(0xFF64748B);
    final type = transaction['transaction_type'];
    final income = ['income', 'deposit'].contains(type);
    final expense = ['expense', 'withdrawal', 'card_payment', 'debt_payment'].contains(type);
    final external = ['credit_card_payment', 'debt_payment'].contains(transaction['source']);
    final reconciled = transaction['is_reconciled'] == true;
    final description = transaction['description']?.toString().trim() ?? '';
    final currency = transaction['currency'] == 'USD' ? 'US\$' : 'C\$';
    final cents = moneyCents(transaction['amount']);
    final date = DateTime.tryParse('${transaction['transaction_date']}')?.toLocal();
    final color = income ? green : expense ? red : blue;
    final icon = switch (type) {
      'card_payment' => Icons.credit_card_outlined,
      'debt_payment' => Icons.payments_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      'income' || 'deposit' => Icons.south_west_rounded,
      'expense' || 'withdrawal' => Icons.north_east_rounded,
      _ => Icons.receipt_long_outlined,
    };
    final styledCategory = categoryStyle;
    final hasCategoryStyle = styledCategory != null &&
        ['income', 'expense'].contains(type);
    final visualColor = hasCategoryStyle
        ? categoryColor(styledCategory?['color'], income: income) : color;
    final visualIcon = hasCategoryStyle
        ? categoryIcon(styledCategory?['icon']) : icon;

    Widget amount() => Text(
      '${income ? '+' : expense ? '−' : ''}$currency ${(cents / 100).toStringAsFixed(2)}',
      style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 560;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: visualColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(visualIcon, color: visualColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(description.isEmpty ? label : description,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF172033),
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(type == 'transfer' ? '$account → $destination' : account,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12)),
                if (compact) ...[
                  const SizedBox(height: 9),
                  amount(),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  badge(label, color),
                  if (category.isNotEmpty) badge(category, visualColor),
                  if (external)
                    badge('Pago vinculado', blue, icon: Icons.link_rounded)
                  else if (reconciled)
                    badge('Conciliado', green, icon: Icons.verified_outlined)
                  else
                    badge('Por conciliar', muted),
                ]),
              ])),
              if (!compact) ...[
                const SizedBox(width: 16),
                Flexible(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end, children: [
                  amount(),
                  if (date != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        '${date.hour.toString().padLeft(2, '0')}:'
                            '${date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                ])),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: muted, size: 18),
            ]);
          }),
        ),
      ),
    );
  }
}