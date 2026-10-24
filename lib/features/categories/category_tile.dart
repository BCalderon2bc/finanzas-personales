import 'package:flutter/material.dart';
import '../../widgets/category_style.dart';

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key, required this.category, this.onEdit, this.onToggle,
  });
  final Map<String, dynamic> category;
  final VoidCallback? onEdit, onToggle;

  @override
  Widget build(BuildContext context) {
    final income = category['category_type'] == 'income';
    final active = category['is_active'] == true;
    final color = categoryColor(category['color'], income: income);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: color.withAlpha(active ? 18 : 9),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(categoryIcon(category['icon']),
                    color: active ? color : const Color(0xFF94A3B8), size: 25)),
            const SizedBox(width: 13),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(category['name'].toString(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: active ? const Color(0xFF172033) : const Color(0xFF64748B))),
              const SizedBox(height: 5),
              Text('${income ? 'Ingreso' : 'Gasto'} · ${active ? 'Activa' : 'Inactiva'}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ])),
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              enabled: onEdit != null || onToggle != null,
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'toggle') onToggle?.call();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', enabled: onEdit != null,
                    child: const Text('Editar categoría')),
                PopupMenuItem(value: 'toggle', enabled: onToggle != null,
                    child: Text(active ? 'Desactivar' : 'Activar')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}