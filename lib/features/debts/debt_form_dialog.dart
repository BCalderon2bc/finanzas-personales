import 'package:flutter/material.dart';

class DebtFormDialog extends StatefulWidget {
  const DebtFormDialog({super.key});
  @override
  State<DebtFormDialog> createState() => _DebtFormDialogState();
}
class _DebtFormDialogState extends State<DebtFormDialog> {
  final formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();
  final creditorController = TextEditingController();
  final amountController = TextEditingController();
  String currency = 'NIO';

  @override
  void dispose() {
    descriptionController.dispose();
    creditorController.dispose();
    amountController.dispose();
    super.dispose();
  }
  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'description': descriptionController.text.trim(),
      'creditor_name': creditorController.text.trim().isEmpty
          ? null : creditorController.text.trim(),
      'currency': currency,
      'original_amount': double.parse(amountController.text.trim().replaceAll(',', '.')),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva deuda'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: descriptionController, autofocus: true,
          decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Ej. Préstamo personal'),
          validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe una descripción' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: creditorController,
            decoration: const InputDecoration(labelText: '¿A quién le debes? (opcional)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: currency, decoration: const InputDecoration(labelText: 'Moneda'),
          items: const [
            DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
            DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
          ],
          onChanged: (value) { if (value != null) setState(() => currency = value); },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Capital original', helperText: 'Monto prestado, sin incluir intereses.'),
          validator: (value) {
            final text = (value ?? '').trim();
            final amount = double.tryParse(text.replaceAll(',', '.'));
            if (amount == null || !amount.isFinite || amount <= 0) return 'Escribe un monto mayor que cero';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
            return null;
          },
        ),
      ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}