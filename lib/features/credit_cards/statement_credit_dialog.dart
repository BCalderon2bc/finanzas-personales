import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';
import '../../utils/money.dart';
import 'credit_card_balances.dart';

class StatementCreditDialog extends StatefulWidget {
  const StatementCreditDialog({
    super.key,
    required this.statement,
    required this.data,
  });
  final Map<String, dynamic> statement;
  final CardStatementData data;
  @override
  State<StatementCreditDialog> createState() => _StatementCreditDialogState();
}

class _StatementCreditDialogState extends State<StatementCreditDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      balance = TextEditingController(text: '0.00'),
      minimum = TextEditingController(),
      description = TextEditingController(text: 'Reversión de anualidad');
  String refundId = 'new';
  DateTime date = DateTime.now();
  Map<String, dynamic> get s => widget.statement;
  String get currency => '${s['currency']}';
  List<Map<String, dynamic>> get available {
    final used = widget.data.credits
        .where((c) => c['is_removed'] != true)
        .map((c) => '${c['refund_id']}')
        .toSet();
    return widget.data.payments
        .where(
          (p) =>
              p['transaction_type'] == 'refund' &&
              p['is_voided'] != true &&
              '${p['credit_card_id']}' == '${s['credit_card_id']}' &&
              p['currency'] == currency &&
              !used.contains('${p['id']}') &&
              '${p['transaction_date']}'.compareTo('${s['closing_date']}') >= 0,
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in [amount, balance, minimum, description]) {
      c.dispose();
    }
    super.dispose();
  }

  double? number(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));
  String? validate(String? v) {
    final text = (v ?? '').trim(),
        n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    return n == null ||
            !n.isFinite ||
            n < 0 ||
            n > 999999999999.99 ||
            !RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)
        ? 'Usa un monto positivo o cero, con máximo dos decimales'
        : null;
  }

  Widget field(String label, TextEditingController c, {bool enabled = true}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextFormField(
          controller: c,
          enabled: enabled,
          decoration: InputDecoration(labelText: '$label ($currency)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validate,
          onChanged: (_) => setState(() {}),
        ),
      );
  void save() {
    if (!form.currentState!.validate()) return;
    final a = number(amount)!, b = number(balance)!, m = number(minimum)!;
    final p = widget.data.progress(s);
    String? error;
    if (a <= 0 || b > a || m > a || b + m <= 0)
      error =
          'Indica una reversión mayor que cero y reducciones entre cero y su monto.';
    if (m > 0 && s['minimum_due'] == null)
      error = 'Primero registra el mínimo informado del corte.';
    if ((b * 100).round() + p.balanceCredit > p.balance ||
        (s['minimum_due'] != null &&
            (m * 100).round() + p.minimumCredit >
                moneyCents(s['minimum_due']))) {
      error =
          'Las reducciones superarían el saldo o mínimo informado del corte.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'p_amount': a,
      'p_balance_credit': b,
      'p_minimum_credit': m,
      'p_refund_id': refundId == 'new' ? null : refundId,
      'p_date': DateTime(
        date.year,
        date.month,
        date.day,
        12,
      ).toUtc().toIso8601String(),
      'p_description': description.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.data.progress(s),
        b = number(balance) ?? 0,
        m = number(minimum) ?? 0;
    final nextBalance = p.remaining == null
        ? null
        : (p.remaining! - (b * 100).round()).clamp(0, p.balance).toInt();
    final nextMinimum = p.minimumRemaining == null
        ? null
        : (p.minimumRemaining! - (m * 100).round()).clamp(0, p.balance).toInt();
    return AlertDialog(
      title: const Text('Reversión aplicada al corte'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$currency · Corte ${shortStatementDate(s['closing_date'])}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra lo que el banco confirmó. Si ya ingresaste la devolución, selecciónala para usar el mismo movimiento.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: refundId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Origen de la reversión',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'new',
                      child: Text('Registrar nueva reversión'),
                    ),
                    ...available.map(
                      (t) => DropdownMenuItem(
                        value: '${t['id']}',
                        child: Text(
                          '${cardMoney(moneyCents(t['amount']), currency)} · ${shortStatementDate(t['transaction_date'])} · ${t['description'] ?? 'Reembolso'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      refundId = v;
                      if (v != 'new') {
                        final t = available.firstWhere(
                          (t) => '${t['id']}' == v,
                        );
                        amount.text = '${t['amount']}';
                      } else {
                        amount.clear();
                      }
                    });
                  },
                ),
                field(
                  'Monto total de la reversión',
                  amount,
                  enabled: refundId == 'new',
                ),
                field('Reducción del mínimo confirmada por el banco', minimum),
                field('Reducción del saldo del corte confirmada', balance),
                const SizedBox(height: 8),
                const Text(
                  'Las reducciones son independientes: no se suman como dos reembolsos. Usa 0 en lo que el banco no haya ajustado. No vuelvas a editar el corte para descontar estos mismos importes.',
                ),
                if (refundId == 'new') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Concepto'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Escribe un concepto' : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      'Fecha: ${shortStatementDate(date.toIso8601String())}',
                    ),
                    onPressed: () async {
                      final first = statementDate(s['closing_date'])!,
                          today = DateTime.now();
                      if (first.isAfter(today)) return;
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: date.isBefore(first) ? first : date,
                        firstDate: first,
                        lastDate: today,
                      );
                      if (chosen != null && mounted)
                        setState(() => date = chosen);
                    },
                  ),
                ],
                const Divider(height: 24),
                Text(
                  'Mínimo pendiente: ${cardMoney(p.minimumRemaining, currency)} → ${cardMoney(nextMinimum, currency)}',
                ),
                Text(
                  'Pendiente del período: ${cardMoney(p.remaining, currency)} → ${cardMoney(nextBalance, currency)}',
                ),
                Text(
                  refundId == 'new'
                      ? 'También bajará la deuda de la tarjeta por el monto total de la reversión.'
                      : 'La deuda de la tarjeta ya refleja este reembolso; no se descontará de nuevo.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: save, child: const Text('Aplicar reversión')),
      ],
    );
  }
}
