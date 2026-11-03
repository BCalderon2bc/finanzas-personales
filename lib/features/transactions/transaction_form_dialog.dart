import '../person_accounts/receipt_draft_field.dart';
import '../../widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import '../../data/transfer_exchange.dart';
import '../../utils/money.dart';
import '../help/app_help.dart';

class TransactionFormDialog extends StatefulWidget {
  const TransactionFormDialog({
    super.key,
    required this.accounts,
    required this.categories,
    this.transaction,
  });

  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? transaction;

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _receipt = ReceiptDraft();
  final formKey = GlobalKey<FormState>();
  final rateController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final referenceController = TextEditingController();
  bool get editing => widget.transaction != null;

  String transactionType = 'expense';
  String? accountId;
  String? destinationAccountId;
  String? categoryId;
  DateTime transactionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx == null) {
      if (widget.accounts.isNotEmpty)
        accountId = widget.accounts.first['id'].toString();
      return;
    }
    transactionType = tx['transaction_type'].toString();
    accountId = tx['account_id'].toString();
    destinationAccountId = tx['destination_account_id']?.toString();
    categoryId = tx['category_id']?.toString();
    amountController.text = tx['amount'].toString();
    rateController.text = tx['exchange_rate']?.toString() ?? '';
    descriptionController.text = tx['description']?.toString() ?? '';
    referenceController.text = tx['reference']?.toString() ?? '';
    transactionDate = DateTime.parse(
      tx['transaction_date'].toString(),
    ).toLocal();
  }

  @override
  void dispose() {
    rateController.dispose();
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

  List<Map<String, dynamic>> get filteredCategories => widget.categories
      .where((c) => c['category_type'] == transactionType)
      .toList();

  List<Map<String, dynamic>> get availableDestinations =>
      widget.accounts.where((a) => a['id'].toString() != accountId).toList();

  String get destinationCurrency =>
      widget.accounts
          .where((a) => '${a['id']}' == destinationAccountId)
          .map((a) => '${a['currency']}')
          .firstOrNull ??
      selectedCurrency;
  bool get crossCurrency =>
      transactionType == 'transfer' &&
      destinationAccountId != null &&
      destinationCurrency != selectedCurrency;
  int? get receivedCents {
    try {
      return transferReceivedCents(
        moneyCents(amountController.text.trim().replaceAll(',', '.')),
        selectedCurrency,
        destinationCurrency,
        double.parse(rateController.text.trim().replaceAll(',', '.')),
      );
    } catch (_) {
      return null;
    }
  }

  void save() {
    if (_receipt.picking) return;
    if (!formKey.currentState!.validate()) return;
    final amount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || !amount.isFinite || amount <= 0) return;

    if (transactionType == 'transfer') {
      if (destinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona la cuenta de destino.')),
        );
        return;
      }
      if (!availableDestinations.any(
        (a) => a['id'].toString() == destinationAccountId,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona otra cuenta como destino.')),
        );
        return;
      }
    }

    Navigator.of(context).pop(<String, dynamic>{
      ..._receipt.fields,
      if (crossCurrency) ...{
        'destination_amount': receivedCents! / 100,
        'destination_currency': destinationCurrency,
        'exchange_rate': double.parse(
          rateController.text.trim().replaceAll(',', '.'),
        ),
      },
      'account_id': accountId,
      'destination_account_id': transactionType == 'transfer'
          ? destinationAccountId
          : null,
      'category_id': transactionType == 'transfer' ? null : categoryId,
      'transaction_type': transactionType,
      'amount': amount,
      'currency': selectedCurrency,
      'transaction_date': DateTime(
        transactionDate.year,
        transactionDate.month,
        transactionDate.day,
        12,
      ).toUtc().toIso8601String(),
      'description': descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      'reference': referenceController.text.trim().isEmpty
          ? null
          : referenceController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return GuideScope(
      topic: 'movement_form',
      ready: true,
      excludedTargets: {
        if (transactionType != 'transfer') 'destination',
        if (!crossCurrency) 'rate',
      },
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compactLayout(context) ? 12 : 40,
          vertical: compactLayout(context) ? 12 : 24,
        ),
        contentPadding: EdgeInsets.fromLTRB(
          compactLayout(context) ? 16 : 24,
          12,
          compactLayout(context) ? 16 : 24,
          16,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(editing ? 'Editar movimiento' : 'Nuevo movimiento'),
            ),
            const AppHelpButton(topic: 'movements'),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuideAnchor(
                    id: 'type',
                    child: DropdownButtonFormField<String>(
                      initialValue: transactionType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de movimiento',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'income',
                          child: Text('Ingreso'),
                        ),
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Gasto'),
                        ),
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transferencia'),
                        ),
                      ],
                      onChanged: editing
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                transactionType = value;
                                categoryId = null;
                                destinationAccountId = null;
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 14),
                  GuideAnchor(
                    id: 'origin',
                    child: DropdownButtonFormField<String>(
                      initialValue: accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta de origen',
                      ),
                      items: widget.accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a['id'].toString(),
                              child: Text(
                                '${a['name']} (${a['currency'] == 'USD' ? 'US\$' : 'C\$'})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: editing
                          ? null
                          : (value) => setState(() {
                              accountId = value;
                              destinationAccountId = null;
                            }),
                      validator: (value) =>
                          value == null ? 'Selecciona una cuenta' : null,
                    ),
                  ),
                  if (transactionType == 'transfer') ...[
                    const SizedBox(height: 14),
                    GuideAnchor(
                      id: 'destination',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'destination-$accountId-$destinationAccountId',
                        ),
                        initialValue:
                            availableDestinations.any(
                              (a) => a['id'].toString() == destinationAccountId,
                            )
                            ? destinationAccountId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Cuenta de destino',
                        ),
                        items: availableDestinations
                            .map(
                              (a) => DropdownMenuItem(
                                value: a['id'].toString(),
                                child: Text('${a['name']} (${a['currency']})'),
                              ),
                            )
                            .toList(),
                        onChanged: editing
                            ? null
                            : (value) =>
                                  setState(() => destinationAccountId = value),
                        validator: (value) => value == null
                            ? 'Selecciona la cuenta destino'
                            : null,
                      ),
                    ),
                    if (availableDestinations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No hay otras cuentas activas.'),
                      ),
                  ] else if (filteredCategories.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue:
                          filteredCategories.any(
                            (c) => c['id'].toString() == categoryId,
                          )
                          ? categoryId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (opcional)',
                      ),
                      items: filteredCategories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'].toString(),
                              child: Text(c['name'].toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => categoryId = value),
                    ),
                  ] else if (transactionType != 'transfer') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'No hay categorías de este tipo. Puedes guardar el movimiento sin categoría.',
                    ),
                  ],
                  const SizedBox(height: 14),
                  GuideAnchor(
                    id: 'amount',
                    child: TextFormField(
                      controller: amountController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Monto (${selectedCurrency == 'USD' ? 'US\$' : 'C\$'})',
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (amount == null || !amount.isFinite || amount <= 0)
                          return 'Escribe un monto mayor que cero';
                        if (!RegExp(
                          r'^\d+([.,]\d{1,2})?$',
                        ).hasMatch((value ?? '').trim())) {
                          return 'Usa como máximo dos decimales, sin separadores de miles';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (crossCurrency) ...[
                    const SizedBox(height: 14),
                    GuideAnchor(
                      id: 'rate',
                      child: TextFormField(
                        controller: rateController,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tasa: Córdobas por US\$ 1',
                          helperText:
                              'Usa la tasa aplicada por tu banco. Máximo seis decimales.',
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          final rate = double.tryParse(
                            text.replaceAll(',', '.'),
                          );
                          if (!RegExp(r'^\d+([.,]\d{1,6})?$').hasMatch(text) ||
                              rate == null ||
                              !rate.isFinite ||
                              rate <= 0 ||
                              rate > 1000000)
                            return 'Introduce una tasa positiva válida';
                          if (receivedCents == null)
                            return 'Revisa el monto recibido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      receivedCents == null
                          ? 'Introduce monto y tasa para ver cuánto recibe la otra cuenta.'
                          : 'Sale: ${amountController.text} $selectedCurrency\nRecibe: ${formatMoneyCents(receivedCents!, destinationCurrency)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej. Salario, supermercado, gasolina',
                    ),
                  ),
                  const SizedBox(height: 14),
                  GuideAnchor(
                    id: 'date',
                    child: InkWell(
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: transactionDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null && mounted)
                          setState(() => transactionDate = selected);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha del movimiento',
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          '${transactionDate.day.toString().padLeft(2, '0')}/${transactionDate.month.toString().padLeft(2, '0')}/${transactionDate.year}',
                        ),
                      ),
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
          if (widget.transaction == null) ReceiptDraftField(draft: _receipt),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          GuideAnchor(
            id: 'save',
            child: FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
