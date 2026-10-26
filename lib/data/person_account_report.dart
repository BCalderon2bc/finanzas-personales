import '../utils/money.dart';
import 'person_account_logic.dart';
import 'export_report_models.dart';

/// Report from the ledger owner's perspective. Counterparty data stays scoped
/// to a single person_account_id, including when the caller passes other rows.
ExportReport personAccountReport({
  required Map<String, dynamic> account,
  required List<Map<String, dynamic>> entries,
  required DateTime generatedAt,
  DateTime? start,
  DateTime? end,
}) {
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
  var opening = 0,
      closing = 0,
      otherPurchases = 0,
      myPurchases = 0,
      myPayments = 0,
      receivedPayments = 0,
      previousEntries = 0;
  final detail = <List<Object?>>[];
  for (final e in rows) {
    final d = date(e), effect = personAccountBalance([e]);
    if (from != null && d.isBefore(from)) {
      opening += effect;
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
          effect > 0
              ? 'Pago de ${account['name']} (+)'
              : 'Pago del titular (−)',
        'opening' =>
          effect > 0
              ? 'Saldo anterior a favor de ${account['name']} (+)'
              : 'Saldo anterior a favor del titular (−)',
        _ =>
          effect > 0
              ? 'Compra de ${account['name']} (+)'
              : 'Compra del titular (−)',
      },
      '${e['description'] ?? ''}',
      '${e['currency']}',
      MoneyCell(moneyCents(e['amount'])),
      e['currency'] == 'USD' ? '${e['exchange_rate']}' : '—',
      MoneyCell(effect),
      MoneyCell(closing),
    ]);
  }
  final name = '${account['name']}';
  final conclusion = closing > 0
      ? 'El titular de este registro le debe a $name ${formatMoneyCents(closing, 'NIO')}.'
      : closing < 0
      ? '$name le debe al titular de este registro ${formatMoneyCents(-closing, 'NIO')}.'
      : 'La cuenta está saldada: ninguna de las dos personas debe dinero.';
  return ExportReport(
    title: 'Cuenta con $name',
    period: from == null
        ? 'Historial completo · saldo de todos los movimientos registrados'
        : 'Del ${reportDate(from)} al ${reportDate(to!)} · saldo al cierre del período',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Detalle', [
        'Fecha',
        'Tipo / signo',
        'Descripción',
        'Moneda',
        'Importe original',
        'Tasa C\$/US\$',
        'Variación C\$',
        'Saldo C\$',
      ], detail),
    ],
    totals: [
      ReportTotal('NIO', 'Saldo anterior al período', opening),
      ReportTotal('NIO', 'Compras de $name (+)', otherPurchases),
      ReportTotal('NIO', 'Compras del titular (−)', -myPurchases),
      ReportTotal('NIO', 'Pagos hechos por el titular (−)', -myPayments),
      ReportTotal(
        'NIO',
        'Pagos recibidos por el titular (+)',
        receivedPayments,
      ),
      if (previousEntries != 0)
        ReportTotal(
          'NIO',
          'Saldos anteriores registrados en el período',
          previousEntries,
        ),
      ReportTotal('NIO', 'Saldo al cierre (+ le debe / − le deben)', closing),
    ],
    notes: [
      conclusion,
      'Titular: la persona que lleva este registro. Contraparte: $name.',
      'Positivo: el titular le debe a $name. Negativo: $name le debe al titular. Los importes de compra y pago se compensan.',
      'Cada movimiento en USD usa su tasa guardada y se redondea a centavos. No se aplica la tasa actual a movimientos anteriores.',
      if (from != null)
        'El saldo anterior incluye todos los movimientos vigentes anteriores al inicio; el saldo final excluye fechas posteriores al cierre.',
      if (from == null)
        'El historial completo incluye todas las fechas registradas, incluso fechas futuras si existen.',
      'Los movimientos anulados se excluyen. Este reporte refleja los datos vigentes al generarlo, incluidas sus correcciones.',
      if (detail.isEmpty)
        'No hay movimientos vigentes para el período seleccionado.',
      'Este estado de cuenta no registra nuevos pagos ni modifica saldos bancarios.',
    ],
  );
}
