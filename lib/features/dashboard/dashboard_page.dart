import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../widgets/dashboard_tile.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../transactions/transactions_page.dart';
import 'dashboard_summary.dart';
import 'dashboard_summary_widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  DashboardSummary? summary;
  bool loading = true;
  String? error;
  int requestId = 0;
  @override
  void initState() { super.initState(); loadSummary(); }
  Future<void> loadSummary() async {
    final request = ++requestId;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final accounts = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final rows = await supabase.from('accounts').select('id, name, currency, opening_balance, is_active')
            .eq('user_id', user.id).order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(rows);
        accounts.addAll(page);
        if (page.length < 500) break;
      }
      final transactions = await loadUserTransactions(user.id);
      final result = DashboardSummary.calculate(accounts, transactions, DateTime.now());
      if (mounted && request == requestId) setState(() { summary = result; loading = false; });
    } catch (e) {
      if (mounted && request == requestId) setState(() { error = e.toString(); loading = false; });
    }
  }
  Future<void> openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await loadSummary();
  }
  Future<void> logout() async {
    try { await supabase.auth.signOut(); } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis Finanzas'), actions: [
      IconButton(tooltip: 'Actualizar', onPressed: loading ? null : loadSummary, icon: const Icon(Icons.refresh)),
      IconButton(tooltip: 'Cerrar sesión', onPressed: logout, icon: const Icon(Icons.logout)),
    ]),
    body: RefreshIndicator(onRefresh: loadSummary, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mi panel financiero', style: Theme.of(context).textTheme.headlineMedium),
          Text('Sesión: ${supabase.auth.currentUser?.email ?? 'Usuario'}'),
          const SizedBox(height: 16),
          if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            const Text('No se pudo cargar el resumen.'), const SizedBox(height: 8), SelectableText(error!),
            TextButton(onPressed: loadSummary, child: const Text('Reintentar')),
          ])))
          else if (summary != null) ..._summaryWidgets(summary!),
          const SizedBox(height: 16),
          DashboardTile(icon: Icons.account_balance_wallet_outlined, title: 'Cuentas y efectivo',
            subtitle: 'Bancos, efectivo, ahorros y saldos', onTap: () => openPage(const AccountsPage())),
          DashboardTile(icon: Icons.receipt_long, title: 'Ingresos, gastos y transferencias',
            subtitle: 'Registrar y consultar movimientos', onTap: () => openPage(const TransactionsPage())),
          DashboardTile(icon: Icons.category_outlined, title: 'Categorías',
            subtitle: 'Organiza tus ingresos y gastos', onTap: () => openPage(const CategoriesPage())),
          const DashboardTile(icon: Icons.credit_card, title: 'Deudas y tarjetas',
            subtitle: 'Préstamos, tarjetas de crédito y cuotas', enabled: false),
          const DashboardTile(icon: Icons.account_balance, title: 'Presupuestos',
            subtitle: 'Control mensual de gastos', enabled: false),
        ],
      ))),
    )),
  );
  List<Widget> _summaryWidgets(DashboardSummary data) => [
    Text('Resumen de ${data.month.month.toString().padLeft(2, '0')}/${data.month.year}',
      style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    LayoutBuilder(builder: (context, constraints) {
      final cards = data.currencies.entries.map((e) => CurrencySummaryCard(currency: e.key, summary: e.value)).toList();
      return constraints.maxWidth < 600 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards)
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards.map((card) => Expanded(child: card)).toList());
    }),
    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(
      'Ingresos y gastos incluyen las cuentas activas e inactivas. Las transferencias, depósitos y retiros no se cuentan como ingresos o gastos.',
    )),
    const SizedBox(height: 8),
    Text('Últimos movimientos', style: Theme.of(context).textTheme.titleMedium),
    if (data.recent.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aún no tienes movimientos registrados.')),
    ...data.recent.map((tx) => RecentTransactionCard(transaction: tx, accountNames: data.accountNames,
      onTap: () => openPage(const TransactionsPage()))),
  ];
}
