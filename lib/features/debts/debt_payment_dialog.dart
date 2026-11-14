import '../person_accounts/receipt_draft_field.dart';
import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../data/card_statement_logic.dart';

class DebtPaymentDialog extends StatefulWidget {
  const DebtPaymentDialog({
    super.key,
    required this.currency,
    required this.remainingCents,
    required this.accounts,
    this.expenses = const [],
    this.installments = const [],
    this.initialInstallmentId,
    this.expectedTotalCents,
  });
  final String currency;
  final int remainingCents;
  final List<Map<String, dynamic>> accounts, expenses;
  final List<Map<String, dynamic>> installments;
  final String? initialInstallmentId;
  final int? expectedTotalCents;

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final _receipt = ReceiptDraft();
  final formKey = GlobalKey<FormState>();
  final principal = TextEditingController(text: '0.00');
  final interest = TextEditingController(text: '0.00');
  final insurance = TextEditingController(text: '0.00');
  final fee = TextEditingController(text: '0.00');
  final reference = TextEditingController();
  DateTime date = DateTime.now();
  String? error;
  String? accountId, installmentId;
  Map<String, dynamic>? expense;
  @override
  void initState() {
    super.initState();
    installmentId =
        widget.initialInstallmentId ??
        (widget.installments.isEmpty
            ? null
            : '${widget.installments.first['id']}');
  }

  @override
  void dispose() {
    principal.dispose();
    interest.dispose();
    fee.dispose();
    insurance.dispose();
    reference.dispose();
    super.dispose();
  }

  int cents(TextEditingController controller) =>
      (double.parse(controller.text.trim().replaceAll(',', '.')) * 100).round();

  Widget amountField(
    String label,
    TextEditingController controller, {
    bool capital = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = (value ?? '').trim();
        final amount = double.tryParse(text.replaceAll(',', '.'));
        if (amount == null || !amount.isFinite || amount < 0)
          return 'Introduce un monto válido';
        if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text))
          return 'Usa máximo dos decimales, sin separadores de miles';
        if (capital && (amount * 100).round() > widget.remainingCents)
          return 'Supera el capital pendiente';
        return null;
      },
    ),
  );

  void save() {
    if (_receipt.picking) return;
    if (!formKey.currentState!.validate()) return;
    final capital = cents(principal),
        interests = cents(interest),
        fees = cents(fee),
        insured = cents(insurance);
    if (capital + interests + fees + insured <= 0) {
      setState(() => error = 'El abono total debe ser mayor que cero.');
      return;
    }
    if (expense != null &&
        capital + interests + fees + insured !=
            moneyCents(expense!['amount'])) {
      setState(
        () => error = 'El total debe coincidir con el movimiento asociado.',
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      ..._receipt.fields,
      'principal_amount': capital / 100,
      'interest_amount': interests / 100,
      'insurance_amount': insured / 100,
      'fee_amount': fees / 100,
      'payment_date': DateTime(
        date.year,
        date.month,
        date.day,
        12,
      ).toUtc().toIso8601String(),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'account_id': accountId,
      'transaction_id': expense?['id'],
      'installment_id': installmentId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.currency == 'USD' ? 'US\$' : 'C\$';
    return AlertDialog(
      title: const Text('Registrar abono'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.expenses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Movimiento asociado',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Registrar nuevo débito'),
                      ),
                      for (final row in widget.expenses)
                        DropdownMenuItem(
                          value: '${row['id']}',
                          child: Text(
                            "${shortStatementDate(row['transaction_date'])} · "
                            "${formatMoneyCents(moneyCents(row['amount']), widget.currency)} · "
                            "${row['description'] ?? 'Gasto'}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      expense = widget.expenses
                          .where((row) => '${row['id']}' == id)
                          .firstOrNull;
                      error = null;
                    }),
                  ),
                if (widget.expenses.isNotEmpty) const SizedBox(height: 12),
                if (expense == null)
                  DropdownButtonFormField<String>(
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
                              a['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => accountId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una cuenta' : null,
                  ),
                const SizedBox(height: 12),
                Text(
                  'Capital pendiente: ${formatMoneyCents(widget.remainingCents, widget.currency)}',
                ),
                const SizedBox(height: 12),
                if (widget.expectedTotalCents != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Cuota pendiente: ${formatMoneyCents(widget.expectedTotalCents!, widget.currency)}. '
                      'Indica el desglose real de capital, intereses, seguro y otros cargos.',
                    ),
                  ),
                amountField(
                  'Abono a capital ($symbol)',
                  principal,
                  capital: true,
                ),
                amountField('Intereses pagados ($symbol)', interest),
                amountField('Seguro pagado ($symbol)', insurance),
                amountField('Otros cargos y comisiones ($symbol)', fee),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Total del abono: ${formatMoneyCents([principal, interest, insurance, fee].fold<int>(0, (total, c) => total + ((double.tryParse(c.text.replaceAll(',', '.')) ?? 0) * 100).round()), widget.currency)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (expense == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    ),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null && mounted)
                        setState(() => date = selected);
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.installments.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: installmentId ?? 'none',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Aplicar abono a cuota',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'none',
                        child: Text('Sin asignar a una cuota'),
                      ),
                      ...widget.installments.map(
                        (i) => DropdownMenuItem(
                          value: '${i['id']}',
                          child: Text(
                            'Cuota ${i['number']} · ${shortStatementDate(i['due_date'])}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => installmentId = v == 'none' ? null : v),
                  ),
                  const SizedBox(height: 10),
                ],
                if (expense == null)
                  const Text('El total se descontará de la cuenta.')
                else
                  const Text(
                    'El movimiento existente se mostrará como abono. Se conservarán su cuenta y fecha.',
                  ),

                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        ReceiptDraftField(draft: _receipt),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: save, child: const Text('Guardar abono')),
      ],
    );
  }
}
