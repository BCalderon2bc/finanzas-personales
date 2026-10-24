import 'package:flutter/material.dart';

class CreditCardPaymentDialog extends StatefulWidget {
  const CreditCardPaymentDialog({super.key, required this.accounts, required this.currency});
  final List<Map<String, dynamic>> accounts;
  final String currency;
  @override
  State<CreditCardPaymentDialog> createState() => _CreditCardPaymentDialogState();
}
class _CreditCardPaymentDialogState extends State<CreditCardPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(), reference = TextEditingController();
  String? accountId;

  @override
  void dispose() { amount.dispose(); reference.dispose(); super.dispose(); }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'account_id': accountId,
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pagar tarjeta'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: accountId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Cuenta de donde sale el dinero'),
        items: widget.accounts.map((a) => DropdownMenuItem(
          value: a['id'].toString(),
          child: Text(a['name'].toString(), overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (value) => setState(() => accountId = value),
        validator: (value) => value == null ? 'Selecciona una cuenta' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Monto (${widget.currency})'),
          validator: (value) {
            final text = (value ?? '').trim();
            final number = double.tryParse(text.replaceAll(',', '.'));
            if (number == null || !number.isFinite || number <= 0) return 'Escribe un monto mayor que cero';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
            return null;
          }),
      const SizedBox(height: 12),
      TextFormField(controller: reference,
          decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
    ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Registrar pago')),
    ],
  );
}