import '../person_accounts/person_accounts_page.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/financial_settings_repository.dart';
import '../settings/settings_page.dart';
import 'dashboard_header.dart';
import 'dashboard_conversion.dart';
import '../auth/change_password_page.dart';
import '../accounts/accounts_page.dart';
import '../transactions/transactions_page.dart';
import '../categories/categories_page.dart';
import '../budgets/budgets_page.dart';
import '../debts/debts_page.dart';
import '../debts/debt_payments_page.dart';
import '../credit_cards/credit_cards_page.dart';
import '../credit_cards/credit_card_movements_page.dart';
import '../reports/monthly_expenses_page.dart';
import '../receivable_loans/receivable_loans_page.dart';
import '../receivable_loans/receivable_loans_dashboard.dart';
import 'dashboard_overview.dart';
import 'dashboard_components.dart';
import 'dashboard_monthly_balance.dart';
import 'dashboard_navigation.dart';
import 'dashboard_financial_health.dart';
import 'upcoming_payments_panel.dart';
import '../reports/export_reports_page.dart';
import '../debts/debt_installments_page.dart';
import '../credit_cards/credit_card_statements_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardOverview? data;
  DashboardPeriod period = DashboardPeriod.forMonth(DateTime.now());
  String currency = 'NIO';
  FinancialSettings? financialSettings;
  String? settingsError;
  String? error;
  bool loading = true;
  int requestId = 0;

  final scrollController = ScrollController();
  bool showBackToTop = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateScrollButton);
    loadData();
  }

  @override
  void dispose() {
    scrollController.removeListener(updateScrollButton);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!mounted) {
      return;
    }

    final request = ++requestId;
    final selectedPeriod = period;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      final results = await Future.wait<Object?>([
        loadDashboardOverview(selectedPeriod.start, until: selectedPeriod.end),
        readSettings(),
      ]);
      final result = results[0] as DashboardOverview;
      final settingsResult = results[1] as (FinancialSettings?, String?);
      if (supabase.auth.currentUser?.id != userId) {
        throw StateError('La sesión cambió. Actualiza el inicio.');
      }

      if (!mounted || request != requestId) {
        return;
      }

      setState(() {
        data = result;
        financialSettings = settingsResult.$1;
        settingsError = settingsResult.$2;
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

  Future<(FinancialSettings?, String?)> readSettings() async {
    try {
      return (await loadFinancialSettings(), null);
    } catch (e) {
      return (null, '$e');
    }
  }

  Future<void> openSettings() => pushPage(const SettingsPage());

  Future<void> chooseDate(bool from) async {
    if (loading) return;
    final selected = await showDatePicker(
      context: context,
      helpText: from ? 'Desde' : 'Hasta',
      initialDate: from ? period.start : period.end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      period = from
          ? DashboardPeriod(
              selected,
              selected.isAfter(period.end) ? selected : period.end,
            )
          : DashboardPeriod(
              selected.isBefore(period.start) ? selected : period.start,
              selected,
            );
    });
    await loadData();
  }

  Future<void> pushPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );

    if (mounted) {
      await loadData();
    }
  }

  Future<void> openReceivableLoans() => pushPage(const ReceivableLoansPage());

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
      }
    }
  }

  void updateScrollButton() {
    if (!mounted || !scrollController.hasClients) {
      return;
    }

    final visible = scrollController.offset > 500;

    if (visible != showBackToTop) {
      setState(() => showBackToTop = visible);
    }
  }

  void backToTop() {
    if (!scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    final rate = financialSettings?.rate;
    final presented = current == null || rate == null
        ? current
        : convertDashboard(current, currency, rate);

    return Scaffold(
      drawer: DashboardNavigation(
        onOpen: openTarget,
        onSettings: openSettings,
        onExport: () => pushPage(const ExportReportsPage()),
        onPersonAccounts: () => pushPage(const PersonAccountsPage()),
        onChangePassword: () {
          pushPage(const ChangePasswordPage());
        },
        onOpenReceivables: () {
          openReceivableLoans();
        },
      ),
      appBar: AppBar(
        title: const Text('Mi Billete'),
        actions: [
          IconButton(
            tooltip: 'Configuraciones',
            onPressed: openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          if (MediaQuery.sizeOf(context).width < 650)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (value) {
                if (value == 'refresh') {
                  loadData();
                } else {
                  logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled: !loading,
                  child: const Text('Actualizar'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar sesión'),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'Actualizar',
              onPressed: loading ? null : loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ],
      ),
      floatingActionButton: showBackToTop
          ? FloatingActionButton.small(
              tooltip: 'Volver arriba',
              onPressed: backToTop,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: loadData,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardHeader(
                      period: period,
                      currency: currency,
                      loading: loading,
                      onFrom: () => chooseDate(true),
                      onUntil: () => chooseDate(false),
                      onCurrent: () {
                        final now = DateTime.now();
                        setState(() => period = DashboardPeriod.forMonth(now));
                        loadData();
                      },
                      onCurrencyChanged: (value) =>
                          setState(() => currency = value),
                    ),
                    const SizedBox(height: 12),
                    if (!loading)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Totales en ${currency == 'USD' ? 'dólares' : 'córdobas'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    rate == null
                                        ? 'Configura la tasa para combinar NIO y USD.'
                                        : '1 USD = C\$ ${rate.decimal} · Incluye ambas monedas',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (settingsError != null)
                                    const Text(
                                      'No se pudo cargar la tasa.',
                                      style: TextStyle(
                                        color: Color(0xFFB42318),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Configurar tasa de cambio',
                              onPressed: openSettings,
                              icon: const Icon(
                                Icons.currency_exchange_rounded,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 38),
                              const SizedBox(height: 12),
                              const Text('No pudimos cargar el resumen.'),
                              const SizedBox(height: 8),
                              SelectableText(error!),
                              TextButton(
                                onPressed: loadData,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!loading &&
                        error == null &&
                        current != null &&
                        presented != null) ...[
                      const SizedBox(height: 24),
                      DashboardMetrics(data: presented, currency: currency),
                      const SizedBox(height: 20),
                      UpcomingPaymentsPanel(
                        refreshToken: current.loadedAt,
                        onInstallments: (debt) =>
                            pushPage(DebtInstallmentsPage(debt: debt)),
                        onCard: (card) =>
                            pushPage(CreditCardStatementsPage(card: card)),
                        onDebt: (debt) => pushPage(
                          DebtsPage(
                            initialSearch:
                                debt['description']?.toString() ?? '',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DashboardFinancialHealth(
                        data: presented,
                        currency: currency,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'Accesos rápidos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    DashboardQuickActions(onOpen: openTarget),
                    if (!loading &&
                        error == null &&
                        current != null &&
                        presented != null) ...[
                      const SizedBox(height: 20),
                      ReceivableLoansDashboard(
                        refreshToken: current.loadedAt,
                        displayCurrency: rate == null ? null : currency,
                        exchangeRate: rate,
                        onChanged: () {
                          loadData();
                        },
                      ),
                      const SizedBox(height: 24),
                      DashboardMonthlyBalance(
                        data: presented,
                        currency: currency,
                      ),
                      const SizedBox(height: 20),
                      DashboardPanels(
                        data: presented,
                        currency: currency,
                        onOpen: openTarget,
                        onEvent: openEvent,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Actualizado a las '
                        '${current.loadedAt.hour.toString().padLeft(2, '0')}:'
                        '${current.loadedAt.minute.toString().padLeft(2, '0')} · '
                        '${presented.currencies[currency]!.movements} '
                        'movimientos en el rango',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
