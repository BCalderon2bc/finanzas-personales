import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../accounts/accounts_page.dart';
import '../transactions/transactions_page.dart';
import '../categories/categories_page.dart';
import '../budgets/budgets_page.dart';
import '../debts/debts_page.dart';
import '../debts/debt_payments_page.dart';
import '../credit_cards/credit_cards_page.dart';
import '../credit_cards/credit_card_movements_page.dart';
import '../reports/monthly_expenses_page.dart';
import 'dashboard_overview.dart';
import 'dashboard_components.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardOverview? data;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String currency = 'NIO';
  String? error;
  bool loading = true;
  int requestId = 0;

  @override
  void initState() { super.initState(); loadData(); }

  Future<void> loadData() async {
    final request = ++requestId;
    final selectedMonth = month;
    setState(() { loading = true; error = null; });
    try {
      final result = await loadDashboardOverview(selectedMonth);
      if (!mounted || request != requestId) return;
      setState(() { data = result; loading = false; });
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

  Future<void> pushPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await loadData();
  }

  Future<void> openTarget(DashboardTarget target) {
    final Widget page = switch (target) {
      DashboardTarget.accounts => const AccountsPage(),
      DashboardTarget.transactions => const TransactionsPage(),
      DashboardTarget.categories => const CategoriesPage(),
      DashboardTarget.budgets => const BudgetsPage(),
      DashboardTarget.debts => const DebtsPage(),
      DashboardTarget.cards => const CreditCardsPage(),
      DashboardTarget.reports => const MonthlyExpensesPage(),
    };
    return pushPage(page);
  }

  Future<void> openEvent(DashboardEvent event) {
    if (event.entityId != null && event.target == DashboardTarget.cards) {
      return pushPage(CreditCardMovementsPage(cardId: event.entityId!));
    }
    if (event.entityId != null && event.target == DashboardTarget.debts) {
      return pushPage(DebtPaymentsPage(debtId: event.entityId!));
    }
    return openTarget(event.target);
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Finanzas'), actions: [
        IconButton(tooltip: 'Actualizar', onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Cerrar sesión', onPressed: logout,
            icon: const Icon(Icons.logout_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Tu panorama financiero',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('Revisa tus saldos, el movimiento del mes y tus compromisos.',
                  style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Mes anterior',
                          onPressed: loading ? null : () => changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded)),
                      SizedBox(width: 148, child: Text(dashboardMonth(month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      IconButton(tooltip: 'Mes siguiente',
                          onPressed: loading ? null : () => changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded)),
                    ]),
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'NIO', label: Text('Córdobas')),
                      ButtonSegment(value: 'USD', label: Text('Dólares')),
                    ],
                    selected: {currency},
                    onSelectionChanged: (value) => setState(() => currency = value.first),
                  ),
                  TextButton.icon(
                    onPressed: loading ? null : () async {
                      final now = DateTime.now();
                      setState(() => month = DateTime(now.year, now.month));
                      await loadData();
                    },
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Mes actual'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Ingresos, gastos y presupuestos corresponden al mes seleccionado. Los saldos y deudas muestran los registros vigentes.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 16),
              if (loading)
                const Padding(padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (error != null)
                Card(child: Padding(padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const Icon(Icons.error_outline, size: 36),
                    const SizedBox(height: 8),
                    const Text('No pudimos cargar el panel.'),
                    TextButton(onPressed: loadData, child: const Text('Reintentar')),
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context, builder: (_) => AlertDialog(
                        title: const Text('Detalle del error'),
                        content: SingleChildScrollView(child: SelectableText(error!)),
                        actions: [TextButton(onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'))],
                      ),
                      ),
                      child: const Text('Ver detalle del error'),
                    ),
                  ]),
                ))
              else if (current != null)
                  DashboardMetrics(data: current, currency: currency),
              const SizedBox(height: 22),
              Text('Accesos rápidos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              DashboardQuickActions(onOpen: openTarget),
              if (!loading && error == null && current != null) ...[
                const SizedBox(height: 24),
                DashboardPanels(data: current, currency: currency,
                    onOpen: openTarget, onEvent: openEvent),
                const SizedBox(height: 14),
                Text('Actualizado a las ${current.loadedAt.hour.toString().padLeft(2, '0')}:'
                    '${current.loadedAt.minute.toString().padLeft(2, '0')} · '
                    '${current.currencies[currency]!.movements} movimientos en el mes',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ]),
          )),
        ),
      ),
    );
  }
}