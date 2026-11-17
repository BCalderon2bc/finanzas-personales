import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../data/card_statement_repository.dart';
import '../person_accounts/person_receipts_dialog.dart';
import '../person_accounts/receipt_draft_field.dart';
import 'credit_card_payment_dialog.dart';

Future<bool> registerStatementPayment(
  BuildContext context,
  String userId,
  Map<String, dynamic> s, {
  int? initialAmountCents,
}) async {
  final rows = await statementRows(
    'accounts',
    'id,name,currency,is_active',
    userId,
  );
  final accounts = rows
      .where((a) => a['is_active'] == true && a['currency'] == s['currency'])
      .toList();
  if (!context.mounted) {
    return false;
  }
  if (accounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Necesitas una cuenta activa en ${s['currency']}.'),
      ),
    );
    return false;
  }
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => CreditCardPaymentDialog(
      accounts: accounts,
      currency: '${s['currency']}',
      statements: [s],
      initialStatementId: '${s['id']}',
      initialAmountCents: initialAmountCents,
    ),
  );
  if (result == null || !context.mounted) {
    return false;
  }
  if (supabase.auth.currentUser?.id != userId) {
    throw StateError('La sesión cambió.');
  }
  final linked = result['statement_id'];
  final receipt = result.remove(receiptDraftKey) as PendingReceipt?;
  final saved = await supabase.rpc(
    linked == null
        ? 'register_credit_card_payment'
        : 'register_credit_card_payment_for_statement',
    params: {
      'p_card_id': s['credit_card_id'],
      'p_account_id': result['account_id'],
      'p_amount': result['amount'],
      'p_reference': result['reference'],
      if (linked != null) 'p_statement_id': linked,
    },
  );
  if (context.mounted)
    await attachFinancialReceipt(
      context,
      receipt,
      userId,
      'credit_card_transactions',
      saved,
    );
  return true;
}
