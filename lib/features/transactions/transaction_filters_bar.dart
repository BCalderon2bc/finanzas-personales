import 'package:flutter/material.dart';
import 'transaction_filter.dart';

class TransactionFiltersBar extends StatefulWidget {
  const TransactionFiltersBar({super.key, required this.accounts, required this.onChanged});
  final List<Map<String, dynamic>> accounts;
  final ValueChanged<TransactionFilter> onChanged;
  @override
  State<TransactionFiltersBar> createState() => _TransactionFiltersBarState();
}
class _TransactionFiltersBarState extends State<TransactionFiltersBar> {
  final searchController = TextEditingController();
  String type = 'all';
  String? accountId;
  DateTimeRange? range;
  String reconciliation = 'all';

  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  TransactionFilter get filter => TransactionFilter(
    type: type, accountId: accountId, query: searchController.text,
    start: range?.start, end: range?.end,
    reconciled: reconciliation == 'all' ? null : reconciliation == 'reconciled',
  );

  void notify() => widget.onChanged(filter);

  void clear() {
    setState(() {
      type = 'all'; accountId = null; range = null;
      reconciliation = 'all'; searchController.clear();
    });
    notify();
  }

  Future<void> chooseDates() async {
    final selected = await showDateRangePicker(context: context,
      firstDate: DateTime(2000), lastDate: DateTime(2100, 12, 31), initialDateRange: range);
    if (selected == null || !mounted) return;
    setState(() => range = selected);
    notify();
  }
  String day(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: searchController,
      decoration: const InputDecoration(labelText: 'Buscar descripción o referencia', prefixIcon: Icon(Icons.search)),
      onChanged: (_) { setState(() {}); notify(); }),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      key: ValueKey('type-$type'), value: type, isExpanded: true,
      decoration: const InputDecoration(labelText: 'Tipo de movimiento'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Todos')),
        DropdownMenuItem(value: 'income', child: Text('Ingresos')),
        DropdownMenuItem(value: 'expense', child: Text('Gastos')),
        DropdownMenuItem(value: 'transfer', child: Text('Transferencias')),
        DropdownMenuItem(value: 'deposit', child: Text('Depósitos')),
        DropdownMenuItem(value: 'withdrawal', child: Text('Retiros')),
        DropdownMenuItem(value: 'card_payment', child: Text('Pagos de tarjeta')),
        DropdownMenuItem(value: 'debt_payment', child: Text('Abonos de deudas')),
      ],
      onChanged: (value) { if (value != null) { setState(() => type = value); notify(); } },
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      key: ValueKey('account-$accountId'), value: accountId ?? 'all', isExpanded: true,
      decoration: const InputDecoration(labelText: 'Cuenta'),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('Todas las cuentas')),
        ...widget.accounts.map((a) => DropdownMenuItem(value: a['id'].toString(),
          child: Text('${a['name']} (${a['currency']})${a['is_active'] == true ? '' : ' · Inactiva'}', overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (value) { setState(() => accountId = value == 'all' ? null : value); notify(); },
    ),
    const SizedBox(height: 8),

    DropdownButtonFormField<String>(
      key: ValueKey('reconciliation-$reconciliation'),
      value: reconciliation, isExpanded: true,
      decoration: const InputDecoration(labelText: 'Conciliación'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
        DropdownMenuItem(value: 'pending', child: Text('Pendientes de conciliar')),
        DropdownMenuItem(value: 'reconciled', child: Text('Conciliados')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => reconciliation = value);
          notify();
        }
      },
    ),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      OutlinedButton.icon(onPressed: chooseDates, icon: const Icon(Icons.date_range),
        label: Text(range == null ? 'Todas las fechas' : '${day(range!.start)} – ${day(range!.end)}')),
      if (range != null) IconButton(tooltip: 'Quitar fechas', icon: const Icon(Icons.close),
        onPressed: () { setState(() => range = null); notify(); }),
      if (filter.isActive) TextButton(onPressed: clear, child: const Text('Limpiar filtros')),
    ]),
  ]);
}
