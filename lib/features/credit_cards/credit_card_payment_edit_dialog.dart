import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../data/card_statement_logic.dart';
import 'credit_card_balances.dart';

class CreditCardPaymentEditDialog extends StatefulWidget {
  const CreditCardPaymentEditDialog({
    super.key,
    required this.preview,
    required this.accounts,
  });
  final Map<String, dynamic> preview;
  final List<Map<String, dynamic>> accounts;
  @override
  State<CreditCardPaymentEditDialog> createState() =>
      _CreditCardPaymentEditDialogState();
}

class _CreditCardPaymentEditDialogState
    extends State<CreditCardPaymentEditDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      reference = TextEditingController(),
      description = TextEditingController(),
      rate = TextEditingController();
  late Map<String, dynamic> payment;
  late DateTime date, originalDate;
  late String currency;
  String? accountId;
  bool unlink = false;
  int get allocated => moneyCents(widget.preview['allocated']);
  Map<String, dynamic>? get bank =>
      widget.accounts.where((a) => '${a['id']}' == accountId).firstOrNull;
  String get bankCurrency =>
      '${bank?['currency'] ?? payment['account_debit_currency'] ?? payment['currency']}';
  String get oldBankCurrency =>
      '${payment['account_debit_currency'] ?? payment['currency']}';
  bool get cross => bank != null && bankCurrency != currency;
  bool get incompatible =>
      currency != payment['currency'] &&
      (allocated > 0 || (widget.preview['links'] as List).isNotEmpty);
  double? get parsedRate =>
      double.tryParse(rate.text.trim().replaceAll(',', '.'));
  int? get cardCents {
    final n = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0 || n > 999999999999.99
        ? null
        : (n * 100).round();
  }

  int? get debitCents {
    final c = cardCents;
    if (c == null || bank == null) return null;
    if (!cross) return c;
    final r = parsedRate;
    if (r == null || !r.isFinite || r <= 0 || r > 1000000) return null;
    final v = bankCurrency == 'USD' ? c / r : c * r;
    return !v.isFinite || v > 99999999999999 ? null : v.round();
  }

  @override
  void initState() {
    super.initState();
    payment = Map<String, dynamic>.from(widget.preview['payment'] as Map);
    currency = '${payment['currency']}';
    amount.text = (moneyCents(payment['amount']) / 100).toStringAsFixed(2);
    reference.text = payment['reference']?.toString() ?? '';
    description.text = payment['description']?.toString() ?? '';
    rate.text = payment['payment_exchange_rate']?.toString() ?? '';
    originalDate = DateTime.parse('${payment['transaction_date']}').toLocal();
    date = DateTime(originalDate.year, originalDate.month, originalDate.day);
    final id = payment['account_id']?.toString();
    accountId = widget.accounts.any((a) => '${a['id']}' == id) ? id : null;
  }

  @override
  void dispose() {
    for (final c in [amount, reference, description, rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (debitCents == null || debitCents! <= 0 || (incompatible && !unlink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa el débito y confirma retirar los vínculos incompatibles.',
          ),
        ),
      );
      return;
    }
    final sameDate =
        date.year == originalDate.year &&
        date.month == originalDate.month &&
        date.day == originalDate.day;
    Navigator.pop(context, <String, dynamic>{
      'p_account_id': accountId,
      'p_amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'p_currency': currency,
      'p_rate': cross ? parsedRate : null,
      'p_unlink_incompatible': incompatible && unlink,
      'p_date': sameDate
          ? payment['transaction_date']
          : DateTime(
              date.year,
              date.month,
              date.day,
              12,
            ).toUtc().toIso8601String(),
      'p_reference': reference.text.trim(),
      'p_description': description.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final original = moneyCents(
          payment['account_debit_amount'] ?? payment['amount'],
        ),
        current = debitCents;
    final sameAccount = accountId == payment['account_id']?.toString();
    return AlertDialog(
      title: const Text('Editar pago de tarjeta'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Indica lo aplicado a la tarjeta y la cuenta desde donde pagaste. Si las monedas son distintas, introduce la tasa aplicada por el banco.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Moneda del pago aplicado a la tarjeta',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NIO',
                      child: Text('Córdobas (NIO)'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('Dólares (USD)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => currency = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monto aplicado a la tarjeta ($currency)',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final text = (v ?? '').trim(),
                        n = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                    if (n == null ||
                        !n.isFinite ||
                        n <= 0 ||
                        n > 999999999999.99 ||
                        !RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text))
                      return 'Monto positivo con máximo dos decimales';
                    return currency == payment['currency'] &&
                            (n * 100).round() < allocated
                        ? 'Ya hay ${cardMoney(allocated, currency)} asignados a cuotas'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de origen',
                  ),
                  items: widget.accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: '${a['id']}',
                          child: Text(
                            '${a['name']} · ${a['currency']}${a['is_active'] != true ? ' · Inactiva' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => accountId = v),
                  validator: (v) => v == null ? 'Selecciona una cuenta' : null,
                ),
                if (cross) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tasa: córdobas por US\$1',
                      helperText:
                          'El débito de cuenta se redondea a dos decimales.',
                      helperMaxLines: 2,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final text = (v ?? '').trim(), r = parsedRate;
                      return r == null ||
                              !r.isFinite ||
                              r <= 0 ||
                              r > 1000000 ||
                              !RegExp(r'^\d+([.,]\d{1,6})?$').hasMatch(text)
                          ? 'Tasa positiva con máximo seis decimales'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Débito de cuenta: ${cardMoney(current, bankCurrency)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    'Fecha: ${shortStatementDate(date.toIso8601String())}',
                  ),
                  onPressed: () async {
                    final today = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: date.isBefore(DateTime(1900))
                          ? date
                          : DateTime(1900),
                      lastDate: date.isAfter(today) ? date : today,
                    );
                    if (d != null && mounted) setState(() => date = d);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reference,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
                TextFormField(
                  controller: description,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                if (allocated > 0)
                  Text(
                    'Asignado a tasa cero: ${cardMoney(allocated, '${payment['currency']}')}. Conserva sus importes si mantienes la moneda.',
                  ),
                if (incompatible)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: unlink,
                    title: const Text(
                      'Retirar los vínculos al corte y cuotas de la moneda anterior',
                    ),
                    subtitle: const Text(
                      'Esos pendientes volverán a quedar sin cubrir. Luego podrás aplicar el pago corregido al corte o cuotas de la nueva moneda.',
                    ),
                    onChanged: (v) => setState(() => unlink = v ?? false),
                  ),
                const Divider(height: 24),
                Text(
                  'Débito anterior: ${cardMoney(original, oldBankCurrency)}',
                ),
                Text(
                  'Aplicado a la tarjeta: ${cardMoney(cardCents, currency)}',
                ),
                if (current != null && current > 0)
                  Text(
                    sameAccount
                        ? current > original
                              ? 'Débito adicional de cuenta: ${cardMoney(current - original, bankCurrency)}.'
                              : current < original
                              ? 'La cuenta recuperará ${cardMoney(original - current, bankCurrency)}.'
                              : 'El débito de la cuenta mantiene su importe.'
                        : 'La cuenta anterior recuperará ${cardMoney(original, oldBankCurrency)} y la seleccionada tendrá un débito de ${cardMoney(current, bankCurrency)}.',
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
        FilledButton(onPressed: save, child: const Text('Guardar cambios')),
      ],
    );
  }
}
