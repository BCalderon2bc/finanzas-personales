import 'package:flutter/material.dart';

class CreditCardMovementDialog extends StatefulWidget {
  const CreditCardMovementDialog({super.key, required this.currency, required this.categories,    this.movement,});
  final String currency;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? movement;

  @override
  State<CreditCardMovementDialog> createState() => _CreditCardMovementDialogState();
}
class _CreditCardMovementDialogState extends State<CreditCardMovementDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(), description = TextEditingController();
  final reference = TextEditingController();
  String type = 'purchase';
  String? categoryId;
  DateTime date = DateTime.now();
  bool get usesCategory => type == 'purchase' || type == 'refund';

  bool get editing => widget.movement != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.movement;
    if (tx == null) return;
    type = tx['transaction_type'].toString();
    categoryId = tx['category_id']?.toString();
    amount.text = tx['amount'].toString();
    description.text = tx['description']?.toString() ?? '';
    reference.text = tx['reference']?.toString() ?? '';
    date = DateTime.parse(tx['transaction_date'].toString()).toLocal();
  }

  @override
  void dispose() {
    amount.dispose(); description.dispose(); reference.dispose(); super.dispose();
  }
  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'transaction_type': type,
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'category_id': usesCategory ? categoryId : null,
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'transaction_date': DateTime(date.year, date.month, date.day, 12).toUtc().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.currency == 'USD' ? 'US\$' : 'C\$';
    return AlertDialog(
      title: Text(editing ? 'Editar movimiento' : 'Movimiento de tarjeta'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
        key: formKey, child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: type, decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'purchase', child: Text('Compra')),
                DropdownMenuItem(value: 'interest', child: Text('Intereses')),
                DropdownMenuItem(value: 'fee', child: Text('Comisión')),
                DropdownMenuItem(value: 'refund', child: Text('Devolución de compra')),
              ],
              onChanged: editing ? null : (value) {
                if (value != null) setState(() { type = value; categoryId = null; });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Monto ($symbol)'),
              validator: (value) {
                final text = (value ?? '').trim();
                final number = double.tryParse(text.replaceAll(',', '.'));
                if (number == null || !number.isFinite || number <= 0) return 'Escribe un monto mayor que cero';
                if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
                return null;
              },
            ),
            if (usesCategory && widget.categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(type),
                initialValue: categoryId ?? 'none', isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
                items: [
                  const DropdownMenuItem(value: 'none', child: Text('Sin categoría')),
                  ...widget.categories.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (value) => setState(() => categoryId = value == 'none' ? null : value),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: description,
                decoration: const InputDecoration(labelText: 'Descripción')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
              onPressed: () async {
                final selected = await showDatePicker(context: context,
                    initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (selected != null && mounted) setState(() => date = selected);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: reference,
                decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
          ]),
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Guardar')),
      ],
    );
  }
}