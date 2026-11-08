import '../utils/money.dart';
import '../features/credit_cards/credit_card_balances.dart';
import 'export_report_models.dart';

/// Movimientos del período con totales separados por moneda.
ExportReport creditCardsExport({
  required List<Map<String, dynamic>> cards,
  required List<Map<String, dynamic>> movements,
  required DateTime start,
  required DateTime end,
  required DateTime generatedAt,
  String currency = 'all',
  String? cardId,
}) {
  const charges = 'Cargos';
  const payments = 'Pagos';
  const refunds = 'Reembolsos';
  const net = 'Total neto';
  final sums = {
    for (final c in cardCurrencies)
      if (currency == 'all' || c == currency)
        c: {charges: 0, payments: 0, refunds: 0, net: 0},
  };
  final details = <List<Object?>>[];
  const labels = {
    'purchase': 'Compra',
    'payment': 'Pago',
    'refund': 'Reembolso',
    'fee': 'Comisión',
    'interest': 'Intereses',
  };
  for (final card in cards.where(
    (c) => cardId == null || '${c['id']}' == cardId,
  )) {
    final rows =
        movements
            .where(
              (m) =>
                  '${m['credit_card_id']}' == '${card['id']}' &&
                  m['is_voided'] != true,
            )
            .toList()
          ..sort(_order);
    for (final row in rows) {
      final date = _date(row['transaction_date']);
      final c = '${row['currency']}';
      if (!inReportRange(date, start, end) ||
          currency != 'all' && c != currency) {
        continue;
      }
      final type = row['transaction_type'];
      final effect = cardEffects[type];
      final totals = sums[c];
      if (totals == null || effect == null) {
        throw StateError('Movimiento de tarjeta pendiente de revisión.');
      }
      final amount = effect * moneyCents(row['amount']);
      final group = switch (type) {
        'payment' => payments,
        'refund' => refunds,
        _ => charges,
      };
      totals[group] = totals[group]! + amount;
      totals[net] = totals[net]! + amount;
      details.add([
        reportDate(date),
        '${card['name']}',
        row['charge_kind'] == 'insurance' ? 'Seguro de tarjeta' : labels[type],
        '${row['description'] ?? ''}',
        c == 'NIO' ? MoneyCell(amount) : null,
        c == 'USD' ? MoneyCell(amount) : null,
        '${row['reference'] ?? ''}',
      ]);
    }
  }
  return ExportReport(
    title: 'Tarjetas de crédito',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    showTotalsSummary: false,
    tables: [
      ReportTable(
        'Movimientos de crédito',
        [
          'Fecha',
          'Tarjeta',
          'Movimiento',
          'Descripción',
          'Importe C\$',
          'Importe US\$',
          'Referencia',
        ],
        details,
        footerRows: [
          for (final label in [charges, payments, refunds, net])
            [
              null,
              null,
              label,
              null,
              for (final c in cardCurrencies)
                if (sums[c] case final totals?)
                  MoneyCell(totals[label]!)
                else
                  null,
              null,
            ],
        ],
      ),
    ],
    totals: [
      for (final entry in sums.entries)
        for (final total in entry.value.entries)
          ReportTotal(entry.key, total.key, total.value),
    ],
    notes: const [
      'Los totales corresponden a los movimientos del período y a las tarjetas seleccionadas.',
      'Las compras, los intereses, las comisiones y el seguro se incluyen en Cargos. Los pagos y reembolsos restan del total neto.',
      'Los importes se muestran en su moneda original.',
    ],
  );
}

/// Débito: estado de la cuenta bancaria vinculada, no atribución inventada a una tarjeta.
ExportReport debitCardsExport({
  required List<Map<String, dynamic>> cards,
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> transactions,
  required List<Map<String, dynamic>> cardPayments,
  required List<Map<String, dynamic>> debtPayments,
  required DateTime start,
  required DateTime end,
  required DateTime generatedAt,
  String currency = 'all',
  String? cardId,
  String? accountId,
  bool allAccounts = false,
}) {
  final linked = cards
      .where((c) => cardId == null || '${c['id']}' == cardId)
      .map((c) => '${c['account_id']}')
      .toSet();
  final detail = <List<Object?>>[], summary = <List<Object?>>[];
  final totals = {'NIO': 0, 'USD': 0};
  for (final account in accounts.where(
    (a) =>
        (allAccounts
            ? accountId == null || '${a['id']}' == accountId
            : linked.contains('${a['id']}')) &&
        (currency == 'all' || a['currency'] == currency),
  )) {
    final id = '${account['id']}', c = '${account['currency']}';
    var balance = moneyCents(account['opening_balance'] ?? 0);
    final events = <Map<String, dynamic>>[];
    for (final tx in transactions.where((t) => t['is_voided'] != true)) {
      final type = tx['transaction_type'];
      if ('${tx['account_id']}' == id) {
        if (![
          'income',
          'deposit',
          'expense',
          'withdrawal',
          'transfer',
        ].contains(type))
          throw StateError('Hay un ajuste de cuenta sin efecto definido.');
        if (tx['currency'] != c)
          throw StateError(
            'La moneda de un movimiento no coincide con su cuenta.',
          );
        events.add({
          ...tx,
          'delta':
              (['income', 'deposit'].contains(type) ? 1 : -1) *
              moneyCents(tx['amount']),
          'label': switch (type) {
            'income' => 'Ingreso',
            'deposit' => 'Depósito',
            'transfer' => 'Transferencia enviada',
            _ => 'Gasto / retiro',
          },
        });
      }
      if (type == 'transfer' && '${tx['destination_account_id']}' == id) {
        if ((tx['destination_currency'] ?? tx['currency']) != c)
          throw StateError('La moneda recibida no coincide con su cuenta.');
        events.add({
          ...tx,
          'delta': moneyCents(tx['destination_amount'] ?? tx['amount']),
          'label': 'Transferencia recibida',
        });
      }
    }
    for (final p in cardPayments.where(
      (p) => '${p['account_id']}' == id && p['is_voided'] != true,
    )) {
      if ((p['account_debit_currency'] ?? p['currency']) != c)
        throw StateError('Moneda del pago de tarjeta inválida.');
      events.add({
        ...p,
        'delta': -moneyCents(p['account_debit_amount'] ?? p['amount']),
        'label': 'Pago de tarjeta de crédito',
      });
    }
    for (final p in debtPayments.where(
      (p) => '${p['account_id']}' == id && p['is_voided'] != true,
    )) {
      if (p['currency'] != c) throw StateError('Moneda del abono inválida.');
      events.add({
        ...p,
        'transaction_date': p['payment_date'],
        'delta': -debtPaymentTotalCents(p),
        'label': 'Abono de préstamo',
      });
    }
    events.sort(_order);
    for (final event in events) {
      final date = _date(event['transaction_date']);
      if (_after(date, end)) continue;
      final delta = event['delta'] as int;
      balance += delta;
      if (!inReportRange(date, start, end)) continue;
      detail.add([
        reportDate(date),
        '${account['name']}',
        event['label'],
        '${event['description'] ?? ''}',
        c == 'NIO' ? MoneyCell(delta) : null,
        c == 'USD' ? MoneyCell(delta) : null,
        c == 'NIO' ? MoneyCell(balance) : null,
        c == 'USD' ? MoneyCell(balance) : null,
        '${event['reference'] ?? ''}',
      ]);
    }
    totals[c] = totals[c]! + balance;
    summary.add([
      '${account['name']}',
      c,
      c == 'NIO' ? MoneyCell(balance) : null,
      c == 'USD' ? MoneyCell(balance) : null,
    ]);
  }
  return ExportReport(
    title: allAccounts
        ? 'Cuentas y efectivo'
        : 'Tarjetas de débito · cuentas vinculadas',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable(allAccounts ? 'Cuentas' : 'Cuentas vinculadas', [
        'Cuenta',
        'Moneda',
        'Saldo C\$',
        'Saldo US\$',
      ], summary),
      ReportTable('Movimientos de cuentas', [
        'Fecha',
        'Cuenta',
        'Movimiento',
        'Descripción',
        'Variación C\$',
        'Variación US\$',
        'Saldo C\$',
        'Saldo US\$',
        'Referencia',
      ], detail),
    ],
    totals: [
      for (final c in ['NIO', 'USD'])
        if (currency == 'all' || c == currency)
          ReportTotal(c, 'Saldo bancario al cierre', totals[c]!),
    ],
    notes: [
      if (!allAccounts)
        'Incluye todos los movimientos de las cuentas vinculadas a las tarjetas de débito seleccionadas: el registro actual no identifica qué tarjeta física originó cada gasto.',
      'Una cuenta vinculada a varias tarjetas se cuenta una sola vez. Los saldos incorporan el saldo inicial y movimientos anteriores al período. Positivo: dinero disponible; negativo: sobregiro.',
      'Las transferencias entre monedas usan el importe recibido guardado. NIO y USD no se mezclan.',
    ],
  );
}

DateTime _date(dynamic value) => DateTime.parse('$value').toLocal();
bool _after(DateTime a, DateTime b) =>
    DateTime(a.year, a.month, a.day).isAfter(DateTime(b.year, b.month, b.day));
int _order(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byDate = _date(
    a['transaction_date'],
  ).compareTo(_date(b['transaction_date']));
  return byDate != 0 ? byDate : '${a['id']}'.compareTo('${b['id']}');
}

ExportReport creditCardExpensesExport({
  required List<Map<String, dynamic>> cards,
  required List<Map<String, dynamic>> movements,
  required DateTime start,
  required DateTime end,
  required DateTime generatedAt,
  String currency = 'all',
  String? cardId,
}) {
  final names = {for (final card in cards) '${card['id']}': '${card['name']}'};
  final rows = <List<Object?>>[];
  final charges = {'NIO': 0, 'USD': 0}, refunds = {'NIO': 0, 'USD': 0};
  final selected =
      movements
          .where(
            (tx) =>
                tx['is_voided'] != true &&
                tx['is_receivable_funding'] != true &&
                (cardId == null || '${tx['credit_card_id']}' == cardId) &&
                [
                  'purchase',
                  'interest',
                  'fee',
                  'refund',
                ].contains(tx['transaction_type']) &&
                (currency == 'all' || tx['currency'] == currency),
          )
          .toList()
        ..sort(_order);
  for (final tx in selected) {
    final date = _date(tx['transaction_date']);
    if (!inReportRange(date, start, end)) continue;
    final c = '${tx['currency']}';
    if (!charges.containsKey(c)) throw StateError('Moneda no admitida.');
    final refund = tx['transaction_type'] == 'refund';
    final amount = moneyCents(tx['amount']);
    if (refund) {
      refunds[c] = refunds[c]! + amount;
    } else {
      charges[c] = charges[c]! + amount;
    }
    final type = tx['charge_kind'] == 'insurance'
        ? 'Seguro de tarjeta'
        : switch (tx['transaction_type']) {
            'purchase' => 'Compra',
            'interest' => 'Intereses',
            'fee' => 'Comisión',
            _ => 'Reembolso',
          };
    rows.add([
      reportDate(date),
      names['${tx['credit_card_id']}'] ?? 'Tarjeta no disponible',
      type,
      '${tx['description'] ?? ''}',
      c == 'NIO' ? MoneyCell(refund ? -amount : amount) : null,
      c == 'USD' ? MoneyCell(refund ? -amount : amount) : null,
      '${tx['reference'] ?? ''}',
    ]);
  }
  return ExportReport(
    title: 'Gastos de tarjetas de crédito',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Gastos y devoluciones', [
        'Fecha',
        'Tarjeta',
        'Tipo',
        'Descripción',
        'Importe C\$',
        'Importe US\$',
        'Referencia',
      ], rows),
    ],
    totals: [
      for (final c in ['NIO', 'USD'])
        if (currency == 'all' || c == currency) ...[
          ReportTotal(c, 'Gastos', charges[c]!),
          ReportTotal(c, 'Devoluciones', refunds[c]!),
          ReportTotal(c, 'Gasto neto', charges[c]! - refunds[c]!),
        ],
    ],
    notes: const [
      'Pagos de tarjeta y préstamos desde tarjeta se excluyen del gasto. Cada compra se cuenta una vez. Los reembolsos restan. Las monedas se presentan separadas.',
    ],
  );
}
