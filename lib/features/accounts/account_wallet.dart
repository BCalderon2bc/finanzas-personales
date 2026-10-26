import 'package:flutter/material.dart';
import '../../widgets/responsive_wallet.dart';
import 'account_card.dart';

class AccountWallet extends StatelessWidget {
  const AccountWallet({super.key, required this.accounts, required this.balances,
    required this.selectedId, this.onSelected});
  final List<Map<String, dynamic>> accounts;
  final Map<String, int> balances;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) => ResponsiveWallet(
    items: accounts, selectedId: selectedId, onSelected: onSelected,
    title: 'Mi billetera', icon: Icons.account_balance_wallet_outlined,
    labelFor: (a) => '${a['name']} · ${a['currency']}',
    itemBuilder: (account, selected) {
      final id = '${account['id']}';
      return Semantics(selected: selected, button: true,
        child: Material(color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(borderRadius: BorderRadius.circular(24),
            onTap: onSelected == null ? null : () => onSelected!(id),
            child: AccountCard(
              account: {...account, 'notes': null, 'account_reference': null},
              balanceCents: balances[id] ?? 0,
            ),
          ),
        ),
      );
    },
  );
}
