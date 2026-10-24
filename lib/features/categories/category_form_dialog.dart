import 'package:flutter/material.dart';
import '../../widgets/category_style.dart';

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key, this.category, required this.categories,
  });
  final Map<String, dynamic>? category;
  final List<Map<String, dynamic>> categories;
  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late String type, iconKey, colorHex;
  bool get editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    nameController = TextEditingController(text: category?['name']?.toString() ?? '');
    type = category?['category_type']?.toString() ?? 'expense';
    iconKey = category?['icon']?.toString() ?? 'category';
    final hex = category?['color']?.toString().replaceAll('#', '').trim() ?? '';
    colorHex = RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(hex)
        ? '#${hex.toUpperCase()}' : type == 'income' ? '#047857' : '#2563EB';
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': nameController.text.trim(),
      'category_type': type,
      'icon': iconKey,
      'color': colorHex,
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(colorHex);
    return AlertDialog(
      title: Text(editing ? 'Editar categoría' : 'Nueva categoría'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: color.withAlpha(12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withAlpha(40))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(15)),
                      child: Icon(categoryIcon(iconKey), color: Colors.white, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nameController.text.trim().isEmpty
                        ? 'Tu categoría' : nameController.text.trim(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(type == 'income' ? 'Ingreso' : 'Gasto',
                        style: TextStyle(color: color, fontSize: 12)),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nombre', hintText: 'Ej. Alimentación'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => save(),
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.isEmpty) return 'Escribe el nombre de la categoría';
                  final editingId = widget.category?['id'];
                  final duplicate = widget.categories.any((c) =>
                  c['id'] != editingId && c['category_type'] == type &&
                      c['name'].toString().trim().toLowerCase() == name.toLowerCase());
                  return duplicate ? 'Ya existe una categoría de este tipo con ese nombre' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                ],
                onChanged: editing ? null : (value) {
                  if (value != null) setState(() => type = value);
                },
              ),
              if (editing) const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('El tipo se conserva para mantener la clasificación del historial.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
              const SizedBox(height: 22),
              const Text('Icono', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...categoryIconOptions.entries.map((entry) {
                  final selected = iconKey == entry.key;
                  return Semantics(
                    selected: selected,
                    child: IconButton(
                      tooltip: entry.value.$2,
                      onPressed: () => setState(() => iconKey = entry.key),
                      style: IconButton.styleFrom(
                          backgroundColor: selected ? color : const Color(0xFFF1F5F9),
                          foregroundColor: selected ? Colors.white : const Color(0xFF64748B),
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: Icon(entry.value.$1, size: 23),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 22),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...categoryColorOptions.map((hex) {
                  final selected = colorHex == hex;
                  return Semantics(
                    label: 'Color $hex', selected: selected,
                    child: Material(
                      color: categoryColor(hex), shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => colorHex = hex),
                        child: SizedBox(
                            width: 44, height: 44,
                            child: selected
                                ? const Icon(Icons.check_rounded, color: Colors.white)
                                : null),
                      ),
                    ),
                  );
                }),
              ]),
            ],
          ),
        )),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: save, child: const Text('Guardar')),
      ],
    );
  }
}