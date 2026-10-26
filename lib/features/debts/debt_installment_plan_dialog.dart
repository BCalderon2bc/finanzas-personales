import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';

class DebtInstallmentPlanDialog extends StatefulWidget {
  const DebtInstallmentPlanDialog({
    super.key,
    required this.currency,
    this.installment,
  });
  final String currency;
  final Map<String, dynamic>? installment;
  @override
  State<DebtInstallmentPlanDialog> createState() =>
      _DebtInstallmentPlanDialogState();
}

class _DebtInstallmentPlanDialogState extends State<DebtInstallmentPlanDialog> {
  final keyForm = GlobalKey<FormState>();
  final amount = TextEditingController(),
      count = TextEditingController(),
      day = TextEditingController(),
      last = TextEditingController(),
      notes = TextEditingController();
  DateTime first = DateTime.now();
  bool get editing => widget.installment != null;
  @override
  void initState() {
    super.initState();
    day.text = '${first.day}';
    final i = widget.installment;
    if (i != null) {
      amount.text = '${i['amount']}';
      first = statementDate(i['due_date'])!;
      notes.text = i['notes']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [amount, count, day, last, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? valid(String? v, {bool optional = false}) {
    final s = (v ?? '').trim();
    if (optional && s.isEmpty) {
      return null;
    }
    final n = double.tryParse(s.replaceAll(',', '.'));
    return !RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(s) ||
            n == null ||
            !n.isFinite ||
            n <= 0 ||
            n > 999999999999.99
        ? 'Monto positivo, máximo dos decimales, sin separadores de miles.'
        : null;
  }

  void save() {
    if (!keyForm.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'amount': double.parse(amount.text.trim().replaceAll(',', '.')),
      'first_due':
          '${first.year}-${first.month.toString().padLeft(2, '0')}-${first.day.toString().padLeft(2, '0')}',
      'count': int.tryParse(count.text.trim()),
      'day': int.tryParse(day.text.trim()),
      'last': last.text.trim().isEmpty
          ? null
          : double.parse(last.text.trim().replaceAll(',', '.')),
      'notes': notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar cuota' : 'Configurar cuotas mensuales'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: keyForm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Usa el monto y las fechas acordados con el banco o acreedor. El calendario no agrega deuda ni calcula intereses.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto de cuota · ${widget.currency}',
                ),
                validator: (v) => valid(v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${editing ? 'Vencimiento' : 'Primera cuota pendiente'}: ${shortStatementDate(first.toIso8601String())}',
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: first,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null && mounted) {
                    setState(() {
                      first = d;
                      if (!editing) {
                        day.text = '${d.day}';
                      }
                    });
                  }
                },
              ),
              if (!editing) ...[
                TextFormField(
                  controller: count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de cuotas pendientes',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 || n > 600
                        ? 'Indica entre 1 y 600.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: day,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Día habitual mensual',
                    helperText:
                        'Si no existe ese día, se usa el último día del mes.',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 || n > 31
                        ? 'Día del 1 al 31.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: last,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Última cuota, si es diferente (opcional)',
                  ),
                  validator: (v) => valid(v, optional: true),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El nuevo calendario reemplaza al vigente y conserva el anterior con sus pagos en el historial. '
                  'La primera fecha se respeta exactamente; el día habitual se usa desde la segunda cuota.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ],
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
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}
