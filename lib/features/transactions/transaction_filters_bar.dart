import 'package:flutter/material.dart';
import 'transaction_filter.dart';

class TransactionFiltersBar extends StatefulWidget {
  const TransactionFiltersBar({
    super.key, required this.accounts, required this.value, required this.onChanged,
  });
  final List<Map<String, dynamic>> accounts;
  final TransactionFilter value;
  final ValueChanged<TransactionFilter> onChanged;
  @override
  State<TransactionFiltersBar> createState() => _TransactionFiltersBarState();
}

class _TransactionFiltersBarState extends State<TransactionFiltersBar> {
  late final TextEditingController searchController;
  TransactionFilter get filter => widget.value;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: filter.query);
  }

  @override
  void didUpdateWidget(covariant TransactionFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (searchController.text != filter.query) {
      searchController.value = TextEditingValue(
        text: filter.query,
        selection: TextSelection.collapsed(offset: filter.query.length),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  DateTimeRange? get range {
    final start = filter.start;
    final end = filter.end;
    if (start == null || end == null) { return null; }
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    if (first.isAfter(last)) { return null; }
    return DateTimeRange(start: first, end: last);
  }

  Future<void> chooseDates() async {
    final currentRange = range;
    var firstDate = DateTime(2000);
    var lastDate = DateTime(2100, 12, 31);
    if (currentRange != null) {
      if (currentRange.start.isBefore(firstDate)) {
        firstDate = currentRange.start;
      }
      if (currentRange.end.isAfter(lastDate)) {
        lastDate = currentRange.end;
      }
    }
    final selected = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: currentRange,
    );
    if (selected == null || !mounted) { return; }
    widget.onChanged(filter.copyWith(start: selected.start, end: selected.end));
  }

  String day(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String get dateLabel {
    final start = filter.start;
    final end = filter.end;
    if (start != null && end != null) { return '${day(start)} – ${day(end)}'; }
    if (start != null) { return 'Desde ${day(start)}'; }
    if (end != null) { return 'Hasta ${day(end)}'; }
    return 'Todas las fechas';
  }

  @override
  Widget build(BuildContext context) {
    final accountId = filter.accountId;
    final missingAccount = accountId != null &&
        !widget.accounts.any((a) => a['id'].toString() == accountId);
    final reconciliation = filter.reconciled == null
        ? 'all' : filter.reconciled == true ? 'reconciled' : 'pending';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: searchController,
        decoration: InputDecoration(
          labelText: 'Buscar descripción o referencia',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: filter.query.isEmpty ? null : IconButton(
            tooltip: 'Limpiar búsqueda',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => widget.onChanged(filter.copyWith(query: '')),
          ),
        ),
        onChanged: (value) => widget.onChanged(filter.copyWith(query: value)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('type-${filter.type}'),
        initialValue: filter.type, isExpanded: true,
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
          DropdownMenuItem(value: 'adjustment', child: Text('Ajustes')),
        ],
        onChanged: (value) {
          if (value != null) { widget.onChanged(filter.copyWith(type: value)); }
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('account-$accountId'),
        initialValue: accountId ?? 'all', isExpanded: true,
        decoration: const InputDecoration(labelText: 'Cuenta'),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('Todas las cuentas')),
          ...widget.accounts.map((account) => DropdownMenuItem(
            value: account['id'].toString(),
            child: Text(
                '${account['name']} (${account['currency']})'
                    '${account['is_active'] == true ? '' : ' · Inactiva'}',
                overflow: TextOverflow.ellipsis),
          )),
          if (missingAccount) DropdownMenuItem(
              value: accountId, child: const Text('Cuenta no disponible')),
        ],
        onChanged: (value) {
          if (value == null) { return; }
          widget.onChanged(filter.copyWith(
              accountId: value, clearAccount: value == 'all'));
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('reconciliation-$reconciliation'),
        initialValue: reconciliation, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Conciliación'),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
          DropdownMenuItem(value: 'pending', child: Text('Pendientes de conciliar')),
          DropdownMenuItem(value: 'reconciled', child: Text('Conciliados')),
        ],
        onChanged: (value) {
          if (value == null) { return; }
          widget.onChanged(filter.copyWith(
            reconciled: value == 'reconciled',
            clearReconciled: value == 'all',
          ));
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
              onPressed: chooseDates,
              icon: const Icon(Icons.date_range),
              label: Text(dateLabel)),
          if (filter.start != null || filter.end != null)
            IconButton(
                tooltip: 'Quitar fechas',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => widget.onChanged(filter.copyWith(clearDates: true))),
          if (filter.isActive)
            TextButton.icon(
                onPressed: () => widget.onChanged(const TransactionFilter()),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar filtros')),
        ],
      ),
    ]);
  }
}