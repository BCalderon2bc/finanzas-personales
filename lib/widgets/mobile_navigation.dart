import 'package:flutter/material.dart';
import '../features/accounts/accounts_page.dart';
import '../features/transactions/transactions_page.dart';

final dashboardScaffoldKey = GlobalKey<ScaffoldState>();

class MobileNavigation extends StatelessWidget {
  const MobileNavigation({super.key, required this.index, this.onReturn});
  final int index;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 62,
    selectedIndex: index,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
      NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Movimientos'),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        label: 'Cuentas',
      ),
      NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
    ],
    onDestinationSelected: (value) async {
      if (value == index) return;
      final navigator = Navigator.of(context);
      if (value == 0 || value == 3) {
        navigator.popUntil((route) => route.isFirst);
        if (value == 3) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            dashboardScaffoldKey.currentState?.openDrawer();
          });
        }
        return;
      }
      final route = MaterialPageRoute<void>(
        builder: (_) =>
            value == 1 ? const TransactionsPage() : const AccountsPage(),
      );
      if (index == 0) {
        await navigator.push(route);
        if (context.mounted) onReturn?.call();
      } else {
        navigator.pushReplacement(route);
      }
    },
  );
}
