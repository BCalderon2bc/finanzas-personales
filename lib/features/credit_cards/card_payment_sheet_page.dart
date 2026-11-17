import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../data/card_statement_repository.dart';
import '../../data/payment_agenda_labels.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import 'credit_card_statements_page.dart';
import 'credit_card_face.dart';
import 'register_statement_payment.dart';

enum _Period { all, overdue, nextWeek }

enum _PaymentAmount { minimum, total, custom }

typedef _Sheet = ({
  String userId,
  List<Map<String, dynamic>> cards,
  CardStatementData statements,
});

class CardPaymentSheetPage extends StatefulWidget {
  const CardPaymentSheetPage({super.key});

  @override
  State<CardPaymentSheetPage> createState() => _CardPaymentSheetPageState();
}

class _CardPaymentSheetPageState extends State<CardPaymentSheetPage> {
  static const _currencies = ['NIO', 'USD'];
  late Future<_Sheet> _sheet = _load();
  _Period _period = _Period.all;
  bool _paying = false;

  Future<_Sheet> _load() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Debes iniciar sesión.');
    final (cards, statements) = await (
      statementRows(
        'credit_cards',
        'id,name,currency,is_active,card_reference,network,card_tier,card_product,financial_institutions(name)',
        userId,
      ),
      loadCardStatements(userId),
    ).wait;
    if (supabase.auth.currentUser?.id != userId) {
      throw StateError('La sesión cambió.');
    }
    return (userId: userId, cards: cards, statements: statements);
  }

  void _refresh() => setState(() => _sheet = _load());

  Future<void> _pay(
    String userId,
    StatementProgress cut,
    _PaymentAmount amount,
  ) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final cents = switch (amount) {
        _PaymentAmount.minimum => cut.minimumRemaining,
        _PaymentAmount.total => cut.remaining,
        _PaymentAmount.custom => null,
      };
      final saved = await registerStatementPayment(
        context,
        userId,
        cut.statement,
        initialAmountCents: cents,
      );
      if (mounted && saved) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago registrado.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar el pago: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  DateTime? _due(StatementProgress cut) =>
      statementDate(cut.statement['due_date']);

  bool _includes(StatementProgress cut, DateTime today) {
    if (_period == _Period.all) return true;
    final due = _due(cut);
    if (cut.settled || due == null) return false;
    final days = daysUntil(due, today);
    return _period == _Period.overdue ? days < 0 : days >= 0 && days <= 7;
  }

  int _dateOrder(List<StatementProgress> cuts) =>
      cuts.fold(8640000000000000, (first, cut) {
        final due = cut.settled ? null : _due(cut)?.millisecondsSinceEpoch;
        return due != null && due < first ? due : first;
      });

  String _amount(int? cents, String currency) =>
      cents == null ? 'Sin dato' : formatMoneyCents(cents, currency);

  Widget _cutRow(_Sheet sheet, String currency, StatementProgress cut) {
    final due = _due(cut);
    final overdue =
        !cut.settled && due != null && daysUntil(due, DateTime.now()) < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          cut.settled
              ? 'Corte cubierto'
              : due == null
              ? 'Fecha límite sin registrar'
              : '${overdue ? 'Venció el' : 'Vence el'} ${shortStatementDate(cut.statement['due_date'])}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: overdue ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        AdaptiveColumns(
          minColumnWidth: 112,
          children: [
            _amountLabel(
              'Mínimo pendiente',
              _amount(cut.settled ? 0 : cut.minimumRemaining, currency),
            ),
            _amountLabel('Saldo del corte', _amount(cut.remaining, currency)),
          ],
        ),
        if ((cut.remaining ?? 0) > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PopupMenuButton<_PaymentAmount>(
              enabled: !_paying,
              tooltip: 'Pagar en ${currency == 'NIO' ? 'córdobas' : 'dólares'}',
              onSelected: (amount) => _pay(sheet.userId, cut, amount),
              itemBuilder: (_) => [
                if ((cut.minimumRemaining ?? 0) > 0)
                  const PopupMenuItem(
                    value: _PaymentAmount.minimum,
                    child: Text('Pagar mínimo'),
                  ),
                const PopupMenuItem(
                  value: _PaymentAmount.total,
                  child: Text('Pagar total del corte'),
                ),
                const PopupMenuItem(
                  value: _PaymentAmount.custom,
                  child: Text('Otro monto'),
                ),
              ],
              child: Chip(
                avatar: const Icon(Icons.payments_outlined, size: 17),
                label: const Text('Pagar'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _amountLabel(String label, String amount) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          amount,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _moneyPanel(String title, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  Widget _content(_Sheet sheet) {
    final today = DateTime.now();
    final rows =
        [
          for (final card in sheet.cards)
            (
              card: card,
              cuts: sheet.statements
                  .currentFor('${card['id']}')
                  .map(sheet.statements.progress)
                  .where((cut) => _includes(cut, today))
                  .toList(),
            ),
        ]..sort((a, b) {
          final byDate = _dateOrder(a.cuts).compareTo(_dateOrder(b.cuts));
          return byDate != 0
              ? byDate
              : agendaCardLabel(a.card).compareTo(agendaCardLabel(b.card));
        });
    final allCuts = rows.expand((row) => row.cuts).toList();
    final visible = rows.where(
      (row) => _period == _Period.all || row.cuts.isNotEmpty,
    );
    String label(String currency) => currency == 'NIO' ? 'Córdobas' : 'Dólares';

    return ListView(
      padding: EdgeInsets.all(pageGutter(context)),
      children: [
        DropdownButtonFormField<_Period>(
          initialValue: _period,
          decoration: const InputDecoration(labelText: 'Vencimientos'),
          items: const [
            DropdownMenuItem(value: _Period.all, child: Text('Todas')),
            DropdownMenuItem(value: _Period.overdue, child: Text('Vencidas')),
            DropdownMenuItem(
              value: _Period.nextWeek,
              child: Text('Hoy y próximos 7 días'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _period = value);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Totales pendientes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Según los cortes registrados en este filtro.'),
        AdaptiveColumns(
          minColumnWidth: 260,
          children: [
            for (final currency in _currencies)
              Card(
                child: _moneyPanel(label(currency), [
                  for (final (title, select)
                      in <(String, int? Function(StatementProgress))>[
                        ('Mínimos', (cut) => cut.minimumRemaining),
                        ('Cortes completos', (cut) => cut.remaining),
                      ])
                    Builder(
                      builder: (_) {
                        final cuts = allCuts.where(
                          (cut) =>
                              cut.statement['currency'] == currency &&
                              !cut.settled,
                        );
                        final values = cuts.map(select).toList();
                        final total = values.whereType<int>().fold(
                          0,
                          (sum, value) => sum + value,
                        );
                        return _amountLabel(
                          values.contains(null) ? '$title · parcial' : title,
                          formatMoneyCents(total, currency),
                        );
                      },
                    ),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty) const Text('No hay tarjetas para este filtro.'),
        for (final row in visible)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 82,
                      child: CreditCardFace(
                        card: row.card,
                        compact: true,
                        imageOnly: true,
                      ),
                    ),
                    title: Text(
                      agendaCardLabel(row.card, includeName: false),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _paying
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreditCardStatementsPage(card: row.card),
                              ),
                            );
                            if (mounted) _refresh();
                          },
                  ),
                  const SizedBox(height: 10),
                  AdaptiveColumns(
                    minColumnWidth: 320,
                    children: [
                      for (final currency in _currencies)
                        _moneyPanel(label(currency), [
                          if (row.cuts.any(
                            (cut) => cut.statement['currency'] == currency,
                          ))
                            for (final cut in row.cuts.where(
                              (cut) => cut.statement['currency'] == currency,
                            ))
                              _cutRow(sheet, currency, cut)
                          else
                            Text(
                              _period == _Period.all
                                  ? 'Sin corte registrado'
                                  : 'Sin vencimientos en este filtro',
                            ),
                        ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hoja de pagos de tarjetas'),
      actions: [
        IconButton(
          onPressed: _paying ? null : _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: PageFrame(
      maxWidth: 1120,
      child: FutureBuilder<_Sheet>(
        future: _sheet,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('No se pudo cargar la hoja. Reintentar'),
              ),
            );
          }
          return _content(data);
        },
      ),
    ),
  );
}
