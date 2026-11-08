import '../core/supabase_client.dart';
import 'card_export_reports.dart';
import 'transaction_repository.dart';
import 'card_statement_repository.dart' show statementRows;
import 'debt_installment_repository.dart';
import 'export_report_models.dart';

Future<ExportReport> loadExportReport({
  required String kind,
  String? cardId,
  String? accountId,
  required String currency,
  required DateTime start,
  required DateTime end,
  required DateTime month,
}) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('Debes iniciar sesión.');
  }
  if (!['all', 'NIO', 'USD'].contains(currency) ||
      ![
        'movements',
        'debts',
        'budgets',
        'credit_cards',
        'credit_card_expenses',
        'accounts',
        'debit_cards',
      ].contains(kind)) {
    throw ArgumentError('Tipo de reporte o moneda inválidos.');
  }
  if ([
    'credit_cards',
    'credit_card_expenses',
    'debit_cards',
    'accounts',
  ].contains(kind)) {
    final credit = kind == 'credit_cards' || kind == 'credit_card_expenses';
    final values = await Future.wait([
      statementRows(credit ? 'credit_cards' : 'debit_cards', '*', uid),
      statementRows('accounts', 'id,name,currency,opening_balance', uid),
      loadUserTransactions(uid),
      statementRows('credit_card_transactions', '*', uid),
      statementRows('debt_payments', '*', uid),
    ]);
    if (supabase.auth.currentUser?.id != uid)
      throw StateError('La sesión cambió.');
    if (kind == 'credit_card_expenses')
      return creditCardExpensesExport(
        cards: values[0],
        movements: values[3],
        start: start,
        end: end,
        generatedAt: DateTime.now(),
        currency: currency,
        cardId: cardId,
      );
    return credit
        ? creditCardsExport(
            cards: values[0],
            movements: values[3],
            start: start,
            end: end,
            generatedAt: DateTime.now(),
            currency: currency,
            cardId: cardId,
          )
        : debitCardsExport(
            cards: values[0],
            accounts: values[1],
            transactions: values[2],
            cardPayments: values[3]
                .where((p) => p['transaction_type'] == 'payment')
                .toList(),
            debtPayments: values[4],
            start: start,
            end: end,
            generatedAt: DateTime.now(),
            currency: currency,
            cardId: cardId,
            accountId: accountId,
            allAccounts: kind == 'accounts',
          );
  }
  if (kind == 'debts') {
    final values = await Future.wait<Object>([
      statementRows(
        'debts',
        'id,description,creditor_name,currency,original_amount,status,due_date',
        uid,
      ),
      loadDebtInstallments(uid),
    ]);
    if (supabase.auth.currentUser?.id != uid) {
      throw StateError('La sesión cambió.');
    }
    final data = values[1] as DebtInstallmentData;
    return debtsReport(
      debts: values[0] as List<Map<String, dynamic>>,
      payments: data.payments,
      installments: data,
      currency: currency,
      generatedAt: DateTime.now(),
    );
  }
  final values = await Future.wait([
    loadUserTransactions(uid),
    statementRows('accounts', 'id,name,currency', uid),
    statementRows('categories', 'id,name', uid),
    statementRows('credit_cards', 'id,name,currency', uid),
    statementRows(
      'credit_card_transactions',
      'id,credit_card_id,account_id,category_id,transaction_type,charge_kind,amount,currency,transaction_date,description,reference,is_voided,is_receivable_funding,account_debit_amount,account_debit_currency,payment_exchange_rate',
      uid,
    ),
    statementRows('debts', 'id,description,currency', uid),
    statementRows(
      'debt_payments',
      'id,debt_id,account_id,principal_amount,interest_amount,fee_amount,insurance_amount,currency,payment_date,reference,is_voided',
      uid,
    ),
    if (kind == 'budgets')
      statementRows(
        'budgets',
        'id,category_id,currency,budget_amount,month,start_date,end_date',
        uid,
      ),
  ]);
  if (supabase.auth.currentUser?.id != uid) {
    throw StateError('La sesión cambió.');
  }
  final normalized = normalizeExportMovements(
    accountMovements: values[0],
    accounts: values[1],
    categories: values[2],
    cards: values[3],
    cardMovements: values[4],
    debts: values[5],
    debtPayments: values[6],
  );
  return kind == 'movements'
      ? movementsReport(normalized, start, end, currency, DateTime.now())
      : budgetsReport(
          budgets: values[7],
          categories: values[2],
          movements: normalized,
          month: month,
          currency: currency,
          generatedAt: DateTime.now(),
        );
}
