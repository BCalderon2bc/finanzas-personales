import 'avanz_statement_import.dart';
import 'period_logic.dart';

typedef ImportedCardStatement = ({
  DateTime closing,
  DateTime? bonus,
  DateTime due,
  String? cardEnding,
  Map<String, ({int minimum, int? overdue, int balance})> amounts,
});

String? statementPdfBankName(String bank) => switch (bank) {
  'avanz' => 'Avanz',
  'bac' => 'BAC',
  'ficohsa' => 'Ficohsa',
  'lafise' => 'LAFISE',
  _ => null,
};

bool statementShowsOverdue(String bank) =>
    bank == 'avanz' || bank == 'ficohsa' || bank == 'lafise';

const _day = r'(\d{2}/\d{2}/\d{4})';
const _bacDay = r'(\d{2}/(?:[a-z]{3}|\d{2})/(?:\d{4}|\d{2}))';
const _money = r'((?:\d{1,3}(?:,\d{3})+|\d*)\.\d{2})(?![\d.,-])';
const _plainPair = '$_money $_money';
const _currencyPair =
    r'c\$\s*'
    '$_money '
    r'(?:us)?\$\s*'
    '$_money';

ImportedCardStatement? parseCardStatementPdf(String bank, String text) {
  if (bank == 'avanz') return parseAvanzStatement(text);
  final source = text
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[\s\u00a0]+'), ' ')
      .trim();
  return switch (bank) {
    'bac' => _parseBac(source),
    'ficohsa' => _parseFicohsa(source),
    'lafise' => _parseLafise(source),
    _ => null,
  };
}

ImportedCardStatement? _parseBac(String source) {
  final account = RegExp(
    r'^estado de cuenta numero de cuenta [x*]+(\d{4})\b',
  ).firstMatch(source);
  final payments = RegExp(
    'fecha de corte $_bacDay (?:fecha limite para bonificar $_bacDay )?'
    'fecha limite para pagar $_bacDay cordobas dolares '
    'pago minimo $_currencyPair pago de contado $_currencyPair credito disponible ',
  ).firstMatch(source);
  if (account == null || payments == null) return null;
  return _statement(
    dates: payments,
    closing: 1,
    bonus: 2,
    due: 3,
    payments: payments,
    minimum: 4,
    balance: 6,
    cardEnding: account[1],
  );
}

ImportedCardStatement? _parseFicohsa(String source) {
  if (!source.startsWith('estado de cuenta ficohsa ') ||
      !source.contains('www.ficohsa.ni')) {
    return null;
  }
  final period = RegExp(
    'periodo: desde: $_day hasta: $_day ',
  ).firstMatch(source);
  final payments = RegExp(
    'pago de contado: $_currencyPair pago minimo: $_currencyPair '
    '(?:pago atrasado: $_currencyPair )?'
    r'\*?\s*'
    'fecha maxima de pago: $_day ',
  ).firstMatch(source);
  if (period == null || payments == null || _date(period[1]) == null)
    return null;
  final ending = RegExp(r'\bcuenta: [x*]+(\d{4})\b').firstMatch(source)?[1];
  return _statement(
    dates: period,
    closing: 2,
    due: 7,
    dueMatch: payments,
    payments: payments,
    minimum: 3,
    balance: 1,
    overdue: 5,
    cardEnding: ending,
  );
}

ImportedCardStatement? _parseLafise(String source) {
  // En el texto de la primera página, PDFium separa los encabezados de sus valores.
  final dates = RegExp(
    r'^tit\.de cuenta: no\.de cuenta: modelo liquidacion: fecha de corte: '
    r'fecha lim\. de pago: estado de cuenta hoja: 1 tipo de tarjeta: .+? '
    r'tipo de tasa de interes: (?:fija|variable) \d+ '
    '$_day $_day ',
  ).firstMatch(source);
  final payments = RegExp(
    'cordobas dolares saldo actual $_money (?:$_money )?'
    'pago de contado (?:$_money )?$_plainPair '
    'pago minimo $_plainPair porcion principal pago minimo ',
  ).firstMatch(source);
  if (dates == null || payments == null) return null;
  final overdue = RegExp(
    r'\(\s*\d+\s*\)\s*pago\(s\) vencido\(s\) '
    '$_plainPair tasa de int\\. corriente anual',
  ).firstMatch(source);
  final endings = RegExp(
    r'\b[x*]{8,}(\d{4})\b',
  ).allMatches(source).map((match) => match[1]!).toSet();
  return _statement(
    dates: dates,
    closing: 1,
    due: 2,
    payments: payments,
    minimum: 6,
    balance: 4,
    overdue: overdue == null ? null : 1,
    overdueMatch: overdue,
    cardEnding: endings.length == 1 ? endings.single : null,
  );
}

DateTime? _date(String? text) {
  if (text == null) return null;
  const months = {
    'ene': 1,
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'abr': 4,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dic': 12,
    'dec': 12,
  };
  final parts = text.split('/');
  final day = int.parse(parts[0]);
  final month = int.tryParse(parts[1]) ?? months[parts[1]];
  final year = int.parse(parts[2]) + (parts[2].length == 2 ? 2000 : 0);
  if (month == null || year < 1900 || year > 2200) return null;
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

int? _cents(String? text) =>
    text == null ? null : int.tryParse(text.replaceAll(RegExp(r'[,.]'), ''));

ImportedCardStatement? _statement({
  required RegExpMatch dates,
  required int closing,
  required int due,
  required RegExpMatch payments,
  required int minimum,
  required int balance,
  int? bonus,
  int? overdue,
  RegExpMatch? dueMatch,
  RegExpMatch? overdueMatch,
  String? cardEnding,
}) {
  final start = _date(dates[closing]);
  final end = _date((dueMatch ?? dates)[due]);
  final bonusText = bonus == null ? null : dates[bonus];
  final bonusDate = _date(bonusText);
  if (start == null ||
      end == null ||
      end.isBefore(start) ||
      (bonusText != null &&
          (bonusDate == null || !includesDay(bonusDate, start, end)))) {
    return null;
  }

  final amounts = <String, ({int minimum, int? overdue, int balance})>{};
  for (var index = 0; index < 2; index++) {
    final total = _cents(payments[balance + index]);
    final min = _cents(payments[minimum + index]);
    final lateText = overdue == null
        ? null
        : (overdueMatch ?? payments)[overdue + index];
    final late = _cents(lateText);
    if (total == null ||
        min == null ||
        min > total ||
        total > 99999999999999 ||
        (lateText != null && (late == null || late > 99999999999999))) {
      return null;
    }
    amounts[index == 0 ? 'NIO' : 'USD'] = (
      minimum: min,
      overdue: late,
      balance: total,
    );
  }
  return (
    closing: start,
    bonus: bonusDate,
    due: end,
    cardEnding: cardEnding,
    amounts: amounts,
  );
}
