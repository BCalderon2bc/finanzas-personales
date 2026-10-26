import 'package:flutter/material.dart';

class PersonAccountFormDialog extends StatefulWidget {
  const PersonAccountFormDialog({super.key, this.account});
  final Map<String, dynamic>? account;
  @override
  State<PersonAccountFormDialog> createState() =>
      _PersonAccountFormDialogState();
}

class _PersonAccountFormDialogState extends State<PersonAccountFormDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name, notes;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.account?['name']?.toString() ?? '',
    );
    notes = TextEditingController(
      text: widget.account?['notes']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.account == null
          ? 'Nueva cuenta con una persona'
          : 'Editar persona',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la persona',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
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
          if (key.currentState!.validate())
            Navigator.pop(context, <String, dynamic>{
              'name': name.text.trim(),
              'notes': notes.text.trim(),
            });
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
