import 'package:flutter/material.dart';

class BudgetFormDialog extends StatefulWidget {
  const BudgetFormDialog({super.key, required this.categories, this.budget});
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? budget;
  @override
  State<BudgetFormDialog> createState() => _BudgetFormDialogState();
}
class _BudgetFormDialogState extends State<BudgetFormDialog> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  String? categoryId;
  String currency = 'NIO';
  bool get editing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    if (budget != null) {
      categoryId = budget['category_id'].toString();
      currency = budget['currency'].toString();
      amountController.text = budget['budget_amount'].toString();
    }
  }
  @override
  void dispose() { amountController.dispose(); super.dispose(); }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'category_id': categoryId,
      'currency': currency,
      'budget_amount': double.parse(amountController.text.trim().replaceAll(',', '.')),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar presupuesto' : 'Nuevo presupuesto'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: categoryId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Categoría de gasto'),
        items: widget.categories.map((c) => DropdownMenuItem(
          value: c['id'].toString(),
          child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: editing ? null : (value) => setState(() => categoryId = value),
        validator: (value) => value == null ? 'Selecciona una categoría' : null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: currency, decoration: const InputDecoration(labelText: 'Moneda'),
        items: const [
          DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
          DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
        ],
        onChanged: editing ? null : (value) {
          if (value != null) setState(() => currency = value);
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Límite mensual'),
        validator: (value) {
          final text = (value ?? '').trim();
          final amount = double.tryParse(text.replaceAll(',', '.'));
          if (amount == null || !amount.isFinite || amount <= 0) return 'Introduce un monto mayor que cero';
          if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa como máximo dos decimales, sin separadores de miles';
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