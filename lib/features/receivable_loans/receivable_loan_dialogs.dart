import 'package:flutter/material.dart';
import '../../data/receivable_loan_logic.dart';

String receivableDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String receivableTimestamp(DateTime date) => DateTime(date.year, date.month, date.day, 12).toUtc().toIso8601String();
String? receivableAmountValidator(String? value) {
  final text = (value ?? '').trim();
  final amount = double.tryParse(text.replaceAll(',', '.'));
  if (amount == null || !amount.isFinite || amount < 0) { return 'Introduce un monto válido'; }
  return RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text) ? null : 'Usa máximo dos decimales, sin separadores de miles';
}
double receivableNumber(TextEditingController controller) => double.parse(controller.text.trim().replaceAll(',', '.'));

class ReceivableLoanFormDialog extends StatefulWidget {
  const ReceivableLoanFormDialog({super.key, required this.accounts, required this.creditCards});
  final List<Map<String, dynamic>> accounts, creditCards;
  @override
  State<ReceivableLoanFormDialog> createState() => _ReceivableLoanFormDialogState();
}
class _ReceivableLoanFormDialogState extends State<ReceivableLoanFormDialog> {
  final formKey = GlobalKey<FormState>();
  final borrower = TextEditingController(), amount = TextEditingController();
  final description = TextEditingController(), reference = TextEditingController();
  String currency = 'NIO';
  String? sourceId;
  bool historical = false;
  DateTime date = DateTime.now();
  DateTime? due;
  @override
  void dispose() {
    borrower.dispose(); amount.dispose(); description.dispose(); reference.dispose(); super.dispose();
  }
  void save() {
    if (!formKey.currentState!.validate()) { return; }
    Navigator.pop(context, <String, dynamic>{
      'p_borrower_name': borrower.text.trim(), 'p_principal_amount': receivableNumber(amount),
      'p_currency': currency,
      'p_account_id': !historical && sourceId?.startsWith('account:') == true ? sourceId!.substring(8) : null,
      'p_credit_card_id': !historical && sourceId?.startsWith('credit:') == true ? sourceId!.substring(7) : null,
      'p_is_historical': historical,
      'p_loan_date': receivableTimestamp(date),
      'p_due_date': due == null ? null : '${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
      'p_description': description.text.trim(), 'p_reference': reference.text.trim(),
    });
  }
  @override
  Widget build(BuildContext context) {
    final available = widget.accounts.where((a) => a['is_active'] == true && a['currency'] == currency).toList();
    final sources = <String, String>{
      for (final a in available) 'account:${a['id']}': 'Cuenta / débito · ${a['name']} ($currency)',
      for (final c in widget.creditCards.where((c) => c['is_active'] == true))
        'credit:${c['id']}': 'Crédito · ${c['name']}${(c['card_reference']?.toString() ?? '').isEmpty ? '' : ' · ${c['card_reference']}'}',
    };
    final creditSource = sourceId?.startsWith('credit:') == true;
    return AlertDialog(title: const Text('Dinero que presté'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: borrower, textCapitalization: TextCapitalization.words, autofocus: true,
            decoration: const InputDecoration(labelText: 'Persona a quien prestaste'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: historical,
            title: const Text('Préstamo anterior a mis registros'),
            subtitle: const Text('No descuenta cuentas ni crea cargos nuevos de tarjeta.'),
            onChanged: (v) => setState(() => historical = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: currency,
            decoration: const InputDecoration(labelText: 'Moneda'),
            items: const [DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
              DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)'))],
            onChanged: (v) { if (v != null) { setState(() { currency = v; sourceId = null; }); } }),
          const SizedBox(height: 12),
          TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: historical ? 'Capital que todavía te deben' : 'Capital prestado',
              helperText: historical ? 'Registra solo lo pendiente al comenzar este historial.'
                : creditSource ? 'Se crea un cargo vinculado en tu tarjeta, en la moneda seleccionada.'
                : 'Sale de tu cuenta, sin contarse como gasto.',
              helperMaxLines: 3), validator: (v) {
              final error = receivableAmountValidator(v);
              if (error != null) { return error; }
              return receivableNumber(amount) <= 0 ? 'El capital debe ser mayor que cero' : null;
            }),
          if (!historical) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(key: ValueKey('source-$currency'), initialValue: sourceId,
              isExpanded: true, decoration: const InputDecoration(labelText: 'De dónde salió'),
              items: sources.entries.map((e) => DropdownMenuItem(value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
              validator: (v) => v == null || !sources.containsKey(v) ? 'Selecciona una cuenta o tarjeta activa' : null,
              onChanged: (v) => setState(() => sourceId = v)),
            if (sources.isEmpty) const Text('No hay cuentas en esta moneda ni tarjetas de crédito activas.', style: TextStyle(color: Colors.red)),
            if (creditSource) const Padding(padding: EdgeInsets.only(top: 8),
              child: Text('No registres otra compra manual por este mismo préstamo. El cargo se crea al guardar.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Fecha: ${receivableDate(date)}'), onPressed: () async {
              final selected = await showDatePicker(context: context, initialDate: date,
                firstDate: DateTime(2000), lastDate: DateTime.now());
              if (selected != null && mounted) { setState(() => date = selected); }
            }),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.event_outlined),
            label: Text(due == null ? 'Vencimiento opcional' : 'Vence: ${receivableDate(due!)}'),
            onPressed: () async {
              final selected = await showDatePicker(context: context, initialDate: due ?? date,
                firstDate: DateTime(2000), lastDate: DateTime(2100, 12, 31));
              if (selected != null && mounted) { setState(() => due = selected); }
            }),
          if (due != null) TextButton(onPressed: () => setState(() => due = null), child: const Text('Quitar vencimiento')),
          const SizedBox(height: 12),
          TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
          const SizedBox(height: 12),
          TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
        ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Guardar préstamo'))]);
  }
}

class ReceivableLoanPaymentDialog extends StatefulWidget {
  const ReceivableLoanPaymentDialog({super.key, required this.loan, required this.pendingCents, required this.accounts});
  final Map<String, dynamic> loan;
  final int pendingCents;
  final List<Map<String, dynamic>> accounts;
  @override
  State<ReceivableLoanPaymentDialog> createState() => _ReceivableLoanPaymentDialogState();
}
class _ReceivableLoanPaymentDialogState extends State<ReceivableLoanPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final capital = TextEditingController(text: '0.00'), interest = TextEditingController(text: '0.00');
  final reference = TextEditingController();
  String? accountId;
  DateTime date = DateTime.now();
  String? error;
  @override
  void dispose() { capital.dispose(); interest.dispose(); reference.dispose(); super.dispose(); }
  void save() {
    if (!formKey.currentState!.validate()) { return; }
    final principal = receivableNumber(capital), fees = receivableNumber(interest);
    if ((principal * 100).round() > widget.pendingCents) {
      setState(() => error = 'El capital cobrado supera lo pendiente.'); return;
    }
    if (principal + fees <= 0) { setState(() => error = 'El total debe ser mayor que cero.'); return; }
    Navigator.pop(context, <String, dynamic>{'p_loan_id': widget.loan['id'], 'p_account_id': accountId,
      'p_principal_amount': principal, 'p_interest_amount': fees,
      'p_payment_date': receivableTimestamp(date), 'p_reference': reference.text.trim()});
  }
  @override
  Widget build(BuildContext context) {
    final currency = widget.loan['currency'].toString();
    final loanDate = DateTime.parse(widget.loan['loan_date'].toString()).toLocal();
    final firstDate = DateTime(loanDate.year, loanDate.month, loanDate.day);
    return AlertDialog(title: const Text('Registrar dinero recibido'),
      content: SizedBox(width: 430, child: SingleChildScrollView(child: Form(key: formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.loan['borrower_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8), Text('Capital pendiente: ${receivableMoney(widget.pendingCents, currency)}'),
          const SizedBox(height: 16),
          TextFormField(controller: capital, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: receivableAmountValidator,
            decoration: InputDecoration(labelText: 'Capital devuelto ($currency)', helperText: 'No se cuenta como ingreso.')),
          TextButton(onPressed: () => setState(() => capital.text = (widget.pendingCents / 100).toStringAsFixed(2)),
            child: const Text('Cobrar todo el capital pendiente')),
          const SizedBox(height: 8),
          TextFormField(controller: interest, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: receivableAmountValidator,
            decoration: InputDecoration(labelText: 'Intereses cobrados ($currency)', helperText: 'Sí se cuentan como ingreso.')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: accountId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cuenta que recibe el dinero'),
            items: widget.accounts.map((a) => DropdownMenuItem(value: a['id'].toString(),
              child: Text(a['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
            validator: (v) => v == null ? 'Selecciona una cuenta' : null,
            onChanged: (v) => setState(() => accountId = v)),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.calendar_month_outlined),
            label: Text(receivableDate(date)), onPressed: () async {
              final selected = await showDatePicker(context: context, initialDate: date,
                firstDate: firstDate, lastDate: DateTime.now());
              if (selected != null && mounted) { setState(() => date = selected); }
            }),
          const SizedBox(height: 12),
          TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Registrar cobro'))]);
  }
}
