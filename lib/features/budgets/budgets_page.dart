import '../../widgets/page_intro.dart';
import '../../widgets/date_period_field.dart';
import '../../data/period_logic.dart';
import '../../widgets/adaptive_layout.dart';
import '../help/app_help.dart';
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
  DateTime get periodStart => month;
  DateTime? customEnd;
  DateTime get periodEnd =>
      customEnd ?? DateTime(month.year, month.month + 1, 0);
  List<Map<String, dynamic>> budgets = [], categories = [];
  Map<String, int> spent = {};
  bool loading = true, saving = false;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String monthDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-01';
  String money(int cents, String currency) => formatMoneyCents(cents, currency);
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> loadData() async {
    final request = ++requestId;
    final from = periodStart, until = periodEnd;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final categoryRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('categories')
            .select('id, name, is_active, icon, color')
            .eq('user_id', user.id)
            .eq('category_type', 'expense')
            .order('name')
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        categoryRows.addAll(page);
        if (page.length < 500) break;
      }
      final budgetRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('budgets')
            .select(
              'id, category_id, currency, budget_amount, month, start_date, end_date',
            )
            .eq('user_id', user.id)
            .lte('start_date', isoDay(until))
            .gte('end_date', isoDay(from))
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        budgetRows.addAll(page);
        if (page.length < 500) break;
      }
      final transactions = [
        ...await loadUserTransactions(user.id),
        ...await loadUserCardExpenses(user.id),
      ];
      final totals = {
        for (final budget in budgetRows)
          '${budget['id']}': budgetSpent(budget, transactions),
      };
      if (!mounted || request != requestId) return;
      setState(() {
        categories = categoryRows;
        budgets = budgetRows;
        spent = totals;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> changeMonth(int offset) async {
    if (loading || saving) return;
    setState(() {
      month = DateTime(month.year, month.month + offset);
      customEnd = null;
    });
    await loadData();
  }

  Future<void> editBudget([Map<String, dynamic>? budget]) async {
    if (loading || saving) return;
    final available = categories
        .where(
          (c) =>
              c['is_active'] == true ||
              c['id'].toString() == budget?['category_id']?.toString(),
        )
        .toList();
    if (budget != null &&
        !available.any(
          (c) => c['id'].toString() == budget['category_id'].toString(),
        )) {
      available.add({
        'id': budget['category_id'],
        'name': 'Categoría no disponible',
      });
    }
    if (available.isEmpty) {
      message('Primero crea una categoría activa de gasto.');
      return;
    }
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BudgetFormDialog(
        categories: available,
        budget: budget,
        initialStart: periodStart,
        initialEnd: periodEnd,
      ),
    );
    if (data == null || !mounted) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      if (budget == null) {
        await supabase.from('budgets').insert({...data, 'user_id': user.id});
      } else {
        await supabase
            .from('budgets')
            .update({
              'budget_amount': data['budget_amount'],
              'start_date': data['start_date'],
              'end_date': data['end_date'],
              'month': data['month'],
            })
            .eq('id', budget['id'])
            .eq('user_id', user.id)
            .select('id')
            .single();
      }
      if (!mounted) return;
      message('Presupuesto guardado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        message(
          e.code == '23505'
              ? 'Ya existe un presupuesto con estas fechas o superpuesto.'
              : 'No se pudo guardar: ${e.message}',
        );
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
        content: const Text(
          'Se eliminará este límite del período. Los movimientos registrados se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || loading || saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final deleted = await supabase
          .from('budgets')
          .delete()
          .eq('id', budget['id'])
          .eq('user_id', user.id)
          .select('id');
      if (!mounted) return;
      message(
        deleted.isEmpty
            ? 'No se eliminó: el registro cambió o faltan permisos.'
            : 'Presupuesto eliminado.',
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Desde ${isoDay(budgetStart(budget))} hasta ${isoDay(budgetEnd(budget))}',
          style: const TextStyle(fontSize: 12),
        ),
        BudgetCard(
          name: categoryStyle?['name']?.toString() ?? 'Categoría no disponible',
          currency: currency,
          categoryStyle: categoryStyle,
          limitCents: moneyCents(budget['budget_amount']),
          usedCents: spent['${budget['id']}'] ?? 0,
          onEdit: saving ? null : () => editBudget(budget),
          onDelete: saving ? null : () => deleteBudget(budget),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => GuideScope(
    topic: 'budgets',
    ready: !loading && error == null,
    child: Scaffold(
      appBar: AppBar(
        title: GuideAnchor(id: 'title', child: const Text('Presupuestos')),
        actions: [
          const AppHelpButton(topic: 'budgets'),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: compactLayout(context)
          ? GuideAnchor(
              id: 'add',
              child: CompactActionBar(
                label: saving ? 'Guardando...' : 'Nuevo presupuesto',
                onPressed: loading || saving || error != null
                    ? null
                    : () => editBudget(),
              ),
            )
          : null,
      floatingActionButton: compactLayout(context)
          ? null
          : GuideAnchor(
              id: 'add',
              child: FloatingActionButton.extended(
                onPressed: loading || saving || error != null
                    ? null
                    : () => editBudget(),
                icon: const Icon(Icons.add),
                label: Text(saving ? 'Guardando...' : 'Nuevo presupuesto'),
              ),
            ),
      body: PageFrame(
        maxWidth: 1150,
        child: Column(
          children: [
            GuideAnchor(
              id: 'month',
              child: DatePeriodField(
                start: periodStart,
                end: periodEnd,
                enabled: !loading && !saving,
                onChanged: (range) {
                  setState(() {
                    month = range.start;
                    customEnd = range.end;
                  });
                  loadData();
                },
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No se pudieron cargar los presupuestos.',
                            ),
                            SelectableText(error!),
                            TextButton(
                              onPressed: loadData,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          compactLayout(context) ? 24 : 100,
                        ),
                        children: [
                          const PageIntro(
                            icon: Icons.savings_outlined,
                            title: 'Controla tus límites',
                            description:
                                'Compara el gasto del período con el monto de cada presupuesto.',
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'El gasto neto incluye cuentas y tarjetas de la misma categoría y moneda dentro de las fechas de cada presupuesto, descontando devoluciones.',
                            ),
                          ),
                          if (budgets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No hay presupuestos que coincidan con estas fechas.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          BudgetSummary(budgets: budgets, spent: spent),
                          ...budgets.map(budgetCard),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
