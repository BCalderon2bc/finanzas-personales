import 'package:flutter/material.dart';
import '../../utils/money.dart';

String expenseMoney(int cents, String currency) =>
    '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

class ExpenseReportSummary extends StatelessWidget {
  const ExpenseReportSummary({
    super.key, required this.currency, required this.chargesCents,
    required this.refundsCents, required this.count, this.compact = false,
  });
  final String currency;
  final int chargesCents, refundsCents, count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = chargesCents - refundsCents;

    Widget detail(String label, int amount) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: Colors.white.withAlpha(200), fontSize: 11)),
        const SizedBox(height: 5),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(expenseMoney(amount, currency), style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
      ]),
    );

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: total < 0
                ? const [Color(0xFF064E3B), Color(0xFF0D8262)]
                : const [Color(0xFF172554), Color(0xFF2563EB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.pie_chart_outline_rounded, color: Colors.white, size: 21),
          const SizedBox(width: 9),
          const Expanded(child: Text('Gasto neto',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          Text(currency, style: TextStyle(
              color: Colors.white.withAlpha(210), fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(expenseMoney(total, currency), style: TextStyle(
                color: Colors.white, fontSize: compact ? 27 : 34,
                letterSpacing: -0.8, fontWeight: FontWeight.w800))),
        const SizedBox(height: 7),
        Text('$count movimientos',
            style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12)),
        const SizedBox(height: 18),
        Row(children: [
          detail('Cargos registrados', chargesCents),
          const SizedBox(width: 16),
          detail('Devoluciones', refundsCents),
        ]),
      ]),
    );
  }
}

class ExpenseCategoryCard extends StatelessWidget {
  const ExpenseCategoryCard({
    super.key, required this.name, required this.currency,
    required this.amountCents, required this.count,
    required this.positiveTotalCents, required this.color,
    required this.onTap, this.icon = Icons.category_outlined,
  });
  final String name, currency;
  final int amountCents, count, positiveTotalCents;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final refund = amountCents < 0;
    final accent = refund ? const Color(0xFF087F5B) : color;
    final ratio = amountCents > 0 && positiveTotalCents > 0
        ? amountCents / positiveTotalCents : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: accent.withAlpha(15),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    color: Color(0xFF172033), fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$count movimientos', style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF64748B), size: 20),
            ]),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12, runSpacing: 8,
              children: [
                Text(expenseMoney(amountCents, currency),
                    style: TextStyle(color: accent,
                        fontSize: 21, fontWeight: FontWeight.w800)),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: accent.withAlpha(14),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(refund ? 'Devoluciones netas'
                        : '${(ratio * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: accent,
                            fontWeight: FontWeight.w600, fontSize: 11))),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0).toDouble(),
                    minHeight: 7, color: accent,
                    backgroundColor: const Color(0xFFF1F5F9))),
          ]),
        ),
      ),
    );
  }
}

class ExpenseDetailTile extends StatelessWidget {
  const ExpenseDetailTile({
    super.key, required this.transaction, required this.currency,
  });
  final Map<String, dynamic> transaction;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final card = tx['source'] == 'credit_card';
    final debt = tx['source'] == 'debt_payment';
    final amount = moneyCents(tx['amount']);
    final refund = amount < 0;
    final color = refund ? const Color(0xFF087F5B) : const Color(0xFF2563EB);
    final description = tx['description']?.toString().trim() ?? '';
    final reference = tx['reference']?.toString().trim() ?? '';
    final cardName = tx['card_name']?.toString().trim() ?? '';
    final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
    final dateText = date == null ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    const cardTypes = {
      'purchase': 'Compra', 'interest': 'Intereses',
      'fee': 'Comisión', 'refund': 'Devolución',
    };
    final label = debt ? 'Intereses y comisiones de deuda'
        : card ? cardTypes[tx['card_transaction_type']] ?? 'Tarjeta'
        : 'Gasto de cuenta';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(refund ? Icons.undo_rounded : debt ? Icons.payments_outlined
            : card ? Icons.credit_card_outlined
            : Icons.account_balance_wallet_outlined, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(description.isEmpty ? label : description,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text('$dateText · $label',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          if (card && cardName.isNotEmpty)
            Text(cardName, style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 9),
          Text(expenseMoney(amount, currency), style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          if (debt) ...[
            const SizedBox(height: 7),
            Text('Intereses: ${expenseMoney(moneyCents(tx['interest_amount']), currency)}',
                style: const TextStyle(fontSize: 12)),
            Text('Comisiones: ${expenseMoney(moneyCents(tx['fee_amount']), currency)}',
                style: const TextStyle(fontSize: 12)),
          ],
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 7),
            SelectableText('Referencia: $reference',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ])),
      ]),
    );
  }
}