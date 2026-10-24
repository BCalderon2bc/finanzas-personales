import 'package:flutter/material.dart';
import 'loan_schedule.dart';

class LoanSimulatorDialog extends StatefulWidget {
  const LoanSimulatorDialog({super.key, required this.principalCents, required this.currency});
  final int principalCents;
  final String currency;
  @override
  State<LoanSimulatorDialog> createState() => _LoanSimulatorDialogState();
}
class _LoanSimulatorDialogState extends State<LoanSimulatorDialog> {
  final formKey = GlobalKey<FormState>();
  final rate = TextEditingController(text: '0'), months = TextEditingController(text: '12');
  String method = 'reducing_balance';
  DateTime firstDue = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
  List<LoanInstallment> schedule = [];
  String? error;

  @override
  void dispose() { rate.dispose(); months.dispose(); super.dispose(); }

  String money(int cents) =>
      '${widget.currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';
  String dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  void clearResult() => setState(() { schedule = []; error = null; });

  void calculate() {
    if (!formKey.currentState!.validate()) return;
    try {
      final result = buildLoanSchedule(
        principalCents: widget.principalCents,
        months: int.parse(months.text.trim()),
        annualRate: method == 'none' ? 0 : double.parse(rate.text.trim().replaceAll(',', '.')),
        method: method, firstDue: firstDue,
      );
      setState(() { schedule = result; error = null; });
    } on FormatException catch (e) {
      setState(() { schedule = []; error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final interest = schedule.fold<int>(0, (sum, row) => sum + row.interest);
    return AlertDialog(
      title: const Text('Simular cuotas'),
      content: SizedBox(
        width: 620, height: MediaQuery.sizeOf(context).height * 0.7,
        child: SingleChildScrollView(child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Capital a simular: ${money(widget.principalCents)}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modelo estimado'),
              items: const [
                DropdownMenuItem(value: 'reducing_balance', child: Text('Cuota fija sobre saldo')),
                DropdownMenuItem(value: 'flat', child: Text('Interés sobre capital inicial')),
                DropdownMenuItem(value: 'none', child: Text('Sin intereses')),
              ],
              onChanged: (value) {
                if (value != null) setState(() { method = value; schedule = []; error = null; });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: rate, enabled: method != 'none',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tasa nominal anual (%)'),
              onChanged: (_) => clearResult(),
              validator: (value) {
                if (method == 'none') return null;
                final text = (value ?? '').trim();
                final number = double.tryParse(text.replaceAll(',', '.'));
                if (number == null || !number.isFinite || number < 0) return 'Introduce una tasa válida';
                if (!RegExp(r'^\d+([.,]\d{1,4})?$').hasMatch(text)) return 'Usa máximo cuatro decimales';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: months, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Meses a simular'),
              onChanged: (_) => clearResult(),
              validator: (value) {
                final number = int.tryParse((value ?? '').trim());
                return number == null || number < 1 || number > 600
                    ? 'Introduce de 1 a 600 meses' : null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text('Primera cuota: ${dateText(firstDue)}'),
              onPressed: () async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: context, initialDate: firstDue,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 50, 12, 31),
                );
                if (selected != null && mounted) {
                  setState(() { firstDue = selected; schedule = []; error = null; });
                }
              },
            ),
            const SizedBox(height: 8),
            const Text('Estimación desde el capital pendiente. No incluye intereses ya vencidos, seguros, comisiones ni mora. En el modelo flat, el interés usa el capital inicial de esta simulación.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: calculate, child: const Text('Calcular')),
            if (error != null) Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (schedule.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Intereses estimados: ${money(interest)}'),
              Text('Total estimado: ${money(widget.principalCents + interest)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...schedule.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Cuota ${row.number} · ${dateText(row.date)} · ${money(row.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Capital: ${money(row.principal)} · Intereses: ${money(row.interest)}'),
                  Text('Capital restante: ${money(row.balance)}'),
                ]),
              )),
            ],
          ]),
        )),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}