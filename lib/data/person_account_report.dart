import '../utils/money.dart';
import 'person_account_logic.dart';
import 'export_report_models.dart';
import 'person_account_export_report.dart';
import 'exchange_rate.dart';

/// Report from the ledger owner's perspective. Counterparty data stays scoped
/// to a single person_account_id, including when the caller passes other rows.
ExportReport personAccountReport({
  required Map<String, dynamic> account,
  required List<Map<String, dynamic>> entries,
  required DateTime generatedAt,
  String? ownerName,
  ExchangeRate? settlementRate,
  DateTime? start,
  DateTime? end,
}) {
  final owner = (ownerName ?? '').trim().isEmpty
      ? 'Titular del registro'
      : ownerName!.trim();
  final name = '${account['name']}'.trim();
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  if ((start == null) != (end == null))
    throw ArgumentError('Selecciona ambas fechas.');
  final from = start == null ? null : day(start),
      to = end == null ? null : day(end);
  if (from != null && to!.isBefore(from))
    throw ArgumentError('El período no es válido.');
  final rows = entries
      .where(
        (e) =>
            '${e['person_account_id']}' == '${account['id']}' &&
            e['is_voided'] != true,
      )
      .toList();
  DateTime date(Map<String, dynamic> e) {
    final d = DateTime.tryParse('${e['entry_date']}');
    if (d == null) throw StateError('Un movimiento tiene fecha inválida.');
    return day(d);
  }

  for (final e in rows) {
    date(e);
  }
  rows.sort((a, b) {
    final cmp = date(a).compareTo(date(b));
    return cmp != 0
        ? cmp
        : '${a['created_at']}:${a['id']}'.compareTo(
            '${b['created_at']}:${b['id']}',
          );
  });
  personAccountBalance(rows);
  var closing = 0,
      otherPurchases = 0,
      myPurchases = 0,
      myPayments = 0,
      receivedPayments = 0,
      previousEntries = 0;
  // Las columnas de conversión aparecen solo si el detalle visible contiene USD.
  final showExchange = rows.any((e) {
    final d = date(e);
    return e['currency'] == 'USD' &&
        (from == null || !d.isBefore(from)) &&
        (to == null || !d.isAfter(to));
  });
  final detail = <List<Object?>>[];
  for (final e in rows) {
    final d = date(e), effect = personAccountBalance([e]);
    if (from != null && d.isBefore(from)) {
      closing += effect;
      continue;
    }
    if (to != null && d.isAfter(to)) continue;
    closing += effect;
    switch (e['kind']) {
      case 'purchase':
        if (effect > 0)
          otherPurchases += effect;
        else
          myPurchases -= effect;
      case 'payment':
        if (effect > 0)
          receivedPayments += effect;
        else
          myPayments -= effect;
      case 'opening':
        previousEntries += effect;
      default:
        throw StateError('Tipo de movimiento no reconocido.');
    }
    detail.add([
      reportDate(d),
      switch (e['kind']) {
        'payment' =>
          effect > 0 ? 'Pago de ${account['name']} (+)' : 'Pago de $owner (−)',
        'opening' =>
          effect > 0
              ? 'Saldo anterior a favor de ${account['name']} (+)'
              : 'Saldo anterior a favor de $owner (−)',
        _ =>
          effect > 0
              ? 'Compra de ${account['name']} (+)'
              : 'Compra de $owner (−)',
      },
      '${e['description'] ?? ''}',
      '${e['currency']}',
      if (showExchange) ...[
        e['currency'] == 'USD'
            ? MoneyCell(
                moneyCents(e['amount']) * int.parse('${e['direction']}'),
              )
            : null,
        e['currency'] == 'USD' ? '${e['exchange_rate']}' : '—',
        // Usa el equivalente guardado, con el redondeo original del registro.
        MoneyCell(effect),
      ] else
        MoneyCell(effect),
    ]);
  }

  return PersonAccountExportReport(
    ownerName: owner,
    personName: name,
    closingCents: closing,
    settlementRate: settlementRate,
    title: 'Cuenta con $name',
    period: from == null
        ? 'Historial completo · saldo de todos los movimientos registrados'
        : 'Del ${reportDate(from)} al ${reportDate(to!)} · saldo al cierre del período',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Detalle', [
        'Fecha',
        'Movimiento',
        'Descripción',
        'Moneda',
        if (showExchange) ...[
          'Importe US\$',
          'Tasa C\$/US\$',
          'Importe C\$',
        ] else
          'Importe C\$',
      ], detail),
    ],
    totals: [
      ReportTotal('NIO', 'Compras de $name (+)', otherPurchases),
      ReportTotal('NIO', 'Compras de $owner (−)', -myPurchases),
      ReportTotal('NIO', 'Pagos hechos por $owner (−)', -myPayments),
      ReportTotal('NIO', 'Pagos recibidos por $owner (+)', receivedPayments),
      if (previousEntries != 0)
        ReportTotal(
          'NIO',
          'Saldos anteriores registrados en el período',
          previousEntries,
        ),
      ReportTotal('NIO', 'Saldo neto al cierre', closing),
    ],
    notes: [
      'Cada movimiento en USD usa su tasa guardada y se redondea a centavos. No se aplica la tasa actual a movimientos anteriores.',
      if (detail.isEmpty)
        'No hay movimientos vigentes para el período seleccionado.',
    ],
  );
}
