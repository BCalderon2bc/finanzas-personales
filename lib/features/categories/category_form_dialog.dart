import 'package:flutter/material.dart';

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, this.category, required this.categories});
  final Map<String, dynamic>? category;
  final List<Map<String, dynamic>> categories;
  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}
class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late String type;
  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category?['name']?.toString() ?? '');
    type = widget.category?['category_type']?.toString() ?? 'expense';
  }
  @override
  void dispose() { nameController.dispose(); super.dispose(); }
  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{'name': nameController.text.trim(), 'category_type': type});
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: nameController, autofocus: true, textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Alimentación'),
          textInputAction: TextInputAction.done, onFieldSubmitted: (_) => save(),
          validator: (value) {
            final name = (value ?? '').trim();
            if (name.isEmpty) return 'Escribe el nombre de la categoría';
            final duplicate = widget.categories.any((c) => c['id'] != widget.category?['id'] &&
                c['category_type'] == type && c['name'].toString().trim().toLowerCase() == name.toLowerCase());
            return duplicate ? 'Ya existe una categoría de este tipo con ese nombre' : null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: type, decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(value: 'income', child: Text('Ingreso')),
            DropdownMenuItem(value: 'expense', child: Text('Gasto')),
          ],
          onChanged: widget.category != null ? null : (value) { if (value != null) setState(() => type = value); },
        ),
        if (widget.category != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text(
          'El tipo se conserva para mantener la clasificación del historial.',
        )),
      ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}
