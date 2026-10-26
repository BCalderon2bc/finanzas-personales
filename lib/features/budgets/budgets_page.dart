import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../utils/money.dart';
import 'budget_form_dialog.dart';
import 'budget_summary.dart';
import '../../data/credit_card_repository.dart';
import 'budget_card.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});
  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}
class _BudgetsPageState extends State<BudgetsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> budgets = [], categories = [];
  Map<String, int> spent = {};
  bool loading = true, saving = false;
  String? error;
  int requestId = 0;

  @override
  void initState() { super.initState(); loadData(); }

  String monthDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-01';
  String money(int cents, String currency) =>
      formatMoneyCents(cents, currency);
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> loadData() async {
    final request = ++requestId;
    final selectedMonth = month;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final categoryRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('categories')
            .select('id, name, is_active, icon, color').eq('user_id', user.id)
            .eq('category_type', 'expense').order('name').order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        categoryRows.addAll(page);
        if (page.length < 500) break;
      }
      final budgetRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('budgets')
            .select('id, category_id, currency, budget_amount, month')
            .eq('user_id', user.id)
            .gte('month', monthDate(selectedMonth))
            .lt('month', monthDate(DateTime(selectedMonth.year, selectedMonth.month + 1)))
            .order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        budgetRows.addAll(page);
        if (page.length < 500) break;
      }
      final transactions = [
        ...await loadUserTransactions(user.id),
        ...await loadUserCardExpenses(user.id),
      ];
      final totals = <String, int>{};
      for (final tx in transactions) {
        if (tx['transaction_type'] != 'expense' || tx['category_id'] == null) continue;
        final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
        if (date == null) throw FormatException('Un gasto tiene una fecha inválida.');
        if (date.year != selectedMonth.year || date.month != selectedMonth.month) continue;
        final key = '${tx['category_id']}|${tx['currency']}';
        totals[key] = (totals[key] ?? 0) + moneyCents(tx['amount']);
      }
      if (!mounted || request != requestId) return;
      setState(() {
        categories = categoryRows; budgets = budgetRows; spent = totals; loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  Future<void> changeMonth(int offset) async {
    if (loading || saving) return;
    setState(() => month = DateTime(month.year, month.month + offset));
    await loadData();
  }

  Future<void> editBudget([Map<String, dynamic>? budget]) async {
    if (loading || saving) return;
    final available = categories.where((c) => c['is_active'] == true ||
        c['id'].toString() == budget?['category_id']?.toString()).toList();
    if (budget != null && !available.any((c) =>
    c['id'].toString() == budget['category_id'].toString())) {
      available.add({'id': budget['category_id'], 'name': 'Categoría no disponible'});
    }
    if (available.isEmpty) {
      message('Primero crea una categoría activa de gasto.');
      return;
    }
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BudgetFormDialog(categories: available, budget: budget),
    );
    if (data == null || !mounted) return;
    if (budget == null && budgets.any((b) =>
    b['category_id'].toString() == data['category_id'] &&
        b['currency'] == data['currency'])) {
      message('Ya existe ese presupuesto este mes. Tócalo para editarlo.');
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      if (budget == null) {
        await supabase.from('budgets').insert({
          ...data, 'user_id': user.id, 'month': monthDate(month),
        });
      } else {
        await supabase.from('budgets').update({'budget_amount': data['budget_amount']})
            .eq('id', budget['id']).eq('user_id', user.id).select('id').single();
      }
      if (!mounted) return;
      message('Presupuesto guardado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        message(e.code == '23505'
          ? 'Ya existe ese presupuesto este mes.' : 'No se pudo guardar: ${e.message}');
      }
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteBudget(Map<String, dynamic> budget) async {
    if (loading || saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: const Text('Se eliminará este límite mensual. Los movimientos registrados se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || loading || saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final deleted = await supabase.from('budgets').delete()
          .eq('id', budget['id']).eq('user_id', user.id).select('id');
      if (!mounted) return;
      message(deleted.isEmpty ? 'No se eliminó: el registro cambió o faltan permisos.'
          : 'Presupuesto eliminado.');
      await loadData();
    } catch (e) {
      if (mounted) message('No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget budgetCard(Map<String, dynamic> budget) {
    final categoryId = budget['category_id'].toString();
    final currency = budget['currency'].toString();
    Map<String, dynamic>? categoryStyle;
    for (final category in categories) {
      if (category['id'].toString() == categoryId) {
        categoryStyle = category;
        break;
      }
    }
    return BudgetCard(
      name: categoryStyle?['name']?.toString() ?? 'Categoría no disponible',
      currency: currency,
      categoryStyle: categoryStyle,
      limitCents: moneyCents(budget['budget_amount']),
      usedCents: spent['$categoryId|$currency'] ?? 0,
      onEdit: saving ? null : () => editBudget(budget),
      onDelete: saving ? null : () => deleteBudget(budget),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Presupuestos'), actions: [
      IconButton(tooltip: 'Actualizar', onPressed: loading || saving ? null : loadData,
          icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading || saving || error != null ? null : () => editBudget(),
      icon: const Icon(Icons.add),
      label: Text(saving ? 'Guardando...' : 'Nuevo presupuesto'),
    ),
    body: Column(children: [
      Row(children: [
        IconButton(onPressed: loading || saving ? null : () => changeMonth(-1),
            tooltip: 'Mes anterior', icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(
            '${month.month.toString().padLeft(2, '0')}/${month.year}',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
        IconButton(onPressed: loading || saving ? null : () => changeMonth(1),
            tooltip: 'Mes siguiente', icon: const Icon(Icons.chevron_right)),
      ]),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator())
          : error != null ? Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        const Text('No se pudieron cargar los presupuestos.'),
        SelectableText(error!),
        TextButton(onPressed: loadData, child: const Text('Reintentar')),
      ],
      )))
          : RefreshIndicator(onRefresh: loadData, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        const Padding(padding: EdgeInsets.only(bottom: 12),
            child: Text('El gasto neto incluye cuentas y tarjetas de la misma categoría, moneda y mes, descontando devoluciones.')),
        if (budgets.isEmpty) const Padding(padding: EdgeInsets.all(24),
            child: Text('No hay presupuestos para este mes.', textAlign: TextAlign.center)),
        BudgetSummary(budgets: budgets, spent: spent),
        ...budgets.map(budgetCard),
      ],
      ))),
    ]),
  );
}