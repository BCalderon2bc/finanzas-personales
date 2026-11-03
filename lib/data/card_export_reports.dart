import '../utils/money.dart';
import '../features/credit_cards/credit_card_balances.dart';
import 'export_report_models.dart';

/// Saldos históricos por tarjeta, sin mezclar monedas ni duplicar tasa cero.
ExportReport creditCardsExport({
  required List<Map<String, dynamic>> cards,
  required List<Map<String, dynamic>> movements,
  required DateTime start,
  required DateTime end,
  required DateTime generatedAt,
  String currency = 'all',
  String? cardId,
}) {
  final details = <List<Object?>>[], summary = <List<Object?>>[];
  final sums = {'NIO': 0, 'USD': 0};
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
    final balances = {
      for (final c in ['NIO', 'USD']) c: cardOpening(card, c),
    };
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
      if (_after(date, end)) continue;
      final c = '${row['currency']}',
          effect = cardEffects[row['transaction_type']];
      if (!balances.containsKey(c) || effect == null)
        throw StateError('Movimiento de tarjeta pendiente de revisión.');
      final delta = effect * moneyCents(row['amount']);
      balances[c] = balances[c]! + delta;
      if (!inReportRange(date, start, end) ||
          currency != 'all' && c != currency)
        continue;
      details.add([
        reportDate(date),
        '${card['name']}',
        labels[row['transaction_type']] ?? '${row['transaction_type']}',
        '${row['description'] ?? ''}',
        c == 'NIO' ? MoneyCell(delta) : null,
        c == 'USD' ? MoneyCell(delta) : null,
        MoneyCell(balances['NIO']!),
        MoneyCell(balances['USD']!),
        '${row['reference'] ?? ''}',
      ]);
    }
    for (final c in ['NIO', 'USD']) {
      if (currency == 'all' || c == currency) sums[c] = sums[c]! + balances[c]!;
    }
    summary.add([
      '${card['name']}',
      card['is_active'] == true ? 'Activa' : 'Inactiva',
      currency == 'USD' ? null : MoneyCell(balances['NIO']!),
      currency == 'NIO' ? null : MoneyCell(balances['USD']!),
    ]);
  }
  return ExportReport(
    title: 'Tarjetas de crédito',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Saldos por tarjeta', [
        'Tarjeta',
        'Estado',
        'Saldo C\$',
        'Saldo US\$',
      ], summary),
      ReportTable('Movimientos de credito', [
        'Fecha',
        'Tarjeta',
        'Movimiento',
        'Descripción',
        'Variación C\$',
        'Variación US\$',
        'Saldo C\$',
        'Saldo US\$',
        'Referencia',
      ], details),
    ],
    totals: [
      for (final c in ['NIO', 'USD'])
        if (currency == 'all' || c == currency)
          ReportTotal(c, 'Saldo neto al cierre', sums[c]!),
    ],
    notes: const [
      'Los saldos incluyen la deuda inicial y todos los movimientos vigentes hasta la fecha final. El saldo de cada fila pertenece a su tarjeta. Positivo: deuda; negativo: saldo a favor.',
      'Compras, intereses y comisiones aumentan la deuda. Pagos y reembolsos la reducen. Los planes tasa cero ya incorporados al saldo inicial o a compras no se suman otra vez.',
      'Córdobas y dólares se presentan separados. No se aplica una tasa actual al historial.',
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
}) {
  final linked = cards
      .where((c) => cardId == null || '${c['id']}' == cardId)
      .map((c) => '${c['account_id']}')
      .toSet();
  final detail = <List<Object?>>[], summary = <List<Object?>>[];
  final totals = {'NIO': 0, 'USD': 0};
  for (final account in accounts.where(
    (a) =>
        linked.contains('${a['id']}') &&
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
    title: 'Tarjetas de débito · cuentas vinculadas',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Cuentas vinculadas', [
        'Cuenta',
        'Moneda',
        'Saldo C\$',
        'Saldo US\$',
      ], summary),
      ReportTable('Movimientos de debito', [
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
    notes: const [
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
