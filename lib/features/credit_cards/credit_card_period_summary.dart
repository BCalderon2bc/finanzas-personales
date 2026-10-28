import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estados de cuenta',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ],
            ),
            if (current.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Registra el saldo al corte, el mínimo y el vencimiento que informa tu banco.',
                ),
              ),
            ...current.map((s) {
              final p = data.progress(s), currency = '${s['currency']}';
              final date = statementDate(s['due_date'])!;
              final past = daysUntil(date, DateTime.now()) < 0 && !p.settled;
              final late = past && (p.minimumRemaining ?? 0) > 0;
              final status = p.settled
                  ? 'Saldo al corte cubierto'
                  : late
                  ? 'Mínimo pendiente tras el vencimiento'
                  : past && p.minimumRemaining == 0
                  ? 'Mínimo cubierto · saldo pendiente'
                  : past
                  ? 'Fecha pasada · mínimo sin registrar'
                  : 'Período vigente';
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$currency · $status',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: late
                            ? const Color(0xFFB42318)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Corte ${shortStatementDate(s['closing_date'])} · Vence ${shortStatementDate(s['due_date'])}',
                    ),
                    const SizedBox(height: 6),
                    Text('Saldo al corte: ${cardMoney(p.balance, currency)}'),
                    Text('Pagos vinculados: ${cardMoney(p.paid, currency)}'),
                    if (p.balanceCredit > 0)
                      Text(
                        'Reversiones al saldo: ${cardMoney(p.balanceCredit, currency)}',
                      ),
                    if (p.minimumCredit > 0)
                      Text(
                        'Reversiones al mínimo: ${cardMoney(p.minimumCredit, currency)}',
                      ),
                    Text(
                      'Pendiente del período: ${cardMoney(p.remaining, currency)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Mínimo pendiente: ${s['minimum_due'] == null ? 'Sin registrar' : cardMoney(p.minimumRemaining, currency)}',
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.manage_history_outlined),
              label: const Text('Cortes, mínimos y pagos'),
            ),
            const SizedBox(height: 8),
            const Text(
              'El saldo al corte es parte de la deuda total, no una deuda adicional.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
