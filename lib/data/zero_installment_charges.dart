export 'zero_installment_charge_logic.dart';
import 'card_statement_repository.dart' show statementRows;

Future<List<Map<String, dynamic>>> loadZeroInstallmentCharges(
  String uid, {
  String? cardId,
}) => statementRows(
  'card_zero_installment_charges',
  '*,card_zero_plans(is_voided)',
  uid,
  cardId: cardId,
);
