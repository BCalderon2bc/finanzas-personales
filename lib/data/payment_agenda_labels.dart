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
