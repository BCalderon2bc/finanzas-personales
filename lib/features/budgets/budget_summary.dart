import 'package:flutter/material.dart';
import '../../utils/money.dart';

class BudgetSummary extends StatelessWidget {
  const BudgetSummary({super.key, required this.budgets, required this.spent});
  final List<Map<String, dynamic>> budgets;
  final Map<String, int> spent;

  String money(int cents, String currency) =>
      formatMoneyCents(cents, currency);

  Widget currencyCard(String currency) {
    final selected = budgets.where((b) => b['currency'] == currency).toList();
    final categories = <String>{};
    int limit = 0, used = 0, exceeded = 0;
    for (final budget in selected) {
      final amount = moneyCents(budget['budget_amount']);
      final key = '${budget['category_id']}|$currency';
      final expense = spent[key] ?? 0;
      limit += amount;
      if (categories.add(key)) used += expense;
      if (expense > amount) exceeded++;
    }
    final remaining = limit - used;
    final colors = remaining < 0
        ? const [Color(0xFF881337), Color(0xFFBE123C)]
        : currency == 'USD'
        ? const [Color(0xFF064E3B), Color(0xFF0D8262)]
        : const [Color(0xFF172554), Color(0xFF2563EB)];

    Widget detail(String label, int amount) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: Colors.white.withAlpha(200), fontSize: 12)),
        const SizedBox(height: 6),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(money(amount, currency), style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
      ]),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.savings_outlined, color: Colors.white, size: 23),
          const SizedBox(width: 10),
          Expanded(child: Text(currency == 'USD' ? 'Dólares' : 'Córdobas',
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w600))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(9)),
              child: Text(currency, style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 22),
        Text(remaining < 0 ? 'EXCESO NETO' : 'DISPONIBLE NETO',
            style: TextStyle(color: Colors.white.withAlpha(200),
                fontSize: 11, letterSpacing: 1.3)),
        const SizedBox(height: 7),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(money(remaining.abs(), currency), style: const TextStyle(
                color: Colors.white, fontSize: 32,
                fontWeight: FontWeight.w800, letterSpacing: -0.8))),
        const SizedBox(height: 22),
        Row(children: [
          detail('Presupuestado', limit),
          const SizedBox(width: 16),
          detail('Gasto neto', used),
        ]),
        const SizedBox(height: 18),
        Divider(color: Colors.white.withAlpha(40), height: 1),
        const SizedBox(height: 14),
        Text(selected.isEmpty ? 'Sin presupuestos en esta moneda'
            : '${selected.length} presupuestos · $exceeded excedidos',
            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final nio = currencyCard('NIO');
        final usd = currencyCard('USD');
        if (box.maxWidth < 700) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            nio, const SizedBox(height: 14), usd,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: nio),
          const SizedBox(width: 14),
          Expanded(child: usd),
        ]);
      }),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
            'Solo incluye categorías presupuestadas del mes. '
                'El disponible neto puede coexistir con categorías excedidas.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
      ),
    ]);
  }
}