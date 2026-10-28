class ShareBank {
  const ShareBank(this.id, this.name, this.ibanCode);
  final String id, name, ibanCode;
}

const shareBanks = [
  ShareBank('bac', 'BAC', 'BAMC'),
  ShareBank('banpro', 'Banpro', 'BAPR'),
  ShareBank('lafise', 'LAFISE', 'BCCE'),
  ShareBank('avanz', 'Avanz', 'PRCB'),
  ShareBank('ficohsa', 'Ficohsa', 'BUNO'),
  ShareBank('bdf', 'BDF', 'BBDF'),
  ShareBank('atlantida', 'Atlántida', 'ATTD'),
  ShareBank('bcn', 'Banco Central de Nicaragua', 'BCNI'),
];
String _bankText(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');
ShareBank? accountShareBank(String name, {String code = ''}) {
  final value = _bankText('$name $code').replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final tokens = value.split(RegExp(r'\s+'));
  for (final bank in shareBanks) {
    if (tokens.contains(bank.id) ||
        tokens.contains(bank.ibanCode.toLowerCase()))
      return bank;
  }
  if (value.contains('america central')) return shareBanks[0];
  if (value.contains('bancentro')) return shareBanks[2];
  if (value.contains('banco de finanzas')) return shareBanks[5];
  if (value.contains('banco de la produccion')) return shareBanks[1];
  if (value.contains('banco central de nicaragua')) return shareBanks[7];
  return null;
}

String normalizeAccountIban(String text) =>
    text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
String? validateAccountIban(
  String? value, {
  String bankName = '',
  String bankCode = '',
  String accountNumber = '',
}) {
  final iban = normalizeAccountIban(value ?? '');
  if (iban.isEmpty) return null;
  if (!RegExp(r'^NI\d{2}[A-Z]{4}\d{20}$').hasMatch(iban))
    return 'El IBAN de Nicaragua debe tener 28 caracteres: NI, 2 dígitos, banco y 20 dígitos.';
  var remainder = 0;
  for (final code in '${iban.substring(4)}${iban.substring(0, 4)}'.codeUnits) {
    if (code >= 65 && code <= 90)
      remainder = (remainder * 100 + code - 55) % 97;
    else
      remainder = (remainder * 10 + code - 48) % 97;
  }
  if (remainder != 1)
    return 'Revisa el IBAN: sus dígitos de control no coinciden. Cópialo nuevamente del banco.';
  final bank = accountShareBank(bankName, code: bankCode);
  if (bank != null && iban.substring(4, 8) != bank.ibanCode)
    return 'Ese IBAN no corresponde a ${bank.name}. Revisa el banco seleccionado.';
  final local = accountNumber.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^\d{1,20}$').hasMatch(local) &&
      iban.substring(8) != local.padLeft(20, '0')) {
    return 'El IBAN no coincide con el número de cuenta. Revisa ambos datos en el banco.';
  }
  return null;
}

String shareCurrency(String currency) => switch (currency) {
  'NIO' => 'Córdobas (NIO)',
  'USD' => 'Dólares (USD)',
  _ => currency,
};
String _oneLine(dynamic value) =>
    '${value ?? ''}'.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();

/// BAC follows the user's supplied copy example. Other banks use an app-owned
/// standard layout: public sources do not document their exact clipboard text.
String buildAccountShareText(Map<String, dynamic> account) {
  final institution = account['financial_institutions'];
  final bankName = institution is Map ? _oneLine(institution['name']) : '';
  final bankCode = institution is Map ? _oneLine(institution['code']) : '';
  final bank = accountShareBank(bankName, code: bankCode);
  final holder = _oneLine(account['account_holder']),
      number = _oneLine(account['account_number']);
  final iban = normalizeAccountIban('${account['account_iban'] ?? ''}'),
      currency = _oneLine(account['currency']);
  final lines = <String>[];
  if (holder.isNotEmpty)
    lines.add('${bank?.id == 'bac' ? 'Cliente' : 'Titular'}: $holder');
  if (bank?.id != 'bac' && (bank?.name ?? bankName).isNotEmpty)
    lines.add('Banco: ${bank?.name ?? bankName}');
  if (number.isNotEmpty)
    lines.add(
      '${bank?.id == 'bac' ? 'Número de cuenta BAC' : 'Número de cuenta'}: $number',
    );
  if (iban.isNotEmpty) lines.add('Número de cuenta IBAN: $iban');
  if (currency.isNotEmpty) lines.add('Moneda: ${shareCurrency(currency)}');
  return lines.join('\n');
}

List<String> missingAccountShareFields(Map<String, dynamic> account) {
  final missing = <String>[];
  if (_oneLine(account['account_holder']).isEmpty) missing.add('titular');
  if (_oneLine(account['account_number']).isEmpty &&
      normalizeAccountIban('${account['account_iban'] ?? ''}').isEmpty)
    missing.add('número de cuenta o IBAN');
  if (!['NIO', 'USD'].contains(account['currency'])) missing.add('moneda');
  final institution = account['financial_institutions'];
  if (institution is! Map || _oneLine(institution['name']).isEmpty)
    missing.add('banco');
  return missing;
}
