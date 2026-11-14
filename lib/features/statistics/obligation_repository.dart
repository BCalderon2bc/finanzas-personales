import 'dart:async';

import '../../data/card_statement_repository.dart' show statementRows;
import '../../data/debt_installment_repository.dart' show loadDebtInstallments;
import '../../data/person_account_repository.dart';
import '../../data/receivable_loan_repository.dart';
import 'obligation_statistics.dart';

Future<ObligationData> loadObligationData() async {
  final uid = personUserId();
  final (
    cards,
    cardMovements,
    debts,
    installmentData,
    loans,
    people,
    entries,
  ) = await (
    statementRows(
      'credit_cards',
      'id,name,currency,opening_balance,opening_balance_nio,opening_balance_usd,card_reference,financial_institutions(name)',
      uid,
    ),
    statementRows(
      'credit_card_transactions',
      'id,credit_card_id,transaction_type,amount,currency,transaction_date,is_voided',
      uid,
    ),
    statementRows(
      'debts',
      'id,description,currency,original_amount,status',
      uid,
    ),
    loadDebtInstallments(uid),
    loadReceivableLoanData(uid),
    personRows('person_accounts', uid, includeShared: true),
    personRows('person_account_entries', uid, includeShared: true),
  ).wait;
  checkPersonSession(uid);
  return ObligationData(
    userId: uid,
    cards: cards,
    cardMovements: cardMovements,
    debts: debts,
    debtPayments: installmentData.payments,
    installmentData: installmentData,
    loans: loans.loans,
    loanPayments: loans.payments,
    people: people,
    personEntries: entries,
  );
}
