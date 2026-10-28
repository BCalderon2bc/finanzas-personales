import 'package:flutter/material.dart';
import '../../data/zero_plan_logic.dart';

class ZeroField {
  const ZeroField(
    this.key,
    this.label, {
    this.type = 'text',
    this.options,
    this.required = true,
    this.zero = false,
    this.signed = false,
    this.readOnly = false,
  });
  final String key, label, type;
  final Map<String, String>? options;
  final bool required, zero, signed, readOnly;
}

class ZeroForm extends StatefulWidget {
  const ZeroForm({
    super.key,
    required this.title,
    required this.fields,
    this.initial = const {},
    this.info,
  });
  final String title;
  final List<ZeroField> fields;
  final Map<String, dynamic> initial;
  final String? info;
  @override
  State<ZeroForm> createState() => _ZeroFormState();
}

class _ZeroFormState extends State<ZeroForm> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  @override
  void initState() {
    super.initState();
    values.addAll(widget.initial);
    for (final f in widget.fields) {
      controllers[f.key] = TextEditingController(
        text: '${values[f.key] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.info != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(widget.info!),
                ),
              ...widget.fields.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: field(f),
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
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final result = <String, dynamic>{};
          for (final f in widget.fields) {
            if (f.type == 'bool')
              result[f.key] = values[f.key] ?? false;
            else if (f.type == 'choice' || f.type == 'date')
              result[f.key] = values[f.key] == '' ? null : values[f.key];
            else {
              final text = controllers[f.key]!.text.trim();
              result[f.key] = text.isEmpty
                  ? null
                  : f.type == 'money'
                  ? text.replaceAll(',', '.')
                  : text;
            }
          }
          Navigator.pop(context, result);
        },
        child: const Text('Guardar'),
      ),
    ],
  );
  Widget field(ZeroField f) {
    if (f.type == 'bool')
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(f.label),
        value: values[f.key] == true,
        onChanged: f.readOnly ? null : (v) => setState(() => values[f.key] = v),
      );
    if (f.type == 'choice')
      return DropdownButtonFormField<String>(
        initialValue: values[f.key]?.toString(),
        isExpanded: true,
        decoration: InputDecoration(labelText: f.label),
        items: f.options!.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: f.readOnly ? null : (v) => values[f.key] = v,
        validator: (v) => f.required && (v == null || v.isEmpty)
            ? 'Selecciona una opción'
            : null,
      );
    if (f.type == 'date')
      return FormField<String>(
        initialValue: values[f.key]?.toString(),
        validator: (_) =>
            f.required && values[f.key] == null ? 'Selecciona una fecha' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '${f.label}: ${values[f.key] == null ? 'Sin fecha' : zeroDateLabel(values[f.key])}',
              ),
              onPressed: f.readOnly
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse('${values[f.key]}') ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null && mounted)
                        setState(() {
                          values[f.key] = zeroDate(d);
                          state.didChange(values[f.key]);
                        });
                    },
            ),
            if (!f.required && values[f.key] != null)
              TextButton(
                onPressed: () => setState(() {
                  values[f.key] = null;
                  state.didChange(null);
                }),
                child: const Text('Quitar fecha'),
              ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    return TextFormField(
      controller: controllers[f.key],
      readOnly: f.readOnly,
      maxLength: f.type == 'money'
          ? null
          : f.key == 'description'
          ? 200
          : f.key == 'notes'
          ? 1000
          : 120,
      maxLines: f.key == 'notes' || f.key == 'description' ? 2 : 1,
      decoration: InputDecoration(
        labelText: f.label,
        helperText: f.type == 'money' ? 'Sin separadores de miles' : null,
      ),
      keyboardType: f.type == 'money'
          ? TextInputType.numberWithOptions(decimal: true, signed: f.signed)
          : TextInputType.text,
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return f.required ? 'Completa este campo' : null;
        if (f.type == 'money') {
          final n = num.tryParse(s.replaceAll(',', '.'));
          final pattern = f.signed
              ? r'^-?\d+([.,]\d{1,2})?$'
              : r'^\d+([.,]\d{1,2})?$';
          if (!RegExp(pattern).hasMatch(s) ||
              n == null ||
              !n.isFinite ||
              n.abs() > 1000000000 ||
              (!f.signed && (n < 0 || (!f.zero && n == 0))))
            return 'Monto inválido. Usa máximo dos decimales.';
        }
        return null;
      },
    );
  }
}

Future<Map<String, dynamic>?> zeroForm(
  BuildContext context,
  String title,
  List<ZeroField> fields, {
  Map<String, dynamic> initial = const {},
  String? info,
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) =>
      ZeroForm(title: title, fields: fields, initial: initial, info: info),
);
