
import '../../data/export_report_models.dart';
import '../../data/export_report_repository.dart';
import '../../utils/money.dart';
import '../statistics/obligation_repository.dart' show loadObligationData;
import '../statistics/obligation_statistics.dart' show ObligationData;
import '../statistics/statistics_charts.dart'
    show ChartGrouping, MonthlyBarChart, buildChartBuckets;
import '../reports/consolidated_expenses_panel.dart';
import '../../widgets/mobile_navigation.dart';
import '../../widgets/adaptive_layout.dart';
import '../help/app_help.dart';
import '../person_accounts/person_accounts_page.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/financial_settings_repository.dart';
import '../settings/settings_page.dart';
import 'dashboard_header.dart';
import 'dashboard_conversion.dart';
import '../auth/change_name_page.dart' show fetchProfileName;
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
import 'dashboard_navigation.dart';
import 'dashboard_financial_health.dart';
import 'upcoming_payments_panel.dart';
import '../reports/export_reports_page.dart';
import '../debts/debt_installments_page.dart';
import '../credit_cards/credit_card_statements_page.dart';
import '../credit_cards/card_payment_sheet_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardOverview? data;
  List<ExportMovement>? consolidatedMovements;
  ObligationData? obligationData;
  DashboardPeriod period = DashboardPeriod.forMonth(DateTime.now());
  ChartGrouping chartGrouping = ChartGrouping.weeks;
  String? selectedCreditCardId;
  bool obligationLoading = false;
  bool obligationError = false;
  String currency = 'NIO';
  FinancialSettings? financialSettings;
  String? settingsError;
  String? error;
  bool loading = true;
  bool signingOut = false;
  String? activeName;
  int profileRequestId = 0;
  int requestId = 0;

  final scrollController = ScrollController();
  bool showBackToTop = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(updateScrollButton);
    loadData();
    loadProfileName();
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
        loadIncomeExpenseData().then<List<ExportMovement>?>(
              (value) => value.movements,
          onError: (Object _) => null,
        ),
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
        consolidatedMovements = results[2] as List<ExportMovement>?;
        financialSettings = settingsResult.$1;
        settingsError = settingsResult.$2;
        loading = false;
      });
      loadObligations(request, userId);
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> loadObligations(int request, String? userId) async {
    if (mounted) {
      setState(() {
        obligationLoading = true;
        obligationError = false;
      });
    }
    try {
      final result = await loadObligationData();
      if (!mounted ||
          request != requestId ||
          supabase.auth.currentUser?.id != userId) {
        return;
      }
      setState(() {
        obligationData = result;
        obligationLoading = false;
        obligationError = false;
      });
    } catch (_) {
      if (mounted && request == requestId) {
        setState(() {
          obligationLoading = false;
          obligationError = true;
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

  Future<void> openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) await Future.wait([loadData(), loadProfileName()]);
  }

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
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo cerrar sesión: $e')));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  Future<void> loadProfileName() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final request = ++profileRequestId;
    try {
      final name = await fetchProfileName(userId);
      if (mounted &&
          request == profileRequestId &&
          supabase.auth.currentUser?.id == userId &&
          activeName != name) {
        setState(() => activeName = name);
      }
    } catch (_) {
      // El correo sigue identificando la cuenta si el perfil no está disponible.
    }
  }

  void updateScrollButton() {
    if (!mounted || scrollController.positions.length != 1) {
      return;
    }

    final visible = scrollController.offset > 500;

    if (visible != showBackToTop) {
      setState(() => showBackToTop = visible);
    }
  }

  void backToTop() {
    if (scrollController.positions.length != 1) {
      return;
    }

    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget creditCardEvolutionChart() {
    final obligations = obligationData;
    if (obligations == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (obligationLoading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  obligationError
                      ? 'No se pudieron cargar los movimientos de tarjetas.'
                      : 'Cargando movimientos de tarjetas...',
                ),
              ),
              if (obligationError)
                TextButton(
                  onPressed: () => loadObligations(
                    requestId,
                    supabase.auth.currentUser?.id,
                  ),
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      );
    }

    final cards = [...obligations.cards]
      ..sort((a, b) => '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}'));
    final validCardIds = cards.map((card) => '${card['id']}').toSet();
    final selectedId = selectedCreditCardId != null &&
        validCardIds.contains(selectedCreditCardId)
        ? selectedCreditCardId!
        : (cards.isEmpty ? null : '${cards.first['id']}');
    final selectedCard = selectedId == null
        ? null
        : cards.firstWhere((card) => '${card['id']}' == selectedId);

    final groupingLabel = switch (chartGrouping) {
      ChartGrouping.days => 'día',
      ChartGrouping.weeks => 'semana',
      ChartGrouping.months => 'mes',
      ChartGrouping.years => 'año',
    };

    if (cards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Evolución por tarjeta de crédito',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay tarjetas de crédito registradas.'),
            ),
          ),
        ],
      );
    }

    final cardId = selectedId!;

    // El gráfico sigue el filtro principal de moneda del Dashboard.
    final chartCurrency = currency.toUpperCase();
    final chartRate = financialSettings?.rate;
    final cardReference = '${selectedCard?['card_reference'] ?? ''}';
    final digits = cardReference.replaceAll(RegExp(r'\D'), '');
    final ending = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : '••••';

    final institution = selectedCard?['financial_institutions'];
    final bank = institution is Map ? '${institution['name'] ?? ''}' : '';

    final movements = obligations.cardMovements
        .where((movement) => movement['credit_card_id']?.toString() == cardId)
        .toList();

    var skippedCurrencyMovements = false;

    int netForRange(DateTime start, DateTime end) {
      var total = 0;

      for (final movement in movements) {
        // La marca de financiamiento por cobrar no elimina el consumo de la tarjeta.
        if (movement['is_voided'] == true) continue;

        final type = movement['transaction_type'];

        // Este gráfico representa únicamente gastos/compras; los pagos
        // realizados a la tarjeta no reducen el total de consumo.
        if (!['purchase', 'interest', 'fee'].contains(type)) continue;

        final rawDate = movement['transaction_date'];
        final parsedDate = DateTime.tryParse('$rawDate');
        if (parsedDate == null) continue;

        final date = parsedDate.toLocal();
        final day = DateUtils.dateOnly(date);

        if (day.isBefore(DateUtils.dateOnly(start)) ||
            day.isAfter(DateUtils.dateOnly(end))) {
          continue;
        }

        final sourceCurrency =
        '${movement['currency'] ?? chartCurrency}'.toUpperCase();

        var amount = moneyCents(movement['amount']);

        if (sourceCurrency != chartCurrency) {
          if (chartRate == null) {
            skippedCurrencyMovements = true;
            continue;
          }

          amount = chartRate.convert(amount, sourceCurrency, chartCurrency);
        }

        total += amount;
      }

      return total;
    }

    final values = buildChartBuckets(
      period.start,
      period.end,
      chartGrouping,
      netForRange,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Evolución por tarjeta de crédito',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: cardId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tarjeta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card_rounded),
                  isDense: true,
                ),
                items: cards.map((card) {
                  final reference = '${card['card_reference'] ?? ''}';
                  final cardDigits = reference.replaceAll(RegExp(r'\D'), '');
                  final lastFour = cardDigits.length >= 4
                      ? cardDigits.substring(cardDigits.length - 4)
                      : '••••';

                  final institutionData = card['financial_institutions'];
                  final institutionName = institutionData is Map
                      ? '${institutionData['name'] ?? ''}'
                      : '';

                  // Mostrar únicamente el banco y la terminación.
                  final label = [
                    if (institutionName.isNotEmpty) institutionName,
                    '••$lastFour',
                  ].join(' · ');

                  return DropdownMenuItem<String>(
                    value: '${card['id']}',
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCreditCardId = value);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<ChartGrouping>(
                value: chartGrouping,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Agrupar',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: ChartGrouping.values.map((grouping) {
                  final label = switch (grouping) {
                    ChartGrouping.days => 'Días',
                    ChartGrouping.weeks => 'Semanas',
                    ChartGrouping.months => 'Meses',
                    ChartGrouping.years => 'Años',
                  };

                  return DropdownMenuItem(
                    value: grouping,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => chartGrouping = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MonthlyBarChart(
          title: bank.isEmpty ? '••$ending' : '$bank · ••$ending',
          detail: 'Gastos (compras, intereses y comisiones) · $chartCurrency · Por $groupingLabel'
              '${skippedCurrencyMovements ? ' · Hay movimientos en otra moneda sin tasa disponible' : ''}',
          values: values,
          currency: chartCurrency,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    final rate = financialSettings?.rate;

    final presented = current == null || rate == null
        ? current
        : convertDashboard(current, currency, rate);

    final email = supabase.auth.currentUser?.email?.trim();
    final activeEmail = email == null || email.isEmpty
        ? 'Correo no disponible'
        : email;

    final gutter = pageGutter(context);
    final compact = compactLayout(context);

    return GuideScope(
      topic: 'dashboard',
      ready: !loading && error == null,
      welcome: true,
      scrollController: scrollController,
      child: Scaffold(
        key: dashboardScaffoldKey,
        bottomNavigationBar: compact
            ? MobileNavigation(index: 0, onReturn: loadData)
            : null,
        onDrawerChanged: (open) {
          if (open) loadProfileName();
        },
        drawer: DashboardNavigation(
          activeEmail: activeEmail,
          activeName: activeName,
          onOpen: openTarget,
          onSettings: openSettings,
          onExport: () => pushPage(const ExportReportsPage()),
          onPersonAccounts: () => pushPage(const PersonAccountsPage()),
          onOpenReceivables: () {
            openReceivableLoans();
          },
        ),
        appBar: AppBar(
          leading: GuideAnchor(
            id: 'menu',
            child: Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          ),
          title: GuideAnchor(
            id: 'title',
            child: const Text('Mi Billete'),
          ),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: signingOut ? null : logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        floatingActionButton: showBackToTop && !compact
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
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                gutter,
                12,
                gutter,
                compact ? 24 : 80,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: widePageMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GuideAnchor(
                        id: 'period',
                        child: DashboardHeader(
                          period: period,
                          currency: currency,
                          loading: loading,
                          onFrom: () => chooseDate(true),
                          onUntil: () => chooseDate(false),
                          onCurrent: () {
                            final now = DateTime.now();
                            setState(
                                  () => period = DashboardPeriod.forMonth(now),
                            );
                            loadData();
                          },
                          onCurrencyChanged: (value) =>
                              setState(() => currency = value),
                        ),
                      ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (error != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 38,
                                ),
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
                        const SizedBox(height: 12),
                        GuideAnchor(
                          id: 'metrics',
                          child: DashboardMetrics(
                            data: presented,
                            currency: currency,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (consolidatedMovements case final movements?) ...[
                          ConsolidatedExpensesPanel(
                            movements: movements,
                            exchangeRate: rate,
                            start: period.start,
                            end: period.end,
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          Card(
                            child: ListTile(
                              title: const Text(
                                'No se pudieron cargar los gastos consolidados',
                              ),
                              trailing: TextButton(
                                onPressed: loadData,
                                child: const Text('Reintentar'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                pushPage(const CardPaymentSheetPage()),
                            icon: const Icon(Icons.credit_card_outlined),
                            label: const Text('Hoja de pagos de tarjetas'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GuideAnchor(
                          id: 'upcoming',
                          child: UpcomingPaymentsPanel(
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
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!loading && error == null && presented != null) ...[
                        DashboardFinancialHealth(
                          data: presented,
                          currency: currency,
                        ),
                      ],
                      if (!loading &&
                          error == null &&
                          current != null &&
                          presented != null) ...[
                        const SizedBox(height: 20),
                        DashboardPanels(
                          data: presented,
                          currency: currency,
                          onOpen: openTarget,
                          onEvent: openEvent,
                          receivablesPanel: ReceivableLoansDashboard(
                            refreshToken: current.loadedAt,
                            displayCurrency: rate == null ? null : currency,
                            exchangeRate: rate,
                            onChanged: () {
                              loadData();
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        creditCardEvolutionChart(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
