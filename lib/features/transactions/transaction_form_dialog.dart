import 'package:flutter/material.dart';

class TransactionFormDialog extends StatefulWidget {
  const TransactionFormDialog({
    super.key,
    required this.accounts,
    required this.categories,
  });

  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final referenceController = TextEditingController();

  String transactionType = 'expense';
  String? accountId;
  String? destinationAccountId;
  String? categoryId;
  DateTime transactionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) accountId = widget.accounts.first['id'].toString();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  String get selectedCurrency {
    for (final account in widget.accounts) {
      if (account['id'].toString() == accountId) {
        return account['currency']?.toString() ?? 'NIO';
      }
    }
    return 'NIO';
  }

  List<Map<String, dynamic>> get filteredCategories =>
      widget.categories.where((c) => c['category_type'] == transactionType).toList();

  List<Map<String, dynamic>> get availableDestinations =>
      widget.accounts.where((a) =>
        a['id'].toString() != accountId &&
        a['currency']?.toString() == selectedCurrency
      ).toList();

  void save() {
    if (!formKey.currentState!.validate()) return;
    final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || !amount.isFinite || amount <= 0) return;

    if (transactionType == 'transfer') {
      if (destinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona la cuenta de destino.')),
        );
        return;
      }
      if (!availableDestinations.any((a) => a['id'].toString() == destinationAccountId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El destino debe ser otra cuenta en la misma moneda.')),
        );
        return;
      }
    }

    Navigator.of(context).pop(<String, dynamic>{
      'account_id': accountId,
      'destination_account_id': transactionType == 'transfer' ? destinationAccountId : null,
      'category_id': transactionType == 'transfer' ? null : categoryId,
      'transaction_type': transactionType,
      'amount': amount,
      'currency': selectedCurrency,
      'transaction_date': DateTime(transactionDate.year, transactionDate.month, transactionDate.day, 12).toUtc().toIso8601String(),
      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      'reference': referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo movimiento'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: transactionType,
                  decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                    DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      transactionType = value;
                      categoryId = null;
                      destinationAccountId = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cuenta de origen'),
                  items: widget.accounts.map((a) => DropdownMenuItem(
                    value: a['id'].toString(),
                    child: Text('${a['name']} (${a['currency'] == 'USD' ? 'US\$' : 'C\$'})'),
                  )).toList(),
                  onChanged: (value) => setState(() {
                    accountId = value;
                    destinationAccountId = null;
                  }),
                  validator: (value) => value == null ? 'Selecciona una cuenta' : null,
                ),
                if (transactionType == 'transfer') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: availableDestinations.any((a) => a['id'].toString() == destinationAccountId)
                        ? destinationAccountId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cuenta de destino'),
                    items: availableDestinations.map((a) => DropdownMenuItem(
                      value: a['id'].toString(),
                      child: Text(a['name'].toString()),
                    )).toList(),
                    onChanged: (value) => setState(() => destinationAccountId = value),
                    validator: (value) => value == null ? 'Selecciona la cuenta destino' : null,
                  ),
                  if (availableDestinations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No hay otras cuentas activas en la misma moneda.'),
                    ),
                ] else if (filteredCategories.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: filteredCategories.any((c) => c['id'].toString() == categoryId) ? categoryId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
                    items: filteredCategories.map((c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name'].toString()),
                    )).toList(),
                    onChanged: (value) => setState(() => categoryId = value),
                  ),
                ] else if (transactionType != 'transfer') ...[
                  const SizedBox(height: 10),
                  const Text('No hay categorías de este tipo. Puedes guardar el movimiento sin categoría.'),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monto (${selectedCurrency == 'USD' ? 'US\$' : 'C\$'})',
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                    if (amount == null || !amount.isFinite || amount <= 0) return 'Escribe un monto mayor que cero';
                    if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch((value ?? '').trim())) {
                      return 'Usa como máximo dos decimales, sin separadores de miles';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej. Salario, supermercado, gasolina',
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: transactionDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null && mounted) setState(() => transactionDate = selected);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha del movimiento',
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                    child: Text('${transactionDate.day.toString().padLeft(2, '0')}/${transactionDate.month.toString().padLeft(2, '0')}/${transactionDate.year}'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: referenceController,
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
