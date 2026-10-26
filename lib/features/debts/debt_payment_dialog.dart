import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../data/card_statement_logic.dart';

class DebtPaymentDialog extends StatefulWidget {
  const DebtPaymentDialog({
    super.key,
    required this.currency,
    required this.remainingCents,
    required this.accounts,
    this.installments = const [],
    this.initialInstallmentId,
    this.expectedTotalCents,
  });
  final String currency;
  final int remainingCents;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> installments;
  final String? initialInstallmentId;
  final int? expectedTotalCents;

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final principal = TextEditingController(text: '0.00');
  final interest = TextEditingController(text: '0.00');
  final fee = TextEditingController(text: '0.00');
  final reference = TextEditingController();
  DateTime date = DateTime.now();
  String? error;
  String? accountId, installmentId;
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
    if (!formKey.currentState!.validate()) return;
    final capital = cents(principal),
        interests = cents(interest),
        fees = cents(fee);
    if (capital + interests + fees <= 0) {
      setState(() => error = 'El abono total debe ser mayor que cero.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'principal_amount': capital / 100,
      'interest_amount': interests / 100,
      'fee_amount': fees / 100,
      'payment_date': DateTime(
        date.year,
        date.month,
        date.day,
        12,
      ).toUtc().toIso8601String(),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'account_id': accountId,
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
                      'Indica el desglose real de capital, intereses y comisiones.',
                    ),
                  ),
                amountField(
                  'Abono a capital ($symbol)',
                  principal,
                  capital: true,
                ),
                amountField('Intereses pagados ($symbol)', interest),
                amountField('Comisiones pagadas ($symbol)', fee),
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
                const Text(
                  'Se descontará de la cuenta el total de capital, intereses y comisiones.',
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: save, child: const Text('Guardar abono')),
      ],
    );
  }
}
