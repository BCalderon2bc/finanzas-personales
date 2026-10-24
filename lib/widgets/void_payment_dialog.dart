import 'package:flutter/material.dart';

class VoidPaymentDialog extends StatefulWidget {
  const VoidPaymentDialog({super.key});
  @override
  State<VoidPaymentDialog> createState() => _VoidPaymentDialogState();
}
class _VoidPaymentDialogState extends State<VoidPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();

  @override
  void dispose() { reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Anular pago'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Se anulará el registro y se recalcularán los saldos relacionados. Esto no realiza una devolución bancaria.'),
      const SizedBox(height: 12),
      TextFormField(
        controller: reason, autofocus: true, maxLines: 3,
        decoration: const InputDecoration(labelText: 'Motivo'),
        validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe el motivo' : null,
      ),
    ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          if (formKey.currentState!.validate()) Navigator.pop(context, reason.text.trim());
        },
        child: const Text('Anular pago'),
      ),
    ],
  );
}