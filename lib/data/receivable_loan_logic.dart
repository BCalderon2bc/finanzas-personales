import '../utils/money.dart';

String receivableMoney(int cents, String currency) =>
    formatMoneyCents(cents, currency);

int receivablePrincipalPaid(String loanId, Iterable<Map<String, dynamic>> payments) =>
    payments.where((p) => p['loan_id'].toString() == loanId && p['is_voided'] != true)
      .fold<int>(0, (sum, p) => sum + moneyCents(p['principal_amount']));

int receivablePending(Map<String, dynamic> loan, Iterable<Map<String, dynamic>> payments) {
  final own = payments.where((p) => p['loan_id'].toString() == loan['id'].toString() && p['is_voided'] != true);
  if (own.any((p) => p['currency'] != loan['currency'])) {
    throw StateError('Hay un cobro con moneda diferente al préstamo.');
  }
  final pending = moneyCents(loan['principal_amount']) - receivablePrincipalPaid(loan['id'].toString(), own);
  if (pending < 0) { throw StateError('Los cobros superan el capital del préstamo.'); }
  return pending;
}

bool receivableOverdue(Map<String, dynamic> loan, int pending, DateTime now) {
  if (loan['is_voided'] == true || pending <= 0) { return false; }
  final due = DateTime.tryParse('${loan['due_date']}');
  if (due == null) { return false; }
  return DateTime(due.year, due.month, due.day).isBefore(DateTime(now.year, now.month, now.day));
}

// Filas derivadas en memoria: nunca se insertan en public.transactions.
List<Map<String, dynamic>> receivableAccountMovements(
  List<Map<String, dynamic>> loans, List<Map<String, dynamic>> payments,
) {
  final result = <Map<String, dynamic>>[];
  final activeLoans = {for (final l in loans.where((l) => l['is_voided'] != true)) l['id'].toString(): l};
  Map<String, dynamic> row({required String id, required String loanId, required String accountId,
    required String type, required dynamic amount, required String currency, required dynamic date,
    required String description, dynamic reference}) => {
      'id': id, 'account_id': accountId, 'destination_account_id': null, 'category_id': null,
      'transaction_type': type, 'amount': amount, 'currency': currency, 'transaction_date': date,
      'description': description, 'reference': reference, 'is_reconciled': false,
      'source': 'receivable_loan', 'loan_id': loanId,
    };
  for (final loan in activeLoans.values) {
    receivablePending(loan, payments);
    if (loan['is_historical'] == true || loan['credit_card_id'] != null) { continue; }
    if (loan['account_id'] == null) { throw StateError('Un préstamo nuevo no tiene cuenta de origen.'); }
    result.add(row(id: 'receivable:loan:${loan['id']}', loanId: loan['id'].toString(),
      accountId: loan['account_id'].toString(), type: 'withdrawal', amount: loan['principal_amount'],
      currency: loan['currency'].toString(), date: loan['loan_date'],
      description: 'Dinero prestado a ${loan['borrower_name']}', reference: loan['reference']));
  }
  for (final payment in payments.where((p) => p['is_voided'] != true)) {
    final loan = activeLoans[payment['loan_id'].toString()];
    if (loan == null) { throw StateError('Hay un cobro vigente sin préstamo vigente.'); }
    for (final component in ['principal_amount', 'interest_amount']) {
      if (moneyCents(payment[component]) == 0) { continue; }
      final capital = component == 'principal_amount';
      result.add(row(id: 'receivable:payment:${payment['id']}:$component', loanId: loan['id'].toString(),
        accountId: payment['account_id'].toString(), type: capital ? 'deposit' : 'income',
        amount: payment[component], currency: payment['currency'].toString(), date: payment['payment_date'],
        description: '${capital ? 'Capital devuelto por' : 'Intereses cobrados a'} ${loan['borrower_name']}',
        reference: payment['reference']));
    }
  }
  return result;
}
