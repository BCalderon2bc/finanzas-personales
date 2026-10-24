import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../data/credit_card_repository.dart';
import '../../utils/money.dart';
import 'category_expenses_dialog.dart';
import 'package:flutter/services.dart';
import '../../data/debt_payment_repository.dart';

class MonthlyExpensesPage extends StatefulWidget {
  const MonthlyExpensesPage({super.key});
  @override
  State<MonthlyExpensesPage> createState() => _MonthlyExpensesPageState();
}
class _MonthlyExpensesPageState extends State<MonthlyExpensesPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String currency = 'NIO';
  List<Map<String, dynamic>> expenses = [];
  Map<String, String> categoryNames = {};
  bool loading = true;
  String? error;
  int requestId = 0;

  @override
  void initState() { super.initState(); loadData(); }

  String money(int cents) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  Future<void> copyReport(List<MapEntry<String, int>> groups, int total, int count) async {
    final text = StringBuffer()
      ..writeln('Gastos por categoría')
      ..writeln('Mes: ${month.month.toString().padLeft(2, '0')}/${month.year}')
      ..writeln('Moneda: $currency')
      ..writeln();
    for (final group in groups) {
      final name = group.key == 'uncategorized'
          ? 'Sin categoría' : categoryNames[group.key] ?? 'Categoría no disponible';
      text.writeln('$name: ${money(group.value)}');
    }
    text
      ..writeln()
      ..writeln('Gasto neto: ${money(total)}')
      ..writeln('Movimientos: $count')
      ..writeln('Incluye cuentas, tarjetas e intereses y comisiones de deudas. Descuenta devoluciones. Excluye pagos de tarjeta y capital abonado.');
    try {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte copiado.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo copiar: $e')),
      );
    }
  }

  Future<void> loadData() async {
    final request = ++requestId;
    final selectedMonth = month;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final names = <String, String>{};
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('categories').select('id, name')
            .eq('user_id', user.id).order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        for (final category in page) {
          names[category['id'].toString()] = category['name'].toString();
        }
        if (page.length < 500) break;
      }
      final rows = [
        ...await loadUserTransactions(user.id),
        ...await loadUserCardExpenses(user.id),
        ...debtPaymentExpenses(await loadUserDebtPayments(user.id)),
      ];
      final selected = <Map<String, dynamic>>[];
      for (final tx in rows) {
        if (tx['transaction_type'] != 'expense') continue;
        final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
        if (date == null) throw FormatException('Un gasto tiene una fecha inválida.');
        if (date.year == selectedMonth.year && date.month == selectedMonth.month) {
          selected.add(tx);
        }
      }
      if (!mounted || request != requestId) return;
      setState(() {
        categoryNames = names; expenses = selected; loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  Future<void> changeMonth(int offset) async {
    if (loading) return;
    setState(() => month = DateTime(month.year, month.month + offset));
    await loadData();
  }

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{}, counts = <String, int>{};
    int total = 0, count = 0;
    for (final tx in expenses) {
      if (tx['currency'] != currency) continue;
      final key = tx['category_id']?.toString() ?? 'uncategorized';
      final amount = moneyCents(tx['amount']);
      totals[key] = (totals[key] ?? 0) + amount;
      counts[key] = (counts[key] ?? 0) + 1;
      total += amount;
      count++;
    }
    final groups = totals.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos por categoría'), actions: [
        IconButton(tooltip: 'Actualizar', onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh)),
        IconButton(
          tooltip: 'Copiar reporte',
          onPressed: loading || error != null || groups.isEmpty
              ? null : () => copyReport(groups, total, count),
          icon: const Icon(Icons.copy_outlined),
        ),
      ]),
      body: Column(children: [
        Row(children: [
          IconButton(tooltip: 'Mes anterior', onPressed: loading ? null : () => changeMonth(-1),
              icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(
              '${month.month.toString().padLeft(2, '0')}/${month.year}',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(tooltip: 'Mes siguiente', onPressed: loading ? null : () => changeMonth(1),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator())
            : error != null ? Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('No se pudo cargar el reporte.'),
            SelectableText(error!),
            TextButton(onPressed: loadData, child: const Text('Reintentar')),
          ]),
        ))
            : RefreshIndicator(onRefresh: loadData, child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            value: currency, decoration: const InputDecoration(labelText: 'Moneda'),
            items: const [
              DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
              DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => currency = value);
            },
          ),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Gasto neto del mes'),
            Text(money(total), style: Theme.of(context).textTheme.headlineSmall),
            Text('$count movimientos'),
          ],
          ))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Incluye gastos de cuentas y tarjetas, más intereses y comisiones de deudas. Descuenta devoluciones. Excluye pagos de tarjeta y capital abonado a deudas.')),
          if (groups.isEmpty) const Padding(padding: EdgeInsets.all(24),
              child: Text('No hay gastos en esta moneda y mes.', textAlign: TextAlign.center)),
          ...groups.map((group) {
            final name = group.key == 'uncategorized' ? 'Sin categoría'
                : categoryNames[group.key] ?? 'Categoría no disponible';
            return Card(child: ListTile(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => CategoryExpensesDialog(
                  name: name,
                  currency: currency,
                  expenses: expenses.where((tx) =>
                  tx['currency'] == currency &&
                      (tx['category_id']?.toString() ?? 'uncategorized') == group.key
                  ).toList(),
                ),
              ),
              leading: const Icon(Icons.category_outlined),
              title: Text(name),
              subtitle: Text('${counts[group.key]} movimientos'),
              trailing: Text(money(group.value),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ));
          }),
        ],
        ))),
      ]),
    );
  }
}