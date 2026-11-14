import 'dart:async';

import '../../data/exchange_rate.dart';
import '../../data/financial_settings_repository.dart';
import '../../data/period_logic.dart' show isoDay;
import 'package:flutter/material.dart';
import '../../data/export_report_models.dart';
import '../../data/export_report_repository.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/date_period_field.dart';
import 'obligation_repository.dart';
import 'obligation_statistics.dart';
import 'statistics_charts.dart';
import 'statistics_summary.dart';

enum _StatisticsView { summary, expenses, debts }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late DateTimeRange range;
  String currency = 'NIO';
  _StatisticsView view = _StatisticsView.summary;
  ExchangeRate? rate;
  ObligationData? obligations;
  List<ExportMovement> movements = [];
  Map<String, String> categories = {};
  bool loading = true;
  bool failed = false;
  int request = 0;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    range = DateTimeRange(start: DateTime(today.year, today.month), end: today);
    load();
  }

  Future<void> load() async {
    final id = ++request;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final (result, settings, obligationData) = await (
        loadIncomeExpenseData(),
        loadFinancialSettings(),
        loadObligationData().then<ObligationData?>(
          (data) => data,
          onError: (Object _) => null,
        ),
      ).wait;
      if (!mounted || id != request) return;
      setState(() {
        movements = result.movements;
        rate = settings?.rate;
        obligations = obligationData;
        categories = {
          for (final category in result.categories)
            '${category['id']}': '${category['name']}',
        };
        loading = false;
      });
    } catch (_) {
      if (!mounted || id != request) return;
      setState(() {
        failed = true;
        loading = false;
      });
    }
  }

  Widget panel(String title, Widget child, {String? detail}) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (detail != null)
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: PageFrame(
        maxWidth: widePageMaxWidth,
        child: ListView(
          padding: EdgeInsets.all(pageGutter(context)),
          children: [
            filters(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (option, label) in const [
                  (_StatisticsView.summary, 'Resumen'),
                  (_StatisticsView.expenses, 'Gastos'),
                  (_StatisticsView.debts, 'Deudas'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: view == option,
                    onSelected: (selected) {
                      if (selected) setState(() => view = option);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (failed)
              panel(
                'No se pudieron cargar las estadísticas',
                OutlinedButton(
                  onPressed: load,
                  child: const Text('Reintentar'),
                ),
              )
            else if (rate == null)
              panel(
                'Configura la tasa de cambio',
                const Text(
                  'Guarda la tasa en Configuraciones y vuelve a abrir Estadísticas.',
                ),
              )
            else ...[
              Text('Tasa configurada: US\$ 1 = C\$ ${rate!.decimal}'),
              const SizedBox(height: 12),
              if (view == _StatisticsView.debts)
                obligationPanels(rate!)
              else
                ...statistics(rate!),
            ],
          ],
        ),
      ),
    );
  }

  Widget filters() {
    final period = DatePeriodField(
      start: range.start,
      end: range.end,
      onChanged: (value) {
        if (mounted) setState(() => range = value);
      },
    );
    final currencyField = DropdownButtonFormField<String>(
      initialValue: currency,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Moneda'),
      items: const [
        DropdownMenuItem(value: 'NIO', child: Text('Córdobas · NIO')),
        DropdownMenuItem(value: 'USD', child: Text('Dólares · USD')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => currency = value);
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 620 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [currencyField, period],
          );
        }
        return Row(
          children: [
            SizedBox(width: 210 * scale, child: currencyField),
            Expanded(child: period),
          ],
        );
      },
    );
  }

  Widget metric(String label, String value, IconData icon, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> statistics(ExchangeRate exchangeRate) {
    final summary = StatisticsSummary(
      movements: movements,
      categories: categories,
      start: range.start,
      end: range.end,
      currency: currency,
      rate: exchangeRate,
    );
    if (view == _StatisticsView.expenses) {
      return [
        if (summary.expenseCategories.isEmpty)
          panel(
            'Sin gastos por categoría',
            const Text('No hay gastos para mostrar en el período elegido.'),
          )
        else
          overviewPanels([
            panel(
              'Distribución de gastos',
              ExpensePie(
                categories: summary.expenseCategories,
                currency: currency,
              ),
              detail: 'Participación por categoría antes de devoluciones.',
            ),
            panel(
              'Categorías con mayor gasto',
              StatisticsBars(
                currency: currency,
                rows: [
                  for (final entry in summary.expenseCategories.take(8))
                    (label: entry.key, cents: entry.value, color: expenseColor),
                ],
              ),
              detail: 'Hasta ocho categorías por gasto antes de devoluciones.',
            ),
          ]),
      ];
    }
    final first = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final previousEnd = first.subtract(const Duration(days: 1));
    final previousStart = first.subtract(Duration(days: summary.dayCount));
    final previous = StatisticsSummary(
      movements: movements,
      categories: categories,
      start: previousStart,
      end: previousEnd,
      currency: currency,
      rate: exchangeRate,
    );
    String money(int cents) => formatMoneyCents(cents, currency);
    String change(int cents) => '${cents > 0 ? '+' : ''}${money(cents)}';
    Widget comparison(String label, int current, int prior) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text('Actual ${money(current)}'),
              Text('Anterior ${money(prior)}'),
              Text('Variación ${change(current - prior)}'),
            ],
          ),
        ],
      ),
    );
    return [
      if (summary.movementCount == 0 && previous.movementCount == 0)
        panel(
          'Sin ingresos o gastos en este período',
          const Text('Prueba con otro rango de fechas o moneda.'),
        )
      else ...[
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
                .clamp(1.0, 1.8);
            return AdaptiveColumns(
              minColumnWidth: 138,
              maxColumns: constraints.maxWidth >= 620 * scale ? 4 : 2,
              children: [
                metric(
                  'Ingresos',
                  money(summary.income),
                  Icons.south_west_rounded,
                  incomeColor,
                ),
                metric(
                  'Gastos netos',
                  money(summary.netExpenses),
                  Icons.north_east_rounded,
                  expenseColor,
                ),
                metric(
                  'Ingresos menos gastos',
                  money(summary.balance),
                  Icons.account_balance_wallet_outlined,
                  summary.balance < 0 ? expenseColor : incomeColor,
                ),
                metric(
                  'Devoluciones',
                  money(summary.refunds),
                  Icons.undo_rounded,
                  categoryColors[0],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        overviewPanels([
          panel(
            'Comparación del período',
            StatisticsBars(
              currency: currency,
              rows: [
                (label: 'Ingresos', cents: summary.income, color: incomeColor),
                (
                  label: 'Gastos antes de devoluciones',
                  cents: summary.grossExpenses,
                  color: expenseColor,
                ),
                (
                  label: 'Devoluciones',
                  cents: summary.refunds,
                  color: categoryColors[0],
                ),
              ],
            ),
          ),
          panel(
            'Comparación con el período anterior',
            Column(
              children: [
                comparison('Ingresos', summary.income, previous.income),
                comparison(
                  'Gastos netos',
                  summary.netExpenses,
                  previous.netExpenses,
                ),
                comparison('Resultado', summary.balance, previous.balance),
              ],
            ),
            detail:
                'Anterior: ${isoDay(previousStart)} a ${isoDay(previousEnd)} · ${summary.dayCount} días.',
          ),
          panel(
            'Actividad del período',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingresos registrados: ${summary.incomeCount}'),
                Text('Gastos registrados: ${summary.expenseCount}'),
                Text('Gasto neto diario: ${money(summary.dailyNetExpense)}'),
                Text(
                  'Mayor gasto individual: ${money(summary.largestExpense)}',
                ),
              ],
            ),
          ),
          if (summary.incomeCategories.isNotEmpty)
            panel(
              'Distribución de ingresos',
              ExpensePie(
                categories: summary.incomeCategories,
                currency: currency,
              ),
            ),
        ]),
      ],
    ];
  }

  Widget overviewPanels(List<Widget> panels) => LayoutBuilder(
    builder: (context, constraints) {
      final count = panelColumnCount(
        context,
        constraints.maxWidth,
      ).clamp(1, panels.length).toInt();
      return stackedPanels([
        for (var column = 0; column < count; column++)
          [
            for (var index = column; index < panels.length; index += count)
              panels[index],
          ],
      ]);
    },
  );

  int panelColumnCount(BuildContext context, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (width >= 1120 * scale) return 3;
    if (width >= 690 * scale) return 2;
    return 1;
  }

  Widget stackedPanels(List<List<Widget>> columns) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < columns.length; index++) ...[
        if (index > 0) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (position, panel) in columns[index].indexed) ...[
                if (position > 0) const SizedBox(height: 12),
                panel,
              ],
            ],
          ),
        ),
      ],
    ],
  );

  Widget obligationPanels(ExchangeRate exchangeRate) {
    final data = obligations;
    if (data == null) {
      return panel(
        'Tarjetas, deudas, préstamos y personas',
        OutlinedButton(onPressed: load, child: const Text('Reintentar')),
        detail: 'No se pudieron cargar estos saldos.',
      );
    }
    final List<ObligationSection> sections;
    try {
      sections = obligationStatistics(
        data,
        exchangeRate,
        currency,
        range.start,
        range.end,
        DateTime.now(),
      );
    } catch (_) {
      return panel(
        'Tarjetas, deudas, préstamos y personas',
        const Text(
          'No se pudieron calcular los saldos. Revisa los movimientos registrados.',
        ),
      );
    }

    final panels = sections.map(obligationPanel).toList();
    final cards = panels[0];
    final debts = panels[1];
    final loans = panels[2];
    final people = panels[3];
    final overdue = panels.skip(4);
    return LayoutBuilder(
      builder: (context, constraints) {
        return stackedPanels(switch (panelColumnCount(
          context,
          constraints.maxWidth,
        )) {
          3 => [
            [cards],
            [debts, ...overdue],
            [loans, people],
          ],
          2 => [
            [cards, loans],
            [debts, ...overdue, people],
          ],
          _ => [
            [cards, debts, ...overdue, loans, people],
          ],
        });
      },
    );
  }

  Widget obligationPanel(ObligationSection section) {
    final ranking = [...section.ranking]
      ..sort((a, b) => b.value.compareTo(a.value));
    return panel(
      section.title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldos actuales',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final row in section.snapshot)
            Text('${row.key}: ${formatMoneyCents(row.value, currency)}'),
          if (section.activity.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Movimientos del período',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (section.activity.every((row) => row.value == 0))
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Sin movimientos en el período'),
              )
            else
              StatisticsBars(
                currency: currency,
                rows: [
                  for (final row in section.activity)
                    (
                      label: row.key,
                      cents: row.value,
                      color: categoryColors[0],
                    ),
                ],
              ),
          ],
          if (ranking.isNotEmpty) ...[
            Text(
              section.activity.isEmpty
                  ? 'Cuotas con mayor saldo pendiente'
                  : 'Mayores saldos actuales',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            StatisticsBars(
              currency: currency,
              rows: [
                for (final row in ranking.take(8))
                  (label: row.key, cents: row.value, color: expenseColor),
              ],
            ),
          ],
        ],
      ),
      detail: section.note,
    );
  }
}
