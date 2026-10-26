import 'package:flutter/material.dart';
import '../../widgets/category_style.dart';
import 'dashboard_overview.dart';

const _blue = Color(0xFF2563EB);
const _green = Color(0xFF087F5B);
const _red = Color(0xFFB42318);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({
    super.key,
    required this.data,
    required this.currency,
  });
  final DashboardOverview data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = data.currencies[currency]!;
    String delta(int amount) =>
        '${amount > 0 ? '+' : ''}${dashboardMoney(amount, currency)} vs período anterior';
    final cards = [
      _Metric(
        title: 'Saldo registrado',
        amount: dashboardMoney(c.cash, currency),
        footer: '${c.activeAccounts} cuentas activas',
        icon: Icons.account_balance_wallet_outlined,
        hero: true,
      ),
      _Metric(
        title: 'Ingresos del período',
        amount: dashboardMoney(c.income, currency),
        footer: delta(c.income - c.previousIncome),
        icon: Icons.south_west,
        footerColor: c.income >= c.previousIncome ? _green : _red,
      ),
      _Metric(
        title: 'Gastos del período',
        amount: dashboardMoney(c.expense, currency),
        footer: delta(c.expense - c.previousExpense),
        icon: Icons.north_east,
        footerColor: c.expense <= c.previousExpense ? _green : _red,
      ),
      _Metric(
        title: 'Ingresos − gastos',
        amount: dashboardMoney(c.net, currency),
        footer: delta(c.net - c.previousNet),
        icon: Icons.insights_outlined,
        footerColor: c.net >= c.previousNet ? _green : _red,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = box.maxWidth >= 1050
            ? 4
            : box.maxWidth >= 350 * scale
            ? 2
            : 1;
        final width = (box.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.amount,
    required this.footer,
    required this.icon,
    this.hero = false,
    this.footerColor,
  });
  final String title, amount, footer;
  final IconData icon;
  final bool hero;
  final Color? footerColor;

  @override
  Widget build(BuildContext context) {
    final accent = footerColor ?? _blue;
    return Container(
      constraints: const BoxConstraints(minHeight: 166),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hero ? null : Colors.white,
        gradient: hero
            ? const LinearGradient(
                colors: [Color(0xFF153E9E), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: hero ? null : Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: hero ? Colors.white.withAlpha(225) : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: hero
                      ? Colors.white.withAlpha(25)
                      : accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: hero ? Colors.white : accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: hero ? Colors.white : const Color(0xFF172033),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: hero ? Colors.white.withAlpha(22) : accent.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                footer,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: hero ? Colors.white : accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.onOpen});
  final ValueChanged<DashboardTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        DashboardTarget.accounts,
        Icons.account_balance_wallet_outlined,
        'Cuentas',
      ),
      (DashboardTarget.transactions, Icons.swap_horiz, 'Movimientos'),
      (DashboardTarget.budgets, Icons.donut_large_outlined, 'Presupuestos'),
      (DashboardTarget.debts, Icons.payments_outlined, 'Deudas'),
      (DashboardTarget.cards, Icons.credit_card_outlined, 'Tarjetas'),
      (DashboardTarget.reports, Icons.bar_chart, 'Reportes'),
      (DashboardTarget.categories, Icons.category_outlined, 'Categorías'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ActionChip(
              avatar: Icon(item.$2, color: _blue, size: 19),
              label: Text(item.$3),
              backgroundColor: Colors.white,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              onPressed: () => onOpen(item.$1),
            ),
          )
          .toList(),
    );
  }
}

class DashboardPanels extends StatelessWidget {
  const DashboardPanels({
    super.key,
    required this.data,
    required this.currency,
    required this.onOpen,
    required this.onEvent,
  });
  final DashboardOverview data;
  final String currency;
  final ValueChanged<DashboardTarget> onOpen;
  final ValueChanged<DashboardEvent> onEvent;
  DashboardCurrency get c => data.currencies[currency]!;
  String money(int? value) => dashboardMoney(value, currency);

  Widget amountRow(
    String label,
    int? amount, {
    Color? color,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: LayoutBuilder(
      builder: (context, box) {
        final caption = Text(label, style: const TextStyle(fontSize: 13));
        final value = Text(
          money(amount),
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        );
        if (box.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 17.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [caption, const SizedBox(height: 4), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: caption),
            const SizedBox(width: 12),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        );
      },
    ),
  );

  Widget categoriesPanel() {
    final entries = c.categories.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
      });
    final positiveTotal = entries.fold<int>(
      0,
      (sum, entry) => sum + (entry.value > 0 ? entry.value : 0),
    );

    return _Panel(
      title: 'Gasto neto por categoría',
      icon: Icons.bar_chart_rounded,
      action: 'Ver reporte',
      onAction: () => onOpen(DashboardTarget.reports),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Todavía no hay gastos en este rango y moneda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            ),
          ...entries.take(5).map((entry) {
            final style = data.categoryStyles[entry.key];
            final uncategorized = entry.key == 'none';
            final color = uncategorized
                ? _muted
                : categoryColor(style?['color']);
            final icon = uncategorized
                ? Icons.help_outline_rounded
                : categoryIcon(style?['icon']);
            final name = uncategorized
                ? 'Sin categoría'
                : data.categoryNames[entry.key] ?? 'Categoría no disponible';
            final ratio = entry.value > 0 && positiveTotal > 0
                ? entry.value / positiveTotal
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              money(entry.value),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: entry.value < 0
                                    ? _green
                                    : const Color(0xFF172033),
                              ),
                            ),
                            Text(
                              entry.value < 0
                                  ? 'Devoluciones netas'
                                  : '${(ratio * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: entry.value < 0 ? _green : _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0).toDouble(),
                            minHeight: 7,
                            color: color,
                            backgroundColor: const Color(0xFFF1F5F9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (entries.isNotEmpty)
            const Text(
              'Porcentajes entre categorías con gasto neto positivo.',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          if (entries.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${entries.length - 5} categorías más en el reporte.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ),
          if (entries.any((entry) => entry.value < 0))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Hay categorías con devoluciones netas.',
                style: TextStyle(color: _green, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget budgetsPanel() {
    final budgets = data.budgets
        .where((b) => b['currency'] == currency)
        .toList();
    double score(Map<String, dynamic> b) =>
        (b['spent_cents'] as int) /
        ((b['limit_cents'] as int) > 0 ? b['limit_cents'] as int : 1);
    budgets.sort((a, b) => score(b).compareTo(score(a)));

    return _Panel(
      title: 'Presupuestos del período',
      icon: Icons.donut_large_outlined,
      action: 'Administrar',
      onAction: () => onOpen(DashboardTarget.budgets),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Límites mensuales completos, sin prorratear. El gasto incluye solo las fechas seleccionadas.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          if (budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.savings_outlined, color: _muted, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'Sin presupuestos para este rango y moneda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          if (c.exceededBudgets > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${c.exceededBudgets} presupuestos excedidos',
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...budgets.take(4).map((b) {
            final spent = b['spent_cents'] as int;
            final limit = b['limit_cents'] as int;
            final exceeded = spent > limit;
            final ratio = limit > 0 ? spent / limit : 0.0;
            final nearLimit = !exceeded && limit > 0 && ratio >= 0.8;
            final color = exceeded
                ? _red
                : nearLimit
                ? const Color(0xFFB45309)
                : _green;
            final style = data.categoryStyles[b['category_id'].toString()];
            final categoryAccent = categoryColor(style?['color']);
            final status = exceeded
                ? 'Excedido'
                : nearLimit
                ? 'Cerca del límite'
                : spent < 0
                ? 'Devoluciones netas'
                : limit == 0
                ? 'Sin margen asignado'
                : 'Dentro del límite';
            final percentage = limit > 0
                ? '${(ratio * 100).toStringAsFixed(0)}%'
                : '—';
            final progress = limit > 0
                ? ratio.clamp(0.0, 1.0).toDouble()
                : spent > 0
                ? 1.0
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: exceeded ? color.withAlpha(65) : _border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: categoryAccent.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            categoryIcon(style?['icon']),
                            color: categoryAccent,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b['name'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          percentage,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${money(spent)} de ${money(limit)}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: color,
                        backgroundColor: _border,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            exceeded
                                ? 'Exceso: ${money(spent - limit)}'
                                : 'Disponible: ${money(limit - spent)}',
                            style: TextStyle(fontSize: 11, color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (budgets.length > 4)
            Text(
              '${budgets.length - 4} presupuestos más en Administrar.',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget debtsPanel() => _Panel(
    title: 'Deudas y compromisos',
    icon: Icons.payments_outlined,
    action: 'Ver deudas',
    onAction: () => onOpen(DashboardTarget.debts),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        amountRow('Capital de préstamos', c.loans),
        amountRow('Deuda de tarjetas', c.cardKnown ? c.cardDebt : null),
        const Divider(),
        amountRow('Total registrado', c.liabilities, bold: true),
        if (c.cardKnown && c.cardCredit > 0)
          amountRow('Saldo a favor en tarjetas', c.cardCredit, color: _green),
        amountRow(
          'Disponible en tarjetas activas',
          c.cardKnown ? c.cardAvailable : null,
        ),
        if (!c.cardKnown)
          const Text(
            'Hay ajustes de tarjeta que requieren revisión.',
            style: TextStyle(color: _red, fontSize: 12),
          ),
        const Divider(height: 24),
        amountRow('Saldo menos deuda registrada', c.position, bold: true),
        const Text(
          'Considera cuentas activas y saldos a favor de tarjetas. '
          'No incluye bienes ni intereses futuros.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        if (c.overdueCount > 0 || c.todayCount > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red.withAlpha(12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Vencimientos al día de hoy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (c.overdueCount > 0)
                  Text(
                    '${c.overdueCount} deudas con capital vencido: ${money(c.overdue)}',
                    style: const TextStyle(color: _red),
                  ),
                if (c.todayCount > 0)
                  Text(
                    '${c.todayCount} deudas vencen hoy: ${money(c.dueToday)}',
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget accountsPanel() {
    final accounts = data.accounts
        .where((a) => a['currency'] == currency)
        .take(5);
    const types = {
      'cash': 'Efectivo',
      'savings': 'Ahorro',
      'checking': 'Cuenta corriente',
      'wallet': 'Billetera digital',
      'investment': 'Inversión',
      'other': 'Otra cuenta',
    };
    return _Panel(
      title: 'Tus cuentas activas',
      icon: Icons.account_balance_wallet_outlined,
      action: 'Ver todas',
      onAction: () => onOpen(DashboardTarget.accounts),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accounts.isEmpty)
            const Text(
              'No hay cuentas activas en esta moneda.',
              style: TextStyle(color: _muted),
            ),
          ...accounts.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _blue.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      a['account_type'] == 'cash'
                          ? Icons.payments_outlined
                          : Icons.account_balance_outlined,
                      color: _blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['name'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          types[a['account_type']] ?? 'Cuenta',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      money(a['balance_cents'] as int),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget recentPanel() {
    final events = data.events
        .where((e) => e.currency == currency)
        .take(6)
        .toList();
    return _Panel(
      title: 'Actividad reciente del período',
      icon: Icons.history_rounded,
      action: 'Ver movimientos',
      onAction: () => onOpen(DashboardTarget.transactions),
      child: events.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 36, color: _muted),
                  SizedBox(height: 10),
                  Text(
                    'Sin actividad para este rango y moneda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            )
          : Column(
              children: List.generate(events.length, (index) {
                final e = events[index];
                final color = e.flow > 0
                    ? _green
                    : e.flow < 0
                    ? _red
                    : _blue;
                final fallbackIcon = e.target == DashboardTarget.cards
                    ? Icons.credit_card_outlined
                    : e.target == DashboardTarget.debts
                    ? Icons.payments_outlined
                    : e.flow > 0
                    ? Icons.south_west_rounded
                    : e.flow < 0
                    ? Icons.north_east_rounded
                    : Icons.swap_horiz_rounded;
                final style = data.categoryStyles[e.categoryId];
                final icon = style == null
                    ? fallbackIcon
                    : categoryIcon(style['icon']);
                final visualColor = style == null
                    ? color
                    : categoryColor(style['color'], income: e.flow > 0);
                final amount = Text(
                  '${e.flow > 0
                      ? '+'
                      : e.flow < 0
                      ? '−'
                      : ''}${money(e.cents)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                );

                return Column(
                  children: [
                    InkWell(
                      onTap: () => onEvent(e),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final compact = box.maxWidth < 480;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: visualColor.withAlpha(16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: visualColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${e.date.day.toString().padLeft(2, '0')}/'
                                        '${e.date.month.toString().padLeft(2, '0')} · ${e.detail}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (style != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            style['name'].toString(),
                                            style: TextStyle(
                                              color: visualColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (compact) ...[
                                        const SizedBox(height: 8),
                                        amount,
                                      ],
                                    ],
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 16),
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: amount,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _muted,
                                  size: 18,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (index < events.length - 1)
                      const Divider(height: 1, color: _border),
                  ],
                );
              }),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 900) {
            return Column(
              children: [
                categoriesPanel(),
                const SizedBox(height: 16),
                budgetsPanel(),
                const SizedBox(height: 16),
                debtsPanel(),
                const SizedBox(height: 16),
                accountsPanel(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    categoriesPanel(),
                    const SizedBox(height: 16),
                    accountsPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    debtsPanel(),
                    const SizedBox(height: 16),
                    budgetsPanel(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      recentPanel(),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.action,
    required this.onAction,
    required this.child,
  });
  final String title, action;
  final IconData icon;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: _border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final heading = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: _blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
              final button = box.maxWidth < 360
                  ? IconButton(
                      tooltip: action,
                      onPressed: onAction,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 21),
                    )
                  : TextButton(onPressed: onAction, child: Text(action));
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 8),
                  button,
                ],
              );
            },
          ),
          const Divider(height: 22, color: _border),
          child,
        ],
      ),
    ),
  );
}
