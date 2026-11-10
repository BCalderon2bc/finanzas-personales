String _agendaText(dynamic value) => value?.toString().trim() ?? '';

String agendaCardLabel(Map<String, dynamic>? card) {
  final institution = card?['financial_institutions'];
  final bank = institution is Map ? _agendaText(institution['name']) : '';
  final name = _agendaText(card?['name']);
  final digits = _agendaText(
    card?['card_reference'],
  ).replaceAll(RegExp(r'\D'), '');
  return [
    bank.isEmpty ? 'Banco sin asignar' : bank,
    name.isEmpty ? 'Tarjeta' : name,
    if (digits.length >= 4) '••${digits.substring(digits.length - 4)}',
  ].join(' · ');
}

String agendaDebtCreditor(Map<String, dynamic> debt) {
  final name = _agendaText(debt['creditor_name']);
  return name.isEmpty ? 'Acreedor sin registrar' : 'Acreedor: $name';
}

String additionalCardLabel(Map card) =>
    "${card['holder_name']} · ••${card['last_four']}";

String reportDebitCardLabel(Map<String, dynamic> card, {Map? account}) {
  final ownBank = card['financial_institutions'];
  final linkedBank = account?['financial_institutions'];
  final bank = ownBank is Map && _agendaText(ownBank['name']).isNotEmpty
      ? ownBank
      : linkedBank;
  final name = _agendaText(card['name']);
  final network = _agendaText(card['network']);
  final accountName = _agendaText(account?['name']);
  return agendaCardLabel({
    'financial_institutions': bank,
    'name': [
      if (name.isNotEmpty) name else if (accountName.isNotEmpty) accountName,
      network.isEmpty ? 'Débito' : network,
    ].join(' · '),
    'card_reference': card['card_reference'],
  });
}

String reportCreditMovementCardLabel(
  Map<String, dynamic> card,
  Map<String, dynamic> movement,
) {
  final additional = movement['credit_card_additionals'];
  return additional is Map
      ? '${agendaCardLabel(card)}\nAdicional · ${additionalCardLabel(additional)}'
      : agendaCardLabel(card);
}
