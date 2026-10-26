import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../widgets/category_style.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key, required this.name, required this.currency,
    required this.limitCents, required this.usedCents,
    this.onEdit, this.onDelete,this.categoryStyle,
  });
  final String name, currency;
  final int limitCents, usedCents;
  final VoidCallback? onEdit, onDelete;
  final Map<String, dynamic>? categoryStyle;

  String money(int cents) =>
      formatMoneyCents(cents, currency);

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF64748B);
    const border = Color(0xFFE2E8F0);
    final remaining = limitCents - usedCents;
    final exceeded = remaining < 0;
    final ratio = limitCents > 0 ? usedCents / limitCents : 0.0;
    final nearLimit = !exceeded && limitCents > 0 && ratio >= 0.8;
    final color = exceeded ? const Color(0xFFB42318)
        : nearLimit ? const Color(0xFFB45309) : const Color(0xFF087F5B);

    final categoryAccent = categoryStyle == null
        ? color : categoryColor(categoryStyle?['color']);
    final categorySymbol = categoryStyle == null
        ? Icons.donut_large_rounded : categoryIcon(categoryStyle?['icon']);

    final status = exceeded ? 'Excedido'
        : usedCents < 0 ? 'Devoluciones netas'
        : limitCents == 0 ? 'Sin importe asignado'
        : nearLimit ? 'Cerca del límite' : 'Dentro del límite';
    final progress = limitCents > 0 ? ratio.clamp(0.0, 1.0).toDouble()
        : usedCents > 0 ? 1.0 : 0.0;

    Widget detail(String label, int amount) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 6),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(money(amount), style: const TextStyle(
                color: Color(0xFF172033), fontSize: 17, fontWeight: FontWeight.w700))),
      ]),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: exceeded ? color.withAlpha(90) : border),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6),
              blurRadius: 16, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: categoryAccent.withAlpha(15),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(categorySymbol, color: categoryAccent, size: 24),),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF172033))),
            const SizedBox(height: 4),
            Text('Presupuesto mensual · $currency',
                style: const TextStyle(color: muted, fontSize: 12)),
          ])),
          IconButton(
              tooltip: 'Editar presupuesto', onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: muted, size: 20)),
        ]),
        const SizedBox(height: 20),
        Text(exceeded ? 'EXCESO' : 'DISPONIBLE NETO',
            style: const TextStyle(color: muted, fontSize: 11,
                letterSpacing: 1.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(money(remaining.abs()), style: TextStyle(
                color: color, fontSize: 30,
                fontWeight: FontWeight.w800, letterSpacing: -0.8))),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(15)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              detail('Asignado', limitCents),
              const SizedBox(width: 16),
              detail('Gasto neto', usedCents),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: progress, minHeight: 9,
                    color: color, backgroundColor: border)),
            const SizedBox(height: 9),
            Text(limitCents > 0
                ? '${(ratio * 100).toStringAsFixed(0)}% de gasto neto sobre el límite'
                : 'Sin porcentaje: el límite asignado es cero',
                style: const TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12, runSpacing: 8,
          children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(9)),
                child: Text(status, style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600))),
            TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: muted),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar')),
          ],
        ),
      ]),
    );
  }
}