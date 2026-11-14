import 'package:flutter/material.dart';

class VoidPaymentDialog extends StatefulWidget {
  const VoidPaymentDialog({super.key, this.deleteFromMovements = false});

  final bool deleteFromMovements;
  @override
  State<VoidPaymentDialog> createState() => _VoidPaymentDialogState();
}

class _VoidPaymentDialogState extends State<VoidPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  String get actionLabel =>
      widget.deleteFromMovements ? 'Eliminar pago' : 'Anular pago';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(actionLabel),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.deleteFromMovements
                    ? 'Se quitará el pago de los movimientos vigentes y se recalcularán los saldos relacionados. El registro quedará en Anulados. Esta acción solo afecta a Mi Billete.'
                    : 'Se anulará el registro y se recalcularán los saldos relacionados. Esto no realiza una devolución bancaria.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.deleteFromMovements
                      ? 'Motivo (opcional)'
                      : 'Motivo',
                ),
                validator: (value) =>
                    !widget.deleteFromMovements && (value ?? '').trim().isEmpty
                    ? 'Escribe el motivo'
                    : null,
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
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          final note = reason.text.trim();
          Navigator.pop(
            context,
            note.isEmpty ? 'Eliminado desde Movimientos de tarjeta' : note,
          );
        },
        child: Text(actionLabel),
      ),
    ],
  );
}
