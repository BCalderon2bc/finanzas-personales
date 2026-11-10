import '../../utils/money.dart';
import '../../utils/card_cash_advance.dart';
import 'credit_card_balances.dart'
    show cardMovementType, cardPointsRedemption, cardPointsRedemptionLabel;
import '../../data/payment_agenda_labels.dart' show additionalCardLabel;
import '../person_accounts/receipt_draft_field.dart';
import 'package:flutter/material.dart';

class CreditCardMovementDialog extends StatefulWidget {
  const CreditCardMovementDialog({
    super.key,
    required this.currency,
    required this.categories,
    this.movement,
    this.cashAccounts = const [],
    this.additionalCards = const [],
  });
  final String currency;
  final List<Map<String, dynamic>> cashAccounts;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? movement;
  final List<Map<String, dynamic>> additionalCards;
  @override
  State<CreditCardMovementDialog> createState() =>
      _CreditCardMovementDialogState();
}

class _CreditCardMovementDialogState extends State<CreditCardMovementDialog> {
  final _receipt = ReceiptDraft();
  final commission = TextEditingController(text: '0');
  String? cashAccountId;
  bool get cashAdvance => type == cardCashAdvance;

  int? cashInputCents(String input) {
    final text = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(text)) return null;
    return moneyCents(text);
  }

  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(),
      description = TextEditingController(),
      reference = TextEditingController();
  String type = 'purchase';
  late String currency;
  String? categoryId;
  String additionalId = '';
  DateTime date = DateTime.now();
  bool get editing => widget.movement != null;
  bool get usesCategory => const [
    'purchase',
    'refund',
    'insurance',
    cardPointsRedemption,
    cardCashAdvance,
  ].contains(type);
  static const types = {
    'purchase': 'Compra',
    cardCashAdvance: cardCashAdvanceLabel,
    'interest': 'Intereses',
    'fee': 'Comisión',
    'insurance': 'Seguro de tarjeta',
    'refund': 'Devolución de compra',
    cardPointsRedemption: cardPointsRedemptionLabel,
  };
  @override
  void initState() {
    super.initState();
    final tx = widget.movement;
    currency = tx?['currency']?.toString() ?? widget.currency;
    if (tx == null) {
      return;
    }
    type = cardMovementType(tx['transaction_type'], tx['charge_kind']);
    categoryId = tx['category_id']?.toString();
    additionalId = tx['additional_card_id']?.toString() ?? '';
    amount.text = cashAdvance
        ? (cardCashAdvancePrincipal(tx) / 100).toStringAsFixed(2)
        : tx['amount'].toString();
    commission.text = (cardCashAdvanceFee(tx) / 100).toStringAsFixed(2);
    cashAccountId = tx['cash_advance_account_id']?.toString();
    description.text = tx['description']?.toString() ?? '';
    reference.text = tx['reference']?.toString() ?? '';
    date = DateTime.parse(tx['transaction_date'].toString()).toLocal();
  }

  @override
  void dispose() {
    commission.dispose();
    amount.dispose();
    description.dispose();
    reference.dispose();
    super.dispose();
  }

  void save() {
    if (_receipt.picking) return;
    if (!formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      ..._receipt.fields,
      'transaction_type': switch (type) {
        'insurance' => 'fee',
        cardCashAdvance => 'purchase',
        cardPointsRedemption => 'refund',
        _ => type,
      },
      'charge_kind': switch (type) {
        'insurance' || cardPointsRedemption || cardCashAdvance => type,
        _ => null,
      },
      'currency': currency,
      'amount': cashAdvance
          ? (cashInputCents(amount.text)! + cashInputCents(commission.text)!) /
                100
          : double.parse(amount.text.trim().replaceAll(',', '.')),
      'cash_advance_fee': cashAdvance
          ? cashInputCents(commission.text)! / 100
          : null,
      'cash_advance_account_id': cashAdvance ? cashAccountId : null,
      'additional_card_id': additionalId.isEmpty ? null : additionalId,
      'category_id': usesCategory ? categoryId : null,
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'transaction_date': DateTime(
        date.year,
        date.month,
        date.day,
        12,
      ).toUtc().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cashOptions = widget.cashAccounts
        .where(
          (account) =>
              account['currency'] == currency &&
              (account['is_active'] == true ||
                  '${account['id']}' == cashAccountId),
        )
        .toList();
    final principalCents = cashInputCents(amount.text);
    final feeCents = cashInputCents(commission.text);
    final categories = [...widget.categories];
    if (categoryId != null &&
        !categories.any((c) => c['id'].toString() == categoryId)) {
      categories.add({'id': categoryId, 'name': 'Categoría actual'});
    }
    final selectableCards = widget.additionalCards
        .where(
          (card) =>
              card['is_active'] == true ||
              card['id'].toString() ==
                  widget.movement?['additional_card_id']?.toString(),
        )
        .toList();
    return AlertDialog(
      title: Text(editing ? 'Editar movimiento' : 'Movimiento de tarjeta'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectableCards.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: additionalId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tarjeta del movimiento',
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Titular')),
                      for (final card in selectableCards)
                        DropdownMenuItem(
                          value: card['id'].toString(),
                          child: Text(
                            additionalCardLabel(card),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => additionalId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(
                    labelText: 'Moneda del movimiento',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NIO',
                      child: Text('Córdobas (C\$)'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('Dólares (US\$)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        currency = value;
                        cashAccountId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: types.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        type = value;
                        if (!usesCategory) {
                          categoryId = null;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  onChanged: cashAdvance ? (_) => setState(() {}) : null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${cashAdvance ? 'Efectivo recibido' : 'Monto'} (${currency == 'USD' ? 'US\$' : 'C\$'})',
                    helperText: type == cardPointsRedemption
                        ? 'Ingresa el importe abonado por el banco.'
                        : null,
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    final n = double.tryParse(text.replaceAll(',', '.'));
                    if (n == null || !n.isFinite || n <= 0) {
                      return 'Escribe un monto mayor que cero';
                    }
                    if (cashAdvance && cashInputCents(text) == null)
                      return 'Usa hasta 12 enteros y dos decimales';
                    return RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)
                        ? null
                        : 'Usa máximo dos decimales, sin separadores de miles';
                  },
                ),
                if (cashAdvance) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commission,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Comisión del banco (${currency == 'USD' ? 'US\$' : 'C\$'})',
                      helperText: 'Ingresa el cargo que aplicó el banco.',
                    ),
                    validator: (value) {
                      return cashInputCents(value ?? '') != null
                          ? null
                          : 'Ingresa cero o una comisión con hasta dos decimales';
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('cash-$currency'),
                    isExpanded: true,
                    initialValue:
                        cashOptions.any((a) => '${a['id']}' == cashAccountId)
                        ? cashAccountId
                        : '',
                    decoration: const InputDecoration(
                      labelText: 'Recibir en cuenta de efectivo (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Solo registrar en la tarjeta'),
                      ),
                      for (final account in cashOptions)
                        DropdownMenuItem(
                          value: '${account['id']}',
                          child: Text(
                            '${account['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => cashAccountId = value == '' ? null : value,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (principalCents != null &&
                      principalCents > 0 &&
                      feeCents != null)
                    Text(
                      'Aumenta la deuda: ${formatMoneyCents(principalCents + feeCents, currency)}',
                    ),
                  const Text(
                    'La comisión se registra como gasto. El efectivo se suma a la cuenta elegida.',
                  ),
                ],
                if (usesCategory) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$type-$categoryId'),
                    initialValue: categoryId ?? 'none',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: cashAdvance
                          ? 'Categoría de la comisión (opcional)'
                          : 'Categoría (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('Sin categoría'),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(
                            c['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => categoryId = v == 'none' ? null : v),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                  ),
                  onPressed: () async {
                    final today = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: date.isBefore(DateTime(2000))
                          ? date
                          : DateTime(2000),
                      lastDate: date.isAfter(today) ? date : today,
                    );
                    if (selected != null && mounted) {
                      setState(() => date = selected);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.movement == null) ReceiptDraftField(draft: _receipt),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: save, child: const Text('Guardar')),
      ],
    );
  }
}
