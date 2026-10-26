import 'package:flutter/material.dart';

class CreditCardMovementDialog extends StatefulWidget {
  const CreditCardMovementDialog({super.key, required this.currency,
    required this.categories, this.movement});
  final String currency;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? movement;
  @override
  State<CreditCardMovementDialog> createState() => _CreditCardMovementDialogState();
}

class _CreditCardMovementDialogState extends State<CreditCardMovementDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(), description = TextEditingController(), reference = TextEditingController();
  String type = 'purchase';
  late String currency;
  String? categoryId;
  DateTime date = DateTime.now();
  bool get editing => widget.movement != null;
  bool get usesCategory => type == 'purchase' || type == 'refund';
  static const types = {'purchase': 'Compra', 'interest': 'Intereses',
    'fee': 'Comisión', 'refund': 'Devolución de compra'};
  @override
  void initState() {
    super.initState();
    final tx = widget.movement;
    currency = tx?['currency']?.toString() ?? widget.currency;
    if (tx == null) { return; }
    type = tx['transaction_type'].toString();
    categoryId = tx['category_id']?.toString();
    amount.text = tx['amount'].toString();
    description.text = tx['description']?.toString() ?? '';
    reference.text = tx['reference']?.toString() ?? '';
    date = DateTime.parse(tx['transaction_date'].toString()).toLocal();
  }
  @override
  void dispose() { amount.dispose(); description.dispose(); reference.dispose(); super.dispose(); }
  void save() {
    if (!formKey.currentState!.validate()) { return; }
    Navigator.pop(context, <String, dynamic>{'transaction_type': type, 'currency': currency,
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'category_id': usesCategory ? categoryId : null,
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'transaction_date': DateTime(date.year, date.month, date.day, 12).toUtc().toIso8601String()});
  }
  @override
  Widget build(BuildContext context) {
    final categories = [...widget.categories];
    if (categoryId != null && !categories.any((c) => c['id'].toString() == categoryId)) {
      categories.add({'id': categoryId, 'name': 'Categoría actual'});
    }
    return AlertDialog(title: Text(editing ? 'Editar movimiento' : 'Movimiento de tarjeta'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(initialValue: currency,
            decoration: const InputDecoration(labelText: 'Moneda del movimiento'),
            items: const [DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
              DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)'))],
            onChanged: (value) {
              if (value != null) {
                setState(() => currency = value);
              }
            },),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  type = value;
                  if (!usesCategory) {
                    categoryId = null;
                  }
                });
              }
            },),
          const SizedBox(height: 12),
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Monto (${currency == 'USD' ? 'US\$' : 'C\$'})'),
            validator: (v) {
              final text = (v ?? '').trim();
              final n = double.tryParse(text.replaceAll(',', '.'));
              if (n == null || !n.isFinite || n <= 0) { return 'Escribe un monto mayor que cero'; }
              return RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)
                  ? null : 'Usa máximo dos decimales, sin separadores de miles';
            }),
          if (usesCategory) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(key: ValueKey('$type-$categoryId'),
              initialValue: categoryId ?? 'none', isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              items: [const DropdownMenuItem(value: 'none', child: Text('Sin categoría')),
                ...categories.map((c) => DropdownMenuItem(value: c['id'].toString(),
                  child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis)))],
              onChanged: (v) => setState(() => categoryId = v == 'none' ? null : v)),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descripción')),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.calendar_month),
            label: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
            onPressed: () async {
              final today = DateTime.now();
              final selected = await showDatePicker(context: context, initialDate: date,
                firstDate: date.isBefore(DateTime(2000)) ? date : DateTime(2000),
                lastDate: date.isAfter(today) ? date : today);
              if (selected != null && mounted) { setState(() => date = selected); }
            }),
          const SizedBox(height: 12),
          TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
        ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Guardar'))]);
  }
}
