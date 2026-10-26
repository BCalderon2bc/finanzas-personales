import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';

class CreditCardPaymentDialog extends StatefulWidget {
  const CreditCardPaymentDialog({super.key, required this.accounts, required this.currency, this.statements = const [], this.initialStatementId, this.initialAmountCents});
  final List<Map<String, dynamic>> accounts;
  final String currency;
  final List<Map<String,dynamic>> statements;
  final String? initialStatementId;
  final int? initialAmountCents;
  @override
  State<CreditCardPaymentDialog> createState() => _CreditCardPaymentDialogState();
}
class _CreditCardPaymentDialogState extends State<CreditCardPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController(), reference = TextEditingController();
  String? accountId, statementId;

  @override
  void initState() {
    super.initState();
    if(widget.initialAmountCents != null) { amount.text=(widget.initialAmountCents!/100).toStringAsFixed(2); }
    statementId=widget.initialStatementId ?? (widget.statements.length==1?'${widget.statements.first['id']}':null);
  }

  @override
  void dispose() { amount.dispose(); reference.dispose(); super.dispose(); }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'account_id': accountId,
      'statement_id': statementId,
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pagar tarjeta'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: accountId, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Cuenta de donde sale el dinero'),
        items: widget.accounts.map((a) => DropdownMenuItem(
          value: a['id'].toString(),
          child: Text(a['name'].toString(), overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (value) => setState(() => accountId = value),
        validator: (value) => value == null ? 'Selecciona una cuenta' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Monto (${widget.currency})'),
          validator: (value) {
            final text = (value ?? '').trim();
            final number = double.tryParse(text.replaceAll(',', '.'));
            if (number == null || !number.isFinite || number <= 0) return 'Escribe un monto mayor que cero';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
            return null;
          }),
      const SizedBox(height: 12),
      if(widget.statements.isNotEmpty) ...[
        DropdownButtonFormField<String>(initialValue:statementId??'none',isExpanded:true,
          decoration:const InputDecoration(labelText:'Aplicar al estado de cuenta'),
          items:[const DropdownMenuItem(value:'none',child:Text('Sin asignar a un corte')),
            ...widget.statements.map((s)=>DropdownMenuItem(value:'${s['id']}',
              child:Text('Corte ${shortStatementDate(s['closing_date'])}',overflow:TextOverflow.ellipsis)))],
          onChanged:(v)=>setState(()=>statementId=v=='none'?null:v)),
        const SizedBox(height:8),
        const Text('Asigna solo pagos que no estén descontados del saldo al corte registrado.',
          style:TextStyle(fontSize:12,color:Color(0xFF64748B))),
        const SizedBox(height:12),
      ],
      TextFormField(controller: reference,
          decoration: const InputDecoration(labelText: 'Referencia (opcional)')),
    ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Registrar pago')),
    ],
  );
}