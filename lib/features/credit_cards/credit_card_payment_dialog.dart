import '../../utils/money.dart';
import '../../core/app_theme.dart' show appMuted;
import '../person_accounts/receipt_draft_field.dart';
import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';

class CreditCardPaymentDialog extends StatefulWidget {
  const CreditCardPaymentDialog({
    super.key,
    required this.accounts,
    this.currency,
    this.statementsByCurrency = const {},
    this.statements = const [],
    this.initialStatementId,
    this.initialAmountCents,
  });
  final List<Map<String, dynamic>> accounts;
  final String? currency;
  final Map<String, List<Map<String, dynamic>>> statementsByCurrency;
  final List<Map<String, dynamic>> statements;
  final String? initialStatementId;
  final int? initialAmountCents;
  @override
  State<CreditCardPaymentDialog> createState() =>
      _CreditCardPaymentDialogState();
}

class _CreditCardPaymentDialogState extends State<CreditCardPaymentDialog> {
  final _receipt = ReceiptDraft();
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(), reference = TextEditingController();
  String? accountId, statementId;

  String? get currency =>
      widget.currency ??
      widget.accounts
          .firstWhere(
            (account) => account['id'].toString() == accountId,
            orElse: () => const {},
          )['currency']
          ?.toString();

  List<Map<String, dynamic>> get statements => widget.currency != null
      ? widget.statements
      : widget.statementsByCurrency[currency] ?? const [];

  String? defaultStatement() =>
      statements.length == 1 ? statements.first['id'].toString() : null;

  void selectAccount(String? id) {
    setState(() {
      final previousCurrency = currency;
      accountId = id;
      if (currency != previousCurrency) {
        amount.clear();
        statementId = defaultStatement();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAmountCents != null) {
      amount.text = (widget.initialAmountCents! / moneyScale).toStringAsFixed(
        6,
      );
    }
    statementId = widget.initialStatementId ?? defaultStatement();
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  void save() {
    if (_receipt.picking) return;
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      ..._receipt.fields,
      'account_id': accountId,
      'statement_id': statementId,
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pagar tarjeta'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: accountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cuenta de donde sale el dinero',
                ),
                items: widget.accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(
                          "${a['currency'] == 'USD' ? '\$' : 'C\$'} · ${a['name']}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: selectAccount,
                validator: (value) =>
                    value == null ? 'Selecciona una cuenta' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                enabled: currency != null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: currency == null ? 'Monto' : 'Monto ($currency)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  final number = double.tryParse(text.replaceAll(',', '.'));
                  if (number == null || !number.isFinite || number <= 0)
                    return 'Escribe un monto mayor que cero';
                  if (!RegExp(r'^\d+([.,]\d{1,6})?$').hasMatch(text))
                    return 'Usa máximo seis decimales, sin separadores de miles';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (statements.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(currency),
                  initialValue: statementId ?? 'none',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aplicar al estado de cuenta',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('Sin asignar a un corte'),
                    ),
                    ...statements.map(
                      (s) => DropdownMenuItem(
                        value: '${s['id']}',
                        child: Text(
                          'Corte ${shortStatementDate(s['closing_date'])}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => statementId = v == 'none' ? null : v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Asigna solo pagos que no estén descontados del saldo al corte registrado.',
                  style: TextStyle(fontSize: 14, color: appMuted),
                ),
                const SizedBox(height: 12),
              ],
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
      ReceiptDraftField(draft: _receipt),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: save, child: const Text('Registrar pago')),
    ],
  );
}
