import 'package:flutter/material.dart';
import '../../utils/money.dart';
import 'debt_due_status.dart';

class DebtCard extends StatelessWidget {
  const DebtCard({
    super.key,
    required this.debt,
    required this.paidCents,
    this.onEdit,
    this.onHistory,
    this.onPayment,
    this.onSimulate,
    this.onInstallments,
    this.nextInstallmentLabel,
  });
  final Map<String, dynamic> debt;
  final int paidCents;
  final VoidCallback? onEdit, onHistory, onPayment, onSimulate, onInstallments;
  final String? nextInstallmentLabel;

  String money(int cents) =>
      formatMoneyCents(cents, debt['currency']?.toString() ?? 'NIO');

  Widget badge(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget amountDetail(String label, int amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          money(amount),
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2563EB);
    const green = Color(0xFF087F5B);
    const red = Color(0xFFB42318);
    const amber = Color(0xFFB45309);
    const muted = Color(0xFF64748B);
    const border = Color(0xFFE2E8F0);
    final original = moneyCents(debt['original_amount']);
    final pending = original - paidCents;
    final status = debt['status']?.toString() ?? '';
    final creditor = debt['creditor_name']?.toString().trim() ?? '';
    final due = debtDueStatus(debt, paidCents, DateTime.now());
    final date = DateTime.tryParse('${debt['due_date']}');
    final progress = original > 0
        ? (paidCents / original).clamp(0.0, 1.0).toDouble()
        : 0.0;
    const labels = {
      'active': 'Activa',
      'overdue': 'Vencida',
      'paused': 'Pausada',
      'paid': 'Pagada',
      'cancelled': 'Cancelada',
    };
    final color = pending < 0
        ? red
        : status == 'paid'
        ? green
        : status == 'paused' || status == 'cancelled'
        ? muted
        : due == DebtDueStatus.overdue || status == 'overdue'
        ? red
        : due == DebtDueStatus.today
        ? amber
        : blue;
    final icon = status == 'paid'
        ? Icons.task_alt_rounded
        : status == 'paused'
        ? Icons.pause_circle_outline
        : status == 'cancelled'
        ? Icons.cancel_outlined
        : Icons.account_balance_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt['description']?.toString() ?? 'Deuda',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172033),
                            ),
                          ),
                          if (creditor.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              creditor,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar deuda',
                      onPressed: onEdit,
                      icon: const Icon(Icons.more_horiz_rounded, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    badge(labels[status] ?? status, icon, color),
                    if (date != null)
                      badge(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/${date.year}',
                        Icons.event_outlined,
                        muted,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'CAPITAL PENDIENTE',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(pending),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No incluye intereses ni comisiones.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                if (pending < 0) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Revisa los abonos: superan el capital original.',
                    style: TextStyle(color: red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: amountDetail('Capital original', original),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: amountDetail('Abonado a capital', paidCents),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: color,
                          backgroundColor: border,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${(progress * 100).toStringAsFixed(0)}% del capital abonado',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                if (due != DebtDueStatus.none) ...[
                  const SizedBox(height: 14),
                  badge(
                    due == DebtDueStatus.overdue
                        ? 'El capital tiene vencimiento pendiente'
                        : 'El capital vence hoy',
                    Icons.notification_important_outlined,
                    due == DebtDueStatus.overdue ? red : amber,
                  ),
                ],
                if (nextInstallmentLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      nextInstallmentLabel!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(height: 30, color: border),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    if (onInstallments != null)
                      OutlinedButton.icon(
                        onPressed: onInstallments,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 19,
                        ),
                        label: const Text('Cuotas'),
                      ),
                    TextButton.icon(
                      onPressed: onHistory,
                      icon: const Icon(Icons.history_rounded, size: 19),
                      label: const Text('Abonos'),
                    ),
                    if (pending > 0 && status != 'cancelled')
                      OutlinedButton.icon(
                        onPressed: onSimulate,
                        icon: const Icon(Icons.calculate_outlined, size: 19),
                        label: const Text('Simular'),
                      ),
                    if (['active', 'overdue'].contains(status))
                      FilledButton.icon(
                        onPressed: pending < 0 ? null : onPayment,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Abonar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
