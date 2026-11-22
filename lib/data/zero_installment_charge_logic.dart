const zeroInstallmentChargeType = 'plan_installment';

/// Only the card HISTORY merges these rows. Balance and expense repositories
/// keep using credit_card_transactions, so principal is never counted twice.
Map<String, dynamic> zeroInstallmentHistoryRow(Map<String, dynamic> charge) => {
  ...charge,
  'id': 'installment-charge/${charge['id']}',
  'charge_id': charge['id'],
  'transaction_type': zeroInstallmentChargeType,
  'transaction_date': '${charge['charge_date']}T12:00:00',
  'is_voided': (charge['card_zero_plans'] as Map?)?['is_voided'] == true,
  'source': 'installment_charge',
};
