import 'package:flutter/material.dart';

class DebtEditDialog extends StatefulWidget {
  const DebtEditDialog({super.key, required this.debt});
  final Map<String, dynamic> debt;
  @override
  State<DebtEditDialog> createState() => _DebtEditDialogState();
}
class _DebtEditDialogState extends State<DebtEditDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController description, creditor;
  DateTime? dueDate;
  String status = 'active';

  @override
  void initState() {
    super.initState();
    description = TextEditingController(text: widget.debt['description']?.toString() ?? '');
    creditor = TextEditingController(text: widget.debt['creditor_name']?.toString() ?? '');
    dueDate = DateTime.tryParse('${widget.debt['due_date']}');
    status = widget.debt['status']?.toString() ?? 'active';
  }
  @override
  void dispose() {
    description.dispose(); creditor.dispose(); super.dispose();
  }
  String dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void save() {
    if (!formKey.currentState!.validate()) return;
    final date = dueDate;
    Navigator.pop(context, <String, dynamic>{
      'description': description.text.trim(),
      'creditor_name': creditor.text.trim().isEmpty ? null : creditor.text.trim(),
      'due_date': date == null ? null
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'status': status,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar deuda'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey,
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: description, autofocus: true,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe una descripción' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: creditor,
                decoration: const InputDecoration(labelText: 'Acreedor (opcional)')),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: status, decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Activa')),
                DropdownMenuItem(value: 'overdue', child: Text('Vencida')),
                DropdownMenuItem(value: 'paused', child: Text('Pausada')),
                DropdownMenuItem(value: 'paid', child: Text('Pagada')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelada')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => status = value);
              },
            ),
            if (status == 'paid')
              const Text('Confirma que también liquidaste intereses y comisiones. El capital pendiente debe ser cero.'),
            if (status == 'cancelled')
              const Text('Se excluirá del resumen de deudas. Sus abonos anteriores se conservan.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(dueDate == null ? 'Agregar vencimiento' : 'Vence: ${dateText(dueDate!)}'),
              onPressed: () async {
                final initial = dueDate ?? DateTime.now();
                final selected = await showDatePicker(
                  context: context, initialDate: initial,
                  firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
                  lastDate: DateTime(initial.year > 2200 ? initial.year : 2200, 12, 31),
                );
                if (selected != null && mounted) setState(() => dueDate = selected);
              },
            ),
            if (dueDate != null)
              TextButton(onPressed: () => setState(() => dueDate = null),
                  child: const Text('Quitar vencimiento')),
          ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}