const expenseReportCategoryLabels = {
  'debt_costs': 'Costos de deuda',
  'card_purchases': 'Compras de tarjeta',
  'card_interest': 'Intereses de tarjeta',
  'card_fees': 'Comisiones y cargos de tarjeta',
  'card_insurance': 'Seguros de tarjeta',
  'card_refunds': 'Devoluciones de tarjeta',
  'card_other': 'Otros gastos de tarjeta',
  'uncategorized': 'Sin categoría',
};

bool isCardInsuranceExpense(Map<String, dynamic> expense) =>
    expense['expense_kind'] == 'card_insurance' ||
    (expense['source'] == 'credit_card' &&
        expense['charge_kind'] == 'insurance');

String expenseReportCategoryKey(Map<String, dynamic> expense) {
  if (expense['source'] == 'debt_payment') return 'debt_costs';

  final assigned = expense['category_id']?.toString().trim();
  if (assigned != null && assigned.isNotEmpty) return assigned;

  if (isCardInsuranceExpense(expense)) return 'card_insurance';
  if (expense['source'] != 'credit_card') return 'uncategorized';

  return switch (expense['card_transaction_type']) {
    'purchase' => 'card_purchases',
    'interest' => 'card_interest',
    'fee' => 'card_fees',
    'refund' => 'card_refunds',
    _ => 'card_other',
  };
}
