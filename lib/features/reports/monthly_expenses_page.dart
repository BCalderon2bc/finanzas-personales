import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../data/credit_card_repository.dart';
import '../../data/debt_payment_repository.dart';
import '../../utils/money.dart';
import '../../widgets/category_style.dart';
import 'category_expenses_dialog.dart';
import 'expense_report_widgets.dart';

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
  Map<String, Map<String, dynamic>> categoryStyles = {};
  bool loading = true;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String money(int cents) =>
      formatMoneyCents(cents, currency);

  String categoryName(String key) => key == 'uncategorized'
      ? 'Sin categoría' : categoryNames[key] ?? 'Categoría no disponible';

  Future<void> copyReport(List<MapEntry<String, int>> groups, int total, int count) async {
    final text = StringBuffer()
      ..writeln('Gastos por categoría')
      ..writeln('Mes: ${month.month.toString().padLeft(2, '0')}/${month.year}')
      ..writeln('Moneda: $currency')
      ..writeln();
    for (final group in groups) {
      text.writeln('${categoryName(group.key)}: ${money(group.value)}');
    }
    text
      ..writeln()
      ..writeln('Gasto neto: ${money(total)}')
      ..writeln('Movimientos: $count')
      ..writeln(
          'Incluye cuentas, tarjetas e intereses y comisiones de deudas. '
              'Descuenta devoluciones. Excluye pagos de tarjeta y capital abonado.');
    try {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte copiado.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo copiar: $e')));
      }
    }
  }

  Future<void> loadData() async {
    if (!mounted) { return; }
    final request = ++requestId;
    final selectedMonth = month;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) { throw Exception('Debes iniciar sesión nuevamente.'); }
      final names = <String, String>{};
      final styles = <String, Map<String, dynamic>>{};
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('categories')
            .select('id, name, icon, color')
            .eq('user_id', user.id).order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        for (final category in page) {
          final id = category['id'].toString();
          names[id] = category['name'].toString();
          styles[id] = category;
        }
        if (page.length < 500) { break; }
      }
      final rows = [
        ...await loadUserTransactions(user.id),
        ...await loadUserCardExpenses(user.id),
        ...debtPaymentExpenses(await loadUserDebtPayments(user.id)),
      ];
      final selected = <Map<String, dynamic>>[];
      for (final tx in rows) {
        if (tx['transaction_type'] != 'expense') { continue; }
        final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
        if (date == null) { throw const FormatException('Un gasto tiene una fecha inválida.'); }
        if (date.year == selectedMonth.year && date.month == selectedMonth.month) {
          selected.add(tx);
        }
      }
      if (!mounted || request != requestId) { return; }
      setState(() {
        categoryNames = names;
        categoryStyles = styles;
        expenses = selected;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  Future<void> changeMonth(int offset) async {
    if (loading) { return; }
    setState(() => month = DateTime(month.year, month.month + offset));
    await loadData();
  }

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{}, counts = <String, int>{};
    int total = 0, count = 0, charges = 0, refunds = 0;
    for (final tx in expenses) {
      if (tx['currency'] != currency) { continue; }
      final key = tx['category_id']?.toString() ?? 'uncategorized';
      final amount = moneyCents(tx['amount']);
      if (amount < 0) {
        refunds += -amount;
      } else {
        charges += amount;
      }
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
    final positiveTotal = groups.fold<int>(
        0, (sum, group) => sum + (group.value > 0 ? group.value : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos por categoría'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'Copiar reporte',
            onPressed: loading || error != null || groups.isEmpty
                ? null : () => copyReport(groups, total, count),
            icon: const Icon(Icons.copy_outlined)),
      ]),
      body: Column(children: [
        Row(children: [
          IconButton(
              tooltip: 'Mes anterior',
              onPressed: loading ? null : () => changeMonth(-1),
              icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(
              '${month.month.toString().padLeft(2, '0')}/${month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: 'Mes siguiente',
              onPressed: loading ? null : () => changeMonth(1),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Expanded(
          child: loading ? const Center(child: CircularProgressIndicator())
              : error != null ? Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              const Text('No se pudo cargar el reporte.'),
              const SizedBox(height: 8),
              SelectableText(error!),
              TextButton(onPressed: loadData, child: const Text('Reintentar')),
            ]),
          ))
              : RefreshIndicator(
            onRefresh: loadData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Moneda'),
                  items: const [
                    DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
                    DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
                  ],
                  onChanged: (value) {
                    if (value != null) { setState(() => currency = value); }
                  },
                ),
                const SizedBox(height: 16),
                ExpenseReportSummary(
                  currency: currency,
                  chargesCents: charges,
                  refundsCents: refunds,
                  count: count,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                      'Incluye gastos de cuentas y tarjetas, más intereses y comisiones '
                          'de deudas. Descuenta devoluciones. Excluye pagos de tarjeta '
                          'y capital abonado a deudas.',
                      style: TextStyle(
                          color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
                ),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.pie_chart_outline_rounded,
                          size: 44, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No hay gastos en esta moneda y mes.',
                          textAlign: TextAlign.center),
                    ]),
                  ),
                if (groups.isNotEmpty) ...[
                  const Text('Distribución por categoría',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                      'Porcentajes entre categorías con gasto neto positivo. '
                          'Las devoluciones netas se muestran por separado.',
                      style: TextStyle(
                          color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
                  const SizedBox(height: 16),
                ],
                ...groups.map((group) {
                  final name = categoryName(group.key);
                  final style = categoryStyles[group.key];
                  return ExpenseCategoryCard(
                    name: name,
                    currency: currency,
                    amountCents: group.value,
                    count: counts[group.key] ?? 0,
                    positiveTotalCents: positiveTotal,
                    color: group.key == 'uncategorized'
                        ? const Color(0xFF64748B)
                        : categoryColor(style?['color']),
                    icon: group.key == 'uncategorized'
                        ? Icons.help_outline_rounded
                        : categoryIcon(style?['icon']),
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
                  );
                }),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}