import 'person_receipts_dialog.dart';
import '../../widgets/adaptive_layout.dart';
import '../help/app_help.dart';
import 'package:flutter/material.dart';
import '../../data/exchange_rate.dart';
import '../../utils/money.dart';

typedef PersonEntryDraft = ({
  Map<String, dynamic> values,
  PendingReceipt? receipt,
});

class PersonEntryDialog extends StatefulWidget {
  const PersonEntryDialog({
    super.key,
    required this.personName,
    this.entry,
    this.defaultRate,
  });
  final String personName;
  final Map<String, dynamic>? entry;
  final ExchangeRate? defaultRate;
  @override
  State<PersonEntryDialog> createState() => _PersonEntryDialogState();
}

class _PersonEntryDialogState extends State<PersonEntryDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      rate = TextEditingController(),
      description = TextEditingController();
  PendingReceipt? _receipt;
  bool _pickingReceipt = false;
  String? _receiptError;

  Future<void> _pickReceipt() async {
    setState(() {
      _pickingReceipt = true;
      _receiptError = null;
    });
    try {
      final selection = await PendingReceipt.pick();
      if (mounted && selection != null) setState(() => _receipt = selection);
    } catch (error) {
      if (mounted) {
        setState(
          () => _receiptError = error is FormatException
              ? error.message
              : 'No se pudo leer el archivo. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingReceipt = false);
    }
  }

  String kind = 'purchase', currency = 'NIO';
  int direction = 1;
  DateTime date = DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    rate.text = widget.defaultRate?.decimal ?? '';
    if (e != null) {
      kind = '${e['kind']}';
      currency = '${e['currency']}';
      direction = int.parse('${e['direction']}');
      amount.text = '${e['amount']}';
      description.text = '${e['description'] ?? ''}';
      if (currency == 'USD') rate.text = '${e['exchange_rate']}';
      date = DateTime.parse('${e['entry_date']}');
    }
  }

  @override
  void dispose() {
    amount.dispose();
    rate.dispose();
    description.dispose();
    super.dispose();
  }

  ExchangeRate? get effectiveRate =>
      ExchangeRate.tryParse(currency == 'NIO' ? '1' : rate.text);
  int? get converted {
    final r = effectiveRate,
        n = num.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (r == null || n == null || !n.isFinite || n <= 0 || n > 1000000000)
      return null;
    return r.convert((n * 100).round(), currency, 'NIO');
  }

  String get plus => switch (kind) {
    'payment' => '${widget.personName} te pagó (+)',
    'opening' => 'Le debías desde antes (+)',
    _ => 'Compra de ${widget.personName} (+)',
  };
  String get minus => switch (kind) {
    'payment' => 'Tú le pagaste (−)',
    'opening' => 'Te debía desde antes (−)',
    _ => 'Compra tuya (−)',
  };
  void save() {
    if (!form.currentState!.validate()) return;
    final cents = converted;
    if (cents == null || cents <= 0 || cents > 100000000000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa el monto convertido: debe ser al menos C\$0.01 y no exceder el límite.',
          ),
        ),
      );
      return;
    }
    Navigator.pop<PersonEntryDraft>(context, (
      receipt: _receipt,
      values: <String, dynamic>{
        'kind': kind,
        'direction': direction,
        'amount': amount.text.trim().replaceAll(',', '.'),
        'currency': currency,
        'exchange_rate': effectiveRate!.decimal,
        'entry_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'description': description.text.trim(),
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cents = converted;
    return GuideScope(
      topic: 'person_form',
      ready: true,
      excludedTargets: {if (currency != 'USD') 'rate'},
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
              child: Text(
                widget.entry == null ? 'Nuevo movimiento' : 'Editar movimiento',
              ),
            ),
            const AppHelpButton(topic: 'people'),
          ],
        ),
        content: SizedBox(
          width: 740,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cuenta con ${widget.personName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 14),
                  AdaptiveColumns(
                    minColumnWidth: 246,
                    children: [
                      GuideAnchor(
                        id: 'kind',
                        child: DropdownButtonFormField<String>(
                          initialValue: kind,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Qué vas a registrar',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'purchase',
                              child: Text('Compra'),
                            ),
                            DropdownMenuItem(
                              value: 'payment',
                              child: Text(
                                'Pago',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'opening',
                              child: Text('Saldo anterior'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => kind = v);
                          },
                        ),
                      ),
                      GuideAnchor(
                        id: 'direction',
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(kind),
                          initialValue: direction,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Quién y cómo afecta el saldo',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 1,
                              child: Text(
                                plus,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: -1,
                              child: Text(
                                minus,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => direction = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AdaptiveColumns(
                    minColumnWidth: 246,
                    children: [
                      GuideAnchor(
                        id: 'currency',
                        child: DropdownButtonFormField<String>(
                          initialValue: currency,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Moneda del movimiento',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'NIO',
                              child: Text('Córdobas (C\$)'),
                            ),
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('Dólares (US\$)'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => currency = v);
                          },
                        ),
                      ),
                      GuideAnchor(
                        id: 'amount',
                        child: TextFormField(
                          controller: amount,
                          autofocus: !compactLayout(context),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Monto',
                            hintText: 'Ej. 1250.50',
                            helperText:
                                'Escribe un monto positivo, sin separadores de miles.',
                            helperMaxLines: 2,
                            errorMaxLines: 3,
                          ),
                          validator: (v) {
                            final text = (v ?? '').trim();
                            final n = num.tryParse(text.replaceAll(',', '.'));
                            return !RegExp(
                                      r'^\d+([.,]\d{1,2})?$',
                                    ).hasMatch(text) ||
                                    n == null ||
                                    !n.isFinite ||
                                    n <= 0 ||
                                    n > 1000000000
                                ? 'Introduce un monto mayor que cero, con máximo dos decimales'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AdaptiveColumns(
                    minColumnWidth: 246,
                    children: [
                      if (currency == 'USD')
                        GuideAnchor(
                          id: 'rate',
                          child: TextFormField(
                            controller: rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Córdobas por US\$1',
                              helperText:
                                  'Esta tasa queda guardada solo en este movimiento.',
                              helperMaxLines: 2,
                              errorMaxLines: 3,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                ExchangeRate.tryParse(v ?? '') == null
                                ? 'Introduce una tasa positiva, con máximo seis decimales'
                                : null,
                          ),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Fecha · ${date.day}/${date.month}/${date.year}',
                        ),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null && mounted)
                            setState(() => date = selected);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      cents == null
                          ? currency == 'USD'
                                ? 'Ingresa el monto y la tasa para ver el efecto en el saldo.'
                                : 'Ingresa el monto para ver el efecto en el saldo.'
                          : '${direction > 0 ? '+' : '−'}${formatMoneyCents(cents, 'NIO')}\n${direction > 0 ? 'Suma al saldo de la cuenta' : 'Resta al saldo de la cuenta'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: description,
                    maxLength: 1000,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
                  ),
                  if (widget.entry == null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickingReceipt ? null : _pickReceipt,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _pickingReceipt
                            ? 'Leyendo archivo…'
                            : _receipt == null
                            ? 'Adjuntar comprobante'
                            : 'Cambiar comprobante',
                      ),
                    ),
                    if (_receipt case final receipt?)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          tooltip: 'Vista previa',
                          onPressed: _pickingReceipt
                              ? null
                              : () => receipt.preview(context),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        onTap: _pickingReceipt
                            ? null
                            : () => receipt.preview(context),
                        title: Text(
                          receipt.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text(
                          'Se subirá al guardar el movimiento',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar comprobante',
                          onPressed: _pickingReceipt
                              ? null
                              : () => setState(() {
                                  _receipt = null;
                                  _receiptError = null;
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    if (_receiptError case final error?)
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'El movimiento se registra en el saldo de esta cuenta personal.',
                    style: TextStyle(fontSize: 12),
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
          GuideAnchor(
            id: 'save',
            child: FilledButton(
              onPressed: _pickingReceipt ? null : save,
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
