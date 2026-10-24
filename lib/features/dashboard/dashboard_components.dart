import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

const _blue = Color(0xFF2563EB);
const _green = Color(0xFF087F5B);
const _red = Color(0xFFB42318);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({super.key, required this.data, required this.currency});
  final DashboardOverview data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = data.currencies[currency]!;
    String delta(int amount) =>
        '${amount > 0 ? '+' : ''}${dashboardMoney(amount, currency)} vs mes anterior';
    final cards = [
      _Metric(title: 'Saldo registrado', amount: dashboardMoney(c.cash, currency),
          footer: '${c.activeAccounts} cuentas activas', icon: Icons.account_balance_wallet_outlined, hero: true),
      _Metric(title: 'Ingresos del mes', amount: dashboardMoney(c.income, currency),
          footer: delta(c.income - c.previousIncome), icon: Icons.south_west,
          footerColor: c.income >= c.previousIncome ? _green : _red),
      _Metric(title: 'Gastos del mes', amount: dashboardMoney(c.expense, currency),
          footer: delta(c.expense - c.previousExpense), icon: Icons.north_east,
          footerColor: c.expense <= c.previousExpense ? _green : _red),
      _Metric(title: 'Ingresos − gastos', amount: dashboardMoney(c.net, currency),
          footer: delta(c.net - c.previousNet), icon: Icons.insights_outlined,
          footerColor: c.net >= c.previousNet ? _green : _red),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 1050 ? 4 : box.maxWidth >= 360 ? 2 : 1;
      final width = (box.maxWidth - 14 * (columns - 1)) / columns;
      return Wrap(spacing: 14, runSpacing: 14,
          children: cards.map((card) => SizedBox(width: width, child: card)).toList());
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.amount, required this.footer,
    required this.icon, this.hero = false, this.footerColor});
  final String title, amount, footer;
  final IconData icon;
  final bool hero;
  final Color? footerColor;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 172),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: hero ? null : Colors.white,
      gradient: hero ? const LinearGradient(
        colors: [Color(0xFF153E9E), Color(0xFF2563EB)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ) : null,
      borderRadius: BorderRadius.circular(22),
      border: hero ? null : Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(title, style: TextStyle(
            color: hero ? Colors.white.withAlpha(220) : _muted, fontSize: 13))),
        Icon(icon, size: 21, color: hero ? Colors.white : _blue),
      ]),
      const SizedBox(height: 20),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(amount, style: TextStyle(fontSize: 29,
              fontWeight: FontWeight.w700, letterSpacing: -0.8,
              color: hero ? Colors.white : const Color(0xFF172033)))),
      const SizedBox(height: 12),
      Text(footer, style: TextStyle(fontSize: 12,
          color: hero ? Colors.white.withAlpha(220) : footerColor ?? _muted)),
    ]),
  );
}

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.onOpen});
  final ValueChanged<DashboardTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    const items = [
      (DashboardTarget.accounts, Icons.account_balance_wallet_outlined, 'Cuentas'),
      (DashboardTarget.transactions, Icons.swap_horiz, 'Movimientos'),
      (DashboardTarget.budgets, Icons.donut_large_outlined, 'Presupuestos'),
      (DashboardTarget.debts, Icons.payments_outlined, 'Deudas'),
      (DashboardTarget.cards, Icons.credit_card_outlined, 'Tarjetas'),
      (DashboardTarget.reports, Icons.bar_chart, 'Reportes'),
      (DashboardTarget.categories, Icons.category_outlined, 'Categorías'),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => ActionChip(
      avatar: Icon(item.$2, color: _blue, size: 19),
      label: Text(item.$3),
      backgroundColor: Colors.white,
      side: const BorderSide(color: _border),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onPressed: () => onOpen(item.$1),
    )).toList());
  }
}

class DashboardPanels extends StatelessWidget {
  const DashboardPanels({super.key, required this.data, required this.currency,
    required this.onOpen, required this.onEvent});
  final DashboardOverview data;
  final String currency;
  final ValueChanged<DashboardTarget> onOpen;
  final ValueChanged<DashboardEvent> onEvent;
  DashboardCurrency get c => data.currencies[currency]!;
  String money(int? value) => dashboardMoney(value, currency);

  Widget amountRow(String label, int? amount, {Color? color, bool bold = false}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(money(amount), textAlign: TextAlign.right,
            style: TextStyle(color: color, fontWeight: bold ? FontWeight.w700 : null))),
      ]));

  Widget categoriesPanel() {
    final entries = c.categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maximum = entries.isEmpty || entries.first.value <= 0 ? 1 : entries.first.value;
    const palette = [_blue, _green, Color(0xFF7C3AED), Color(0xFFB45309), Color(0xFFBE185D)];
    return _Panel(title: 'Gasto neto por categoría', icon: Icons.bar_chart,
      action: 'Ver reporte', onAction: () => onOpen(DashboardTarget.reports),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (entries.isEmpty) const Text('Todavía no hay gastos en este mes y moneda.'),
        ...entries.take(5).toList().asMap().entries.map((item) {
          final entry = item.value;
          final name = entry.key == 'none' ? 'Sin categoría'
              : data.categoryNames[entry.key] ?? 'Categoría no disponible';
          return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(children: [
            Row(children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Text(money(entry.value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: (entry.value / maximum).clamp(0.0, 1.0).toDouble(),
              minHeight: 8, color: palette[item.key % palette.length],
              backgroundColor: const Color(0xFFF1F5F9),
            )),
          ]));
        }),
        if (entries.any((e) => e.value < 0))
          const Text('Las devoluciones pueden dejar categorías con gasto neto negativo.',
              style: TextStyle(color: _muted, fontSize: 12)),
      ]),
    );
  }

  Widget budgetsPanel() {
    final budgets = data.budgets.where((b) => b['currency'] == currency).toList();
    double score(Map<String, dynamic> b) =>
        (b['spent_cents'] as int) / ((b['limit_cents'] as int) > 0 ? b['limit_cents'] as int : 1);
    budgets.sort((a, b) => score(b).compareTo(score(a)));
    return _Panel(title: 'Presupuestos del mes', icon: Icons.donut_large_outlined,
      action: 'Administrar', onAction: () => onOpen(DashboardTarget.budgets),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (budgets.isEmpty) const Text('No tienes presupuestos para este mes y moneda.'),
        if (c.exceededBudgets > 0)
          Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text('${c.exceededBudgets} presupuestos excedidos',
                  style: const TextStyle(color: _red, fontWeight: FontWeight.w600))),
        ...budgets.take(4).map((b) {
          final spent = b['spent_cents'] as int, limit = b['limit_cents'] as int;
          final exceeded = spent > limit;
          final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0).toDouble()
              : spent > 0 ? 1.0 : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(b['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${money(spent)} de ${money(limit)}',
                style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: progress, minHeight: 7, color: exceeded ? _red : _green,
              backgroundColor: const Color(0xFFF1F5F9),
            )),
            const SizedBox(height: 4),
            Text(exceeded ? 'Excedido: ${money(spent - limit)}' : 'Disponible: ${money(limit - spent)}',
                style: TextStyle(fontSize: 12, color: exceeded ? _red : _muted)),
          ],
          ));
        }),
      ]),
    );
  }

  Widget debtsPanel() => _Panel(
    title: 'Deudas y compromisos', icon: Icons.payments_outlined,
    action: 'Ver deudas', onAction: () => onOpen(DashboardTarget.debts),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      amountRow('Capital de préstamos', c.loans),
      amountRow('Deuda de tarjetas', c.cardKnown ? c.cardDebt : null),
      const Divider(),
      amountRow('Total registrado', c.liabilities, bold: true),
      if (c.cardKnown && c.cardCredit > 0) amountRow('Saldo a favor en tarjetas', c.cardCredit, color: _green),
      amountRow('Disponible en tarjetas activas', c.cardKnown ? c.cardAvailable : null),
      if (!c.cardKnown) const Text('Hay ajustes de tarjeta que requieren revisión.',
          style: TextStyle(color: _red, fontSize: 12)),
      const Divider(height: 24),
      amountRow('Saldo menos deuda registrada', c.position, bold: true),
      const Text('Considera cuentas activas y saldos a favor de tarjetas. No incluye bienes ni intereses futuros.',
          style: TextStyle(color: _muted, fontSize: 12)),
      if (c.overdueCount > 0 || c.todayCount > 0) ...[
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _red.withAlpha(12), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Vencimientos al día de hoy', style: TextStyle(fontWeight: FontWeight.w600)),
            if (c.overdueCount > 0)
              Text('${c.overdueCount} deudas con capital vencido: ${money(c.overdue)}',
                  style: const TextStyle(color: _red)),
            if (c.todayCount > 0)
              Text('${c.todayCount} deudas vencen hoy: ${money(c.dueToday)}'),
          ]),
        ),
      ],
    ]),
  );

  Widget accountsPanel() {
    final accounts = data.accounts.where((a) => a['currency'] == currency).take(5);
    const types = {'cash': 'Efectivo', 'savings': 'Ahorro', 'checking': 'Cuenta corriente',
      'wallet': 'Billetera digital', 'investment': 'Inversión', 'other': 'Otra cuenta'};
    return _Panel(title: 'Tus cuentas activas', icon: Icons.account_balance_wallet_outlined,
      action: 'Ver todas', onAction: () => onOpen(DashboardTarget.accounts),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (accounts.isEmpty) const Text('Crea una cuenta para consultar su saldo aquí.'),
        ...accounts.map((a) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _blue.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: Icon(a['account_type'] == 'cash' ? Icons.payments_outlined : Icons.account_balance_outlined,
                    color: _blue, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(types[a['account_type']] ?? 'Cuenta',
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            Flexible(child: Text(money(a['balance_cents'] as int),
                textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        )),
      ]),
    );
  }

  Widget recentPanel() {
    final events = data.events.where((e) => e.currency == currency).take(6);
    return _Panel(title: 'Actividad reciente del mes', icon: Icons.history,
      action: 'Movimientos', onAction: () => onOpen(DashboardTarget.transactions),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (events.isEmpty) const Text('No hay movimientos en este mes y moneda.'),
        ...events.map((e) {
          final color = e.flow > 0 ? _green : e.flow < 0 ? _red : _blue;
          final icon = e.target == DashboardTarget.cards ? Icons.credit_card_outlined
              : e.target == DashboardTarget.debts ? Icons.payments_outlined
              : e.flow > 0 ? Icons.south_west : e.flow < 0 ? Icons.north_east : Icons.swap_horiz;
          return InkWell(onTap: () => onEvent(e), borderRadius: BorderRadius.circular(12),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
              CircleAvatar(backgroundColor: color.withAlpha(18), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')} · ${e.detail}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
              const SizedBox(width: 12),
              Flexible(flex: 4, child: Text(
                  '${e.flow > 0 ? '+' : e.flow < 0 ? '−' : ''}${money(e.cents)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700))),
            ])),
          );
        }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 900) return Column(children: [
        categoriesPanel(), const SizedBox(height: 16),
        budgetsPanel(), const SizedBox(height: 16),
        debtsPanel(), const SizedBox(height: 16), accountsPanel(),
      ]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 7, child: Column(children: [
          categoriesPanel(), const SizedBox(height: 16), accountsPanel(),
        ])),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: Column(children: [
          debtsPanel(), const SizedBox(height: 16), budgetsPanel(),
        ])),
      ]);
    }),
    const SizedBox(height: 16),
    recentPanel(),
  ]);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.action,
    required this.onAction, required this.child});
  final String title, action;
  final IconData icon;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(icon, color: _blue, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        TextButton(onPressed: onAction, child: Text(action)),
      ]),
      const SizedBox(height: 16),
      child,
    ],
    )),
  );
}