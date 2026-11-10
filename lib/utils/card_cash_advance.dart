import 'money.dart';

const cardCashAdvance = 'cash_advance';
const cardCashAdvanceLabel = 'Retiro de efectivo';
const cardCashAdvanceFeeLabel = 'Comisión por retiro de efectivo';
const cashAdvanceDepositSource = 'card_cash_advance_deposit';

bool isCardCashAdvance(Map<String, dynamic> row) =>
    row['charge_kind'] == cardCashAdvance;

int cardCashAdvanceFee(Map<String, dynamic> row) =>
    moneyCents(row['cash_advance_fee'] ?? 0);

int cardCashAdvancePrincipal(Map<String, dynamic> row) =>
    moneyCents(row['amount']) - cardCashAdvanceFee(row);

String cardCashAdvanceBreakdown(Map<String, dynamic> row) {
  final currency = '${row['currency']}';
  return 'Efectivo: ${formatMoneyCents(cardCashAdvancePrincipal(row), currency)}'
      ' · Comisión: ${formatMoneyCents(cardCashAdvanceFee(row), currency)}';
}
