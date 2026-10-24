import 'package:flutter/material.dart';

class CreditCardFormDialog extends StatefulWidget {
  const CreditCardFormDialog({super.key, this.card});
  final Map<String, dynamic>? card;
  @override
  State<CreditCardFormDialog> createState() => _CreditCardFormDialogState();
}
class _CreditCardFormDialogState extends State<CreditCardFormDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), reference = TextEditingController();
  final limit = TextEditingController(), closing = TextEditingController();
  final payment = TextEditingController();
  final openingBalance = TextEditingController(text: '0.00');

  String currency = 'NIO';
  bool get editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    if (card == null) return;
    name.text = card['name']?.toString() ?? '';
    reference.text = card['card_reference']?.toString() ?? '';
    limit.text = card['credit_limit'].toString();
    closing.text = card['closing_day']?.toString() ?? '';
    payment.text = card['payment_day']?.toString() ?? '';
    currency = card['currency'].toString();
    openingBalance.text = '${card['opening_balance'] ?? 0}';
  }


  @override
  void dispose() {
    name.dispose(); reference.dispose(); limit.dispose();
    closing.dispose(); payment.dispose();
    openingBalance.dispose();
    super.dispose();

  }
  Widget dayField(String label, TextEditingController controller) => TextFormField(
    controller: controller, keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      final day = int.tryParse(text);
      return day == null || day < 1 || day > 31 ? 'Introduce un día del 1 al 31' : null;
    },
  );
  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': name.text.trim(),
      'card_reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'currency': currency,
      'credit_limit': double.parse(limit.text.trim().replaceAll(',', '.')),
      if (!editing)
        'opening_balance': double.parse(openingBalance.text.trim().replaceAll(',', '.')),
      'closing_day': int.tryParse(closing.text.trim()),
      'payment_day': int.tryParse(payment.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar tarjeta' : 'Nueva tarjeta de crédito'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Mi tarjeta Visa'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null),
      const SizedBox(height: 12),
      TextFormField(controller: reference, keyboardType: TextInputType.number,
          maxLength: 4, decoration: const InputDecoration(labelText: 'Últimos 4 dígitos (opcional)'),
          validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^\d{4}$').hasMatch(v!.trim())
              ? null : 'Escribe los últimos 4 dígitos'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: currency, decoration: const InputDecoration(labelText: 'Moneda'),
        items: const [
          DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
          DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
        ],
        onChanged: editing ? null : (v) {
          if (v != null) setState(() => currency = v);
        },
      ),
      const SizedBox(height: 12),
      TextFormField(controller: limit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Límite de crédito'),
          validator: (v) {
            final text = (v ?? '').trim();
            final amount = double.tryParse(text.replaceAll(',', '.'));
            if (amount == null || !amount.isFinite || amount < 0) return 'Introduce un límite válido';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
            return null;
          }),
      const SizedBox(height: 12),
      TextFormField(
        controller: openingBalance, readOnly: editing,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Deuda inicial',
          helperText: editing
              ? 'Se conserva después de crear la tarjeta.'
              : 'Deuda anterior al historial que registrarás aquí.',
        ),
        validator: (value) {
          if (editing) return null;
          final text = (value ?? '').trim();
          final amount = double.tryParse(text.replaceAll(',', '.'));
          if (amount == null || !amount.isFinite || amount < 0) return 'Introduce un monto válido';
          if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
          return null;
        },
      ),
      const SizedBox(height: 12),
      const SizedBox(height: 12),
      dayField('Día de corte (opcional)', closing),
      const SizedBox(height: 12),
      dayField('Día de pago (opcional)', payment),
    ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}