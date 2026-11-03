import 'package:flutter/material.dart';
import '../accounts/accounts_page.dart';
import '../transactions/transactions_page.dart';
import '../credit_cards/credit_cards_page.dart';
import '../person_accounts/person_accounts_page.dart';
import '../reports/export_reports_page.dart';
import '../debts/debts_page.dart';
import '../receivable_loans/receivable_loans_page.dart';
import '../budgets/budgets_page.dart';
import '../settings/settings_page.dart';
import 'interactive_guide.dart';

bool hasGuideDestination(String topic) => const {
  'accounts',
  'movements',
  'cards',
  'people',
  'reports',
  'debts',
  'receivables',
  'budgets',
  'settings',
}.contains(topic);
Future<void> openGuideDestination(BuildContext context, String topic) async {
  final Widget page = switch (topic) {
    'accounts' => const AccountsPage(),
    'movements' => const TransactionsPage(),
    'cards' => const CreditCardsPage(),
    'people' => const PersonAccountsPage(),
    'reports' => const ExportReportsPage(),
    'debts' => const DebtsPage(),
    'receivables' => const ReceivableLoansPage(),
    'budgets' => const BudgetsPage(),
    'settings' => const SettingsPage(),
    _ => const CreditCardsPage(),
  };
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => GuideLaunch(topic: topic, child: page),
    ),
  );
}
