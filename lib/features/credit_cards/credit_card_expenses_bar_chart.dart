import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart' show appBorder, appMuted, primaryColor;
import '../../data/card_spending.dart';
import '../../data/exchange_rate.dart';
import '../../data/payment_agenda_labels.dart';
import '../../data/period_logic.dart';
import '../../utils/money.dart';

typedef CardDataRecord = Map<String, dynamic>;

enum CardChartGranularity { day, week, month, year }

enum _ViewportTier { mobile, tablet, desktop }

/// Formatea cualquier valor escalado por [moneyScale] exactamente a 2 decimales
/// (ej. 78.38, 4,538.00) sin símbolo de moneda.
String _formatTwoDecimals(int scaledAmount) {
  final sign = scaledAmount < 0 ? '-' : '';
  final cents = (scaledAmount.abs() * 100 / moneyScale).round();
  final integerPart = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
  );
  final decimalPart = (cents % 100).toString().padLeft(2, '0');
  return '$sign$integerPart.$decimalPart';
}

class CreditCardExpensesBarChart extends StatefulWidget {
  const CreditCardExpensesBarChart({
    super.key,
    required this.cards,
    required this.movements,
    this.generalExchangeRate,
    this.initialCurrency = 'BOTH',
    this.title = 'Gastos de tarjetas de crédito',
  });

  final List<CardDataRecord> cards;
  final List<CardDataRecord> movements;
  final ExchangeRate? generalExchangeRate;
  final String initialCurrency;
  final String title;

  @override
  State<CreditCardExpensesBarChart> createState() =>
      _CreditCardExpensesBarChartState();
}

class _CreditCardExpensesBarChartState
    extends State<CreditCardExpensesBarChart> {
  static final Color _usdBarColor = primaryColor;
  static const Color _nioBarColor = Color(0xFF277354);

  late DateTimeRange _range;
  late String _currency; // 'BOTH' | 'USD' | 'NIO'
  String? _selectedCardId;
  CardChartGranularity _granularity = CardChartGranularity.day;

  @override
  void initState() {
    super.initState();
    _currency = {'BOTH', 'USD', 'NIO'}.contains(widget.initialCurrency)
        ? widget.initialCurrency
        : 'BOTH';
    _range = _currentMonthRange();
  }

  DateTimeRange _currentMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  DateTime? _latestMovementDate() {
    DateTime? latest;
    for (final m in widget.movements) {
      if (_selectedCardId != null &&
          '${m['credit_card_id']}' != _selectedCardId) {
        continue;
      }
      if (cardSpendingCents(m) == 0) continue;
      final d = DateTime.tryParse('${m['transaction_date']}')?.toLocal();
      if (d != null && (latest == null || d.isAfter(latest))) {
        latest = d;
      }
    }
    return latest;
  }

  _ViewportTier _tierForWidth(double width) {
    if (width < 650) return _ViewportTier.mobile;
    if (width < 1024) return _ViewportTier.tablet;
    return _ViewportTier.desktop;
  }

  String _cardBankAndNumber(CardDataRecord card) =>
      agendaCardLabel(card, includeName: false);

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      helpText: isStart ? 'Fecha inicial' : 'Fecha final',
      initialDate: isStart ? _range.start : _range.end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = isStart
          ? DateTimeRange(
        start: picked,
        end: picked.isAfter(_range.end) ? picked : _range.end,
      )
          : DateTimeRange(
        start: picked.isBefore(_range.start) ? picked : _range.start,
        end: picked,
      );
    });
  }

  void _openFullScreenChart(_ChartSeriesResult computed) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLegend(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => _ResponsiveBarCanvas(
                        buckets: computed.buckets,
                        currencyMode: _currency,
                        usdColor: _usdBarColor,
                        nioColor: _nioBarColor,
                        tier: _tierForWidth(box.maxWidth),
                        forcedHeight: math.max(340, box.maxHeight - 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final computed = _computeSeries();
    final isBoth = _currency == 'BOTH';
    final hasAnySpending = computed.buckets.any(
          (b) => isBoth ? (b.usdCents > 0 || b.nioCents > 0) : b.singleCents > 0,
    );
    final latestDate = hasAnySpending ? null : _latestMovementDate();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tier = _tierForWidth(constraints.maxWidth);
        final cardPadding = switch (tier) {
          _ViewportTier.mobile => 16.0,
          _ViewportTier.tablet => 20.0,
          _ViewportTier.desktop => 24.0,
        };

        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: appBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, computed, tier, hasAnySpending),
                const SizedBox(height: 14),
                _buildFilters(context, tier),
                const SizedBox(height: 12),
                _buildGranularitySelector(context, tier),
                const SizedBox(height: 12),
                _buildLegend(),
                const SizedBox(height: 14),
                if (widget.cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Aún no tienes tarjetas de crédito registradas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appMuted),
                    ),
                  )
                else if (!hasAnySpending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Text(
                          'No hay gastos de tarjeta en el rango ${isoDay(_range.start)} al ${isoDay(_range.end)}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: appMuted),
                        ),
                        if (latestDate != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _range = DateTimeRange(
                                  start: DateTime(
                                    latestDate.year,
                                    latestDate.month,
                                    1,
                                  ),
                                  end: DateTime(
                                    latestDate.year,
                                    latestDate.month + 1,
                                    0,
                                  ),
                                );
                                _granularity = CardChartGranularity.day;
                              });
                            },
                            icon: const Icon(Icons.history_rounded, size: 18),
                            label: Text(
                              'Ver último mes con gastos (${latestDate.month.toString().padLeft(2, '0')}/${latestDate.year})',
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  _ResponsiveBarCanvas(
                    buckets: computed.buckets,
                    currencyMode: _currency,
                    usdColor: _usdBarColor,
                    nioColor: _nioBarColor,
                    tier: tier,
                  ),
                const SizedBox(height: 12),
                _buildFooterNote(computed),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    if (_currency == 'BOTH') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appBorder),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            _legendItem(
              color: _usdBarColor,
              code: 'USD',
              description: 'Dólares',
            ),
            _legendItem(
              color: _nioBarColor,
              code: 'NIO',
              description: 'Córdobas',
            ),
          ],
        ),
      );
    }

    final isUsd = _currency == 'USD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isUsd ? _usdBarColor : _nioBarColor).withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBorder),
      ),
      child: _legendItem(
        color: isUsd ? _usdBarColor : _nioBarColor,
        code: isUsd ? 'USD' : 'NIO',
        description: isUsd ? 'Dólares' : 'Córdobas',
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    required String code,
    required String description,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withAlpha(225),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            code,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            description,
            style: TextStyle(
              color: appMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context,
      _ChartSeriesResult computed,
      _ViewportTier tier,
      bool hasAnySpending,
      ) {
    final isMobile = tier == _ViewportTier.mobile;
    final isBoth = _currency == 'BOTH';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                color: primaryColor,
                size: isMobile ? 22 : 24,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: (isMobile
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${isoDay(_range.start)} al ${isoDay(_range.end)}',
                    style: TextStyle(color: appMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBoth)
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total USD',
                        style: TextStyle(color: appMuted, fontSize: 11.5),
                      ),
                      Text(
                        _formatTwoDecimals(computed.totalUsdCents),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _usdBarColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total NIO',
                        style: TextStyle(color: appMuted, fontSize: 11.5),
                      ),
                      Text(
                        _formatTwoDecimals(computed.totalNioCents),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _nioBarColor,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total gasto neto ($_currency)',
                    style: TextStyle(color: appMuted, fontSize: 12),
                  ),
                  Text(
                    _formatTwoDecimals(computed.totalSingleCents),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _currency == 'USD' ? _usdBarColor : _nioBarColor,
                    ),
                  ),
                ],
              ),
            if (hasAnySpending) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Ampliar gráfico',
                onPressed: () => _openFullScreenChart(computed),
                icon: const Icon(Icons.open_in_full_rounded, size: 20),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, _ViewportTier tier) {
    final validSelectedId =
    widget.cards.any((c) => '${c['id']}' == _selectedCardId)
        ? _selectedCardId
        : null;

    final cardDropdown = DropdownButtonFormField<String?>(
      value: validSelectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tarjeta de crédito',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todas las tarjetas', overflow: TextOverflow.ellipsis),
        ),
        for (final card in widget.cards)
          DropdownMenuItem<String?>(
            value: '${card['id']}',
            child: Text(
              _cardBankAndNumber(card),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => _selectedCardId = value),
    );

    final currencyDropdown = DropdownButtonFormField<String>(
      value: _currency,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Moneda',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: const [
        DropdownMenuItem(value: 'BOTH', child: Text('Ambos · USD y NIO')),
        DropdownMenuItem(value: 'USD', child: Text('Dólares · USD')),
        DropdownMenuItem(value: 'NIO', child: Text('Córdobas · NIO')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _currency = value);
      },
    );

    final startBtn = OutlinedButton.icon(
      onPressed: () => _pickDate(true),
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('Desde: ${isoDay(_range.start)}'),
    );

    final endBtn = OutlinedButton.icon(
      onPressed: () => _pickDate(false),
      icon: const Icon(Icons.event_outlined, size: 16),
      label: Text('Hasta: ${isoDay(_range.end)}'),
    );

    final currentMonthBtn = TextButton.icon(
      onPressed: () => setState(() {
        _range = _currentMonthRange();
        _granularity = CardChartGranularity.day;
      }),
      icon: const Icon(Icons.today_rounded, size: 16),
      label: const Text('Mes actual'),
    );

    switch (tier) {
      case _ViewportTier.desktop:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: cardDropdown),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: currencyDropdown),
            const SizedBox(width: 10),
            startBtn,
            const SizedBox(width: 8),
            endBtn,
            const SizedBox(width: 4),
            currentMonthBtn,
          ],
        );

      case _ViewportTier.tablet:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: cardDropdown),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: currencyDropdown),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [startBtn, endBtn, currentMonthBtn],
            ),
          ],
        );

      case _ViewportTier.mobile:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cardDropdown,
            const SizedBox(height: 8),
            currencyDropdown,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: startBtn),
                const SizedBox(width: 8),
                Expanded(child: endBtn),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: currentMonthBtn,
            ),
          ],
        );
    }
  }

  Widget _buildGranularitySelector(BuildContext context, _ViewportTier tier) {
    final selector = SegmentedButton<CardChartGranularity>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: CardChartGranularity.day, label: Text('Día')),
        ButtonSegment(value: CardChartGranularity.week, label: Text('Semana')),
        ButtonSegment(value: CardChartGranularity.month, label: Text('Mes')),
        ButtonSegment(value: CardChartGranularity.year, label: Text('Año')),
      ],
      selected: {_granularity},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          setState(() => _granularity = selection.first);
        }
      },
    );

    if (tier == _ViewportTier.desktop) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(width: 440, child: selector),
      );
    }
    return selector;
  }

  Widget _buildFooterNote(_ChartSeriesResult computed) {
    final isBoth = _currency == 'BOTH';
    final notes = <String>[
      'Incluye compras, intereses y comisiones netas (descontando devoluciones).',
      if (isBoth)
        'En modo Ambos cada moneda se muestra en su valor original.'
      else ...[
        'Conversión aplicada con la tasa de cada tarjeta.',
        if (computed.usedGeneralRate)
          'En tarjetas sin tasa propia se usó la tasa general.',
        if (computed.omittedForeign)
          'Algunos movimientos en otra moneda sin tasa configurada fueron omitidos.',
      ],
    ];
    return Text(
      notes.join(' '),
      style: TextStyle(color: appMuted, fontSize: 12, height: 1.4),
    );
  }

  _ChartSeriesResult _computeSeries() {
    final cardRates = <String, ExchangeRate?>{
      for (final card in widget.cards)
        '${card['id']}': ExchangeRate.tryParse(
          card['limit_exchange_rate']?.toString() ?? '',
        ),
    };

    final start = dayOnly(_range.start);
    final end = dayOnly(_range.end);

    final bucketOrder = <String>[];
    final bucketLabels = <String, String>{};
    final usdTotals = <String, int>{};
    final nioTotals = <String, int>{};
    final singleTotals = <String, int>{};

    _seedBuckets(
      start,
      end,
      bucketOrder,
      bucketLabels,
      usdTotals,
      nioTotals,
      singleTotals,
    );

    var totalUsdCents = 0;
    var totalNioCents = 0;
    var totalSingleCents = 0;
    var usedGeneralRate = false;
    var omittedForeign = false;
    final isBoth = _currency == 'BOTH';

    for (final movement in widget.movements) {
      final cardId = movement['credit_card_id']?.toString();
      if (cardId == null) continue;
      if (_selectedCardId != null && cardId != _selectedCardId) continue;

      final rawDate = DateTime.tryParse(
        '${movement['transaction_date']}',
      )?.toLocal();
      if (rawDate == null || !includesDay(rawDate, start, end)) continue;

      final rawCents = cardSpendingCents(movement);
      if (rawCents == 0) continue;

      final txCurrency =
          movement['currency']?.toString().trim().toUpperCase() ?? '';
      if (txCurrency != 'USD' && txCurrency != 'NIO') continue;

      final key = _bucketKey(dayOnly(rawDate));
      if (!bucketLabels.containsKey(key)) {
        bucketOrder.add(key);
        bucketLabels[key] = key;
        usdTotals[key] = 0;
        nioTotals[key] = 0;
        singleTotals[key] = 0;
      }

      if (isBoth) {
        if (txCurrency == 'USD') {
          usdTotals[key] = (usdTotals[key] ?? 0) + rawCents;
          totalUsdCents += rawCents;
        } else {
          nioTotals[key] = (nioTotals[key] ?? 0) + rawCents;
          totalNioCents += rawCents;
        }
      } else {
        var convertedCents = rawCents;
        if (txCurrency != _currency) {
          final cardRate = cardRates[cardId];
          final effectiveRate = cardRate ?? widget.generalExchangeRate;
          if (effectiveRate == null) {
            omittedForeign = true;
            continue;
          }
          if (cardRate == null) usedGeneralRate = true;
          convertedCents = effectiveRate.convert(rawCents, txCurrency, _currency);
        }
        singleTotals[key] = (singleTotals[key] ?? 0) + convertedCents;
        totalSingleCents += convertedCents;
      }
    }

    final buckets = [
      for (final key in bucketOrder)
        _BarBucket(
          label: bucketLabels[key] ?? key,
          usdCents: math.max(0, usdTotals[key] ?? 0),
          nioCents: math.max(0, nioTotals[key] ?? 0),
          singleCents: math.max(0, singleTotals[key] ?? 0),
        ),
    ];

    return _ChartSeriesResult(
      buckets: buckets,
      totalUsdCents: totalUsdCents,
      totalNioCents: totalNioCents,
      totalSingleCents: totalSingleCents,
      usedGeneralRate: usedGeneralRate,
      omittedForeign: omittedForeign,
    );
  }

  void _seedBuckets(
      DateTime start,
      DateTime end,
      List<String> order,
      Map<String, String> labels,
      Map<String, int> usdTotals,
      Map<String, int> nioTotals,
      Map<String, int> singleTotals,
      ) {
    const monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

    void addBucket(String key, String label) {
      order.add(key);
      labels[key] = label;
      usdTotals[key] = 0;
      nioTotals[key] = 0;
      singleTotals[key] = 0;
    }

    switch (_granularity) {
      case CardChartGranularity.day:
        final totalDays = end.difference(start).inDays + 1;
        if (totalDays > 120) return;
        for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
          addBucket(_bucketKey(d), '${d.day}/${d.month}');
        }
      case CardChartGranularity.week:
        final totalDays = end.difference(start).inDays + 1;
        if (totalDays > 730) return;
        var cursor = _weekStart(start);
        while (!cursor.isAfter(end)) {
          final k = _bucketKey(cursor);
          if (!labels.containsKey(k)) {
            addBucket(k, '${cursor.day} ${monthNames[cursor.month - 1]}');
          }
          cursor = cursor.add(const Duration(days: 7));
        }
      case CardChartGranularity.month:
        var cursor = DateTime(start.year, start.month);
        final last = DateTime(end.year, end.month);
        while (!cursor.isAfter(last)) {
          final label = start.year == end.year
              ? monthNames[cursor.month - 1]
              : '${monthNames[cursor.month - 1]} ${cursor.year % 100}';
          addBucket(_bucketKey(cursor), label);
          cursor = DateTime(cursor.year, cursor.month + 1);
        }
      case CardChartGranularity.year:
        for (var y = start.year; y <= end.year; y++) {
          addBucket('$y', '$y');
        }
    }
  }

  DateTime _weekStart(DateTime d) =>
      d.subtract(Duration(days: d.weekday - DateTime.monday));

  String _bucketKey(DateTime d) {
    return switch (_granularity) {
      CardChartGranularity.day => isoDay(d),
      CardChartGranularity.week => isoDay(_weekStart(d)),
      CardChartGranularity.month =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}',
      CardChartGranularity.year => '${d.year}',
    };
  }
}

class _BarBucket {
  const _BarBucket({
    required this.label,
    required this.usdCents,
    required this.nioCents,
    required this.singleCents,
  });

  final String label;
  final int usdCents;
  final int nioCents;
  final int singleCents;
}

class _ChartSeriesResult {
  const _ChartSeriesResult({
    required this.buckets,
    required this.totalUsdCents,
    required this.totalNioCents,
    required this.totalSingleCents,
    required this.usedGeneralRate,
    required this.omittedForeign,
  });

  final List<_BarBucket> buckets;
  final int totalUsdCents;
  final int totalNioCents;
  final int totalSingleCents;
  final bool usedGeneralRate;
  final bool omittedForeign;
}

class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _ResponsiveBarCanvas extends StatefulWidget {
  const _ResponsiveBarCanvas({
    required this.buckets,
    required this.currencyMode,
    required this.usdColor,
    required this.nioColor,
    required this.tier,
    this.forcedHeight,
  });

  final List<_BarBucket> buckets;
  final String currencyMode;
  final Color usdColor;
  final Color nioColor;
  final _ViewportTier tier;
  final double? forcedHeight;

  @override
  State<_ResponsiveBarCanvas> createState() => _ResponsiveBarCanvasState();
}

class _ResponsiveBarCanvasState extends State<_ResponsiveBarCanvas> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBoth = widget.currencyMode == 'BOTH';
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = widget.forcedHeight ??
            switch (widget.tier) {
              _ViewportTier.mobile => 320.0,
              _ViewportTier.tablet => 370.0,
              _ViewportTier.desktop => 430.0,
            };
        // Ancho suficiente por columna para que los 2 decimales quepan completos sin cortarse
        final minSlotWidth = switch (widget.tier) {
          _ViewportTier.mobile => isBoth ? 148.0 : 84.0,
          _ViewportTier.tablet => isBoth ? 160.0 : 92.0,
          _ViewportTier.desktop => isBoth ? 172.0 : 100.0,
        };
        final maxBarWidth = switch (widget.tier) {
          _ViewportTier.mobile => isBoth ? 28.0 : 38.0,
          _ViewportTier.tablet => isBoth ? 34.0 : 48.0,
          _ViewportTier.desktop => isBoth ? 40.0 : 56.0,
        };

        final sideAxes = isBoth ? 164.0 : 92.0;
        final desiredWidth = math.max(
          constraints.maxWidth,
          sideAxes + widget.buckets.length * minSlotWidth,
        );
        final canScroll = desiredWidth > constraints.maxWidth + 1;

        final canvasWidget = SizedBox(
          width: desiredWidth,
          height: chartHeight,
          child: CustomPaint(
            painter: _GranularBarsPainter(
              buckets: widget.buckets,
              currencyMode: widget.currencyMode,
              usdColor: widget.usdColor,
              nioColor: widget.nioColor,
              maxBarWidth: maxBarWidth,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
              gridColor: Theme.of(context).dividerColor,
            ),
          ),
        );

        if (!canScroll) return canvasWidget;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Desliza o usa las flechas para ver más',
                  style: TextStyle(color: appMuted, fontSize: 11.5),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Desplazar a la izquierda',
                  onPressed: () => _scrollBy(-constraints.maxWidth * 0.7),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Desplazar a la derecha',
                  onPressed: () => _scrollBy(constraints.maxWidth * 0.7),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ScrollConfiguration(
              behavior: const _DragScrollBehavior(),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: canvasWidget,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GranularBarsPainter extends CustomPainter {
  const _GranularBarsPainter({
    required this.buckets,
    required this.currencyMode,
    required this.usdColor,
    required this.nioColor,
    required this.maxBarWidth,
    required this.textColor,
    required this.gridColor,
  });

  final List<_BarBucket> buckets;
  final String currencyMode;
  final Color usdColor;
  final Color nioColor;
  final double maxBarWidth;
  final Color textColor;
  final Color gridColor;

  void _drawText(
      Canvas canvas,
      String text,
      Offset offset,
      TextStyle style, {
        double? maxWidth,
      }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    final isBoth = currencyMode == 'BOTH';
    const left = 78.0;
    final right = isBoth ? 82.0 : 16.0;
    const top = 30.0;
    const bottom = 38.0;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);

    final maxUsd = buckets.fold<int>(1, (m, b) => math.max(m, b.usdCents));
    final maxNio = buckets.fold<int>(1, (m, b) => math.max(m, b.nioCents));
    final maxSingle = buckets.fold<int>(1, (m, b) => math.max(m, b.singleCents));

    final gridPaint = Paint()
      ..color = gridColor.withAlpha(115)
      ..strokeWidth = 1;
    final axisStyle = TextStyle(
      color: textColor,
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
    );

    const gridSteps = 4;
    for (var i = 0; i <= gridSteps; i++) {
      final y = top + chartHeight * i / gridSteps;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);

      if (isBoth) {
        final usdVal = (maxUsd * (gridSteps - i) / gridSteps).round();
        _drawText(
          canvas,
          _formatTwoDecimals(usdVal),
          Offset(0, y - 7),
          axisStyle.copyWith(color: usdColor),
          maxWidth: left - 6,
        );
        final nioVal = (maxNio * (gridSteps - i) / gridSteps).round();
        _drawText(
          canvas,
          _formatTwoDecimals(nioVal),
          Offset(size.width - right + 6, y - 7),
          axisStyle.copyWith(color: nioColor),
          maxWidth: right - 6,
        );
      } else {
        final val = (maxSingle * (gridSteps - i) / gridSteps).round();
        _drawText(
          canvas,
          _formatTwoDecimals(val),
          Offset(0, y - 7),
          axisStyle,
          maxWidth: left - 6,
        );
      }
    }

    final slot = chartWidth / buckets.length;
    final valueStyle = TextStyle(
      color: textColor,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
    );

    if (isBoth) {
      const gap = 10.0;
      final barWidth = math.min(maxBarWidth, (slot * 0.72 - gap) / 2);
      final groupWidth = barWidth * 2 + gap;
      final usdPaint = Paint()..color = usdColor.withAlpha(220);
      final nioPaint = Paint()..color = nioColor.withAlpha(220);

      for (var i = 0; i < buckets.length; i++) {
        final bucket = buckets[i];
        final groupStart = left + slot * i + (slot - groupWidth) / 2;

        if (bucket.usdCents > 0) {
          final h = chartHeight * bucket.usdCents / maxUsd;
          final x = groupStart;
          final y = top + chartHeight - h;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, barWidth, math.max(4.0, h)),
              const Radius.circular(5),
            ),
            usdPaint,
          );
          final label = _formatTwoDecimals(bucket.usdCents);
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: valueStyle.copyWith(color: usdColor),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          tp.paint(
            canvas,
            Offset(
              x + (barWidth - tp.width) / 2,
              math.max(2.0, y - 16),
            ),
          );
        }

        if (bucket.nioCents > 0) {
          final h = chartHeight * bucket.nioCents / maxNio;
          final x = groupStart + barWidth + gap;
          final y = top + chartHeight - h;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, barWidth, math.max(4.0, h)),
              const Radius.circular(5),
            ),
            nioPaint,
          );
          final label = _formatTwoDecimals(bucket.nioCents);
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: valueStyle.copyWith(color: nioColor),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          tp.paint(
            canvas,
            Offset(
              x + (barWidth - tp.width) / 2,
              math.max(2.0, y - 16),
            ),
          );
        }

        final labelPainter = TextPainter(
          text: TextSpan(text: bucket.label, style: axisStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(
            left + slot * i + (slot - labelPainter.width) / 2,
            size.height - bottom + 10,
          ),
        );
      }
    } else {
      final barWidth = math.min(maxBarWidth, slot * 0.62);
      final activeColor = currencyMode == 'USD' ? usdColor : nioColor;
      final barPaint = Paint()..color = activeColor.withAlpha(215);

      for (var i = 0; i < buckets.length; i++) {
        final bucket = buckets[i];
        final barHeight = chartHeight * bucket.singleCents / maxSingle;
        final x = left + slot * i + (slot - barWidth) / 2;
        final y = top + chartHeight - barHeight;

        if (bucket.singleCents > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, barWidth, math.max(4.0, barHeight)),
              const Radius.circular(6),
            ),
            barPaint,
          );

          final valText = _formatTwoDecimals(bucket.singleCents);
          final valPainter = TextPainter(
            text: TextSpan(
              text: valText,
              style: valueStyle.copyWith(color: activeColor),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          valPainter.paint(
            canvas,
            Offset(
              left + slot * i + (slot - valPainter.width) / 2,
              math.max(2.0, y - 16),
            ),
          );
        }

        final labelPainter = TextPainter(
          text: TextSpan(text: bucket.label, style: axisStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(
            left + slot * i + (slot - labelPainter.width) / 2,
            size.height - bottom + 10,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GranularBarsPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
          oldDelegate.currencyMode != currencyMode ||
          oldDelegate.usdColor != usdColor ||
          oldDelegate.nioColor != nioColor ||
          oldDelegate.maxBarWidth != maxBarWidth ||
          oldDelegate.textColor != textColor ||
          oldDelegate.gridColor != gridColor;
}