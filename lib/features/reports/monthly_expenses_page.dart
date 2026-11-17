import '../../core/app_theme.dart' show appMuted;
import '../../widgets/collapsible_filters.dart';
import '../../widgets/date_period_field.dart';
import '../../data/period_logic.dart';
import '../help/app_help.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../data/credit_card_repository.dart';
import '../../data/debt_payment_repository.dart';
import '../../data/expense_report_categories.dart';
import '../../data/exchange_rate.dart';
import '../../data/financial_settings_repository.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/category_style.dart';
import 'category_expenses_dialog.dart';
import 'expense_report_widgets.dart';

typedef _CategoryRow = ({String key, String currency, int cents, Widget card});

class MonthlyExpensesPage extends StatefulWidget {
  const MonthlyExpensesPage({super.key});
  @override
  State<MonthlyExpensesPage> createState() => _MonthlyExpensesPageState();
}

class _MonthlyExpensesPageState extends State<MonthlyExpensesPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime end = DateTime.now();
  String currency = 'both';
  String selectedCategory = 'all';
  List<Map<String, dynamic>> expenses = [];
  Map<String, String> categoryNames = {};
  Map<String, Map<String, dynamic>> categoryStyles = {};
  ExchangeRate? exchangeRate;
  bool loading = true;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String categoryName(String key) =>
      expenseReportCategoryLabels[key] ??
      categoryNames[key] ??
      'Categoría no disponible';

  Future<void> loadData() async {
    if (!mounted) {
      return;
    }
    final request = ++requestId;
    final start = month, until = end;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Debes iniciar sesión nuevamente.');
      }
      final names = <String, String>{};
      final styles = <String, Map<String, dynamic>>{};
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('categories')
            .select('id, name, icon, color, category_type')
            .eq('user_id', user.id)
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        for (final category in page) {
          final id = category['id'].toString();
          names[id] = category['name'].toString();
          styles[id] = category;
        }
        if (page.length < 500) {
          break;
        }
      }
      final rows = [
        ...await loadUserTransactions(user.id),
        ...await loadUserCardExpenses(user.id),
        ...debtPaymentExpenses(await loadUserDebtPayments(user.id)),
      ];
      ExchangeRate? rate;
      try {
        rate = (await loadFinancialSettings())?.rate;
      } catch (e) {
        debugPrint('No se pudo cargar la tasa para gastos por categoría: $e');
      }
      final selected = <Map<String, dynamic>>[];
      for (final tx in rows) {
        if (tx['transaction_type'] != 'expense') {
          continue;
        }
        final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
        if (date == null) {
          throw const FormatException('Un gasto tiene una fecha inválida.');
        }
        if (includesDay(date, start, until)) {
          selected.add(tx);
        }
      }
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        categoryNames = names;
        categoryStyles = styles;
        expenses = selected;
        exchangeRate = rate;
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

  ({Widget summary, List<_CategoryRow> categories}) currencyReport(
    String reportCurrency,
  ) {
    final filteredExpenses = expenses
        .where(
          (tx) =>
              (currency != 'both' || tx['currency'] == reportCurrency) &&
              (selectedCategory == 'all' ||
                  expenseReportCategoryKey(tx) == selectedCategory),
        )
        .toList();
    final rate = currency == 'both' ? null : exchangeRate;
    if (rate == null &&
        filteredExpenses.any((tx) => tx['currency'] != reportCurrency)) {
      return (
        summary: const Text(
          'Se necesita una tasa de cambio válida en Configuraciones para '
          'ver todos los gastos en una sola moneda.',
        ),
        categories: const [],
      );
    }
    final totals = <String, int>{}, counts = <String, int>{};
    int charges = 0, refunds = 0;
    for (final tx in filteredExpenses) {
      final key = expenseReportCategoryKey(tx);
      final amount = expenseReportAmount(tx, reportCurrency, rate);
      if (amount < 0) {
        refunds += -amount;
      } else {
        charges += amount;
      }
      totals[key] = (totals[key] ?? 0) + amount;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final groups = totals.entries;
    final positiveTotal = groups.fold<int>(
      0,
      (sum, group) => sum + (group.value > 0 ? group.value : 0),
    );

    final currencyLabel = reportCurrency == 'NIO' ? 'Córdobas' : 'Dólares';
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(currencyLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ExpenseReportSummary(
          currency: reportCurrency,
          chargesCents: charges,
          refundsCents: refunds,
          count: filteredExpenses.length,
          compact: true,
        ),
        if (filteredExpenses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Sin movimientos con estos filtros.'),
          ),
      ],
    );
    return (
      summary: summary,
      categories: groups.map((group) {
        final name = categoryName(group.key);
        final style = categoryStyles[group.key];
        final card = ExpenseCategoryCard(
          name: name,
          currency: reportCurrency,
          amountCents: group.value,
          count: counts[group.key] ?? 0,
          positiveTotalCents: positiveTotal,
          color: group.key == 'uncategorized'
              ? appMuted
              : categoryColor(style?['color']),
          icon: switch (group.key) {
            'debt_costs' => Icons.payments_outlined,
            'card_refunds' => Icons.undo_rounded,
            'card_insurance' => Icons.shield_outlined,
            'card_purchases' ||
            'card_interest' ||
            'card_fees' ||
            'card_other' => Icons.credit_card_outlined,
            'uncategorized' => Icons.help_outline_rounded,
            _ => categoryIcon(style?['icon']),
          },
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => CategoryExpensesDialog(
              name: name,
              currency: reportCurrency,
              exchangeRate: rate,
              expenses: filteredExpenses
                  .where((tx) => expenseReportCategoryKey(tx) == group.key)
                  .toList(),
            ),
          ),
        );
        return (
          key: group.key,
          currency: reportCurrency,
          cents: group.value,
          card: card,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions =
        {
          for (final entry in categoryStyles.entries)
            if (entry.value['category_type'] == 'expense') entry.key,
          'debt_costs',
          ...expenses.map(expenseReportCategoryKey),
          if (selectedCategory != 'all') selectedCategory,
        }.where((key) => key != 'uncategorized').toList()..sort(
          (a, b) => categoryName(
            a,
          ).toLowerCase().compareTo(categoryName(b).toLowerCase()),
        );

    final reports = [
      if (!loading && error == null)
        for (final reportCurrency
            in currency == 'both' ? const ['NIO', 'USD'] : [currency])
          currencyReport(reportCurrency),
    ];
    final categories = [for (final report in reports) ...report.categories];
    final rate = exchangeRate;
    final mixedCurrencies =
        categories.map((entry) => entry.currency).toSet().length > 1;
    final missingRate = mixedCurrencies && rate == null;
    // Compare exact USD equivalents with a shared denominator.
    BigInt dollarOrder(_CategoryRow entry) =>
        BigInt.from(entry.cents) *
        BigInt.from(
          entry.currency == 'USD' ? rate?.micros ?? 1000000 : 1000000,
        );
    categories.sort((a, b) {
      if (missingRate && a.currency != b.currency) {
        return a.currency.compareTo(b.currency);
      }
      final byAmount = dollarOrder(b).compareTo(dollarOrder(a));
      if (byAmount != 0) return byAmount;
      final byCategory = a.key.compareTo(b.key);
      return byCategory != 0 ? byCategory : a.currency.compareTo(b.currency);
    });
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos por categoría'),
        actions: [
          const AppHelpButton(topic: 'reports'),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: RefreshIndicator(
              onRefresh: () async {
                if (!loading) await loadData();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  pageGutter(context),
                  12,
                  pageGutter(context),
                  32,
                ),
                children: [
                  CollapsibleFilters(
                    summary: currency == 'both'
                        ? 'Ambas monedas'
                        : currency == 'NIO'
                        ? 'Córdobas'
                        : 'Dólares',
                    children: [
                      DatePeriodField(
                        minColumnWidth: 136,
                        start: month,
                        end: end,
                        enabled: !loading,
                        onChanged: (range) {
                          setState(() {
                            month = range.start;
                            end = range.end;
                          });
                          loadData();
                        },
                      ),
                      AdaptiveColumns(
                        minColumnWidth: 148,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: currency,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Moneda',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'both',
                                child: Text('Ambas monedas'),
                              ),
                              DropdownMenuItem(
                                value: 'NIO',
                                child: Text('Córdobas (C\$)'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('Dólares (\$)'),
                              ),
                            ],
                            onChanged: loading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => currency = value);
                                    }
                                  },
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('Todas las categorías'),
                              ),
                              for (final key in categoryOptions)
                                DropdownMenuItem(
                                  value: key,
                                  child: Text(
                                    categoryName(key),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const DropdownMenuItem(
                                value: 'uncategorized',
                                child: Text('Sin categoría'),
                              ),
                            ],
                            onChanged: loading
                                ? null
                                : (value) {
                                    if (value != null)
                                      setState(() => selectedCategory = value);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (error case final problem?) ...[
                    const Text('No se pudo cargar el reporte.'),
                    SelectableText(problem),
                    TextButton(
                      onPressed: loadData,
                      child: const Text('Reintentar'),
                    ),
                  ] else ...[
                    Text(
                      'Resumen de gastos',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'El gasto neto es el total de cargos menos las devoluciones.',
                    ),
                    if (exchangeRate case final rate? when currency != 'both')
                      Text('Tasa configurada · \$ 1 = C\$ ${rate.decimal}'),
                    const SizedBox(height: 12),
                    AdaptiveColumns(
                      minColumnWidth: 300,
                      children: [for (final report in reports) report.summary],
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Distribución por categoría',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cada porcentaje representa la parte del gasto neto positivo en su moneda.',
                      ),
                      const SizedBox(height: 12),
                      if (missingRate)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Configura una tasa de cambio para ordenar juntas '
                            'las categorías en córdobas y dólares.',
                          ),
                        ),
                      for (final entry in categories) entry.card,
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Incluye gastos de cuentas y tarjetas y abonos de deuda, con su capital, intereses, seguros y comisiones. Excluye pagos de tarjeta.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
