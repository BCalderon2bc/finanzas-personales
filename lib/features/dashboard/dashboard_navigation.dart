import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

class DashboardNavigation extends StatelessWidget {
  const DashboardNavigation({super.key, required this.onOpen});
  final ValueChanged<DashboardTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    Widget destination(String title, IconData icon, DashboardTarget target) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            Navigator.pop(context);
            onOpen(target);
          },
        );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.account_balance_wallet_outlined,
                      color: Color(0xFF2563EB)),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis Finanzas', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Tu espacio financiero',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                )),
              ]),
            ),
            ListTile(
              selected: true,
              selectedTileColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Resumen principal'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            destination('Cuentas y efectivo',
                Icons.account_balance_outlined, DashboardTarget.accounts),
            destination('Movimientos',
                Icons.swap_horiz_rounded, DashboardTarget.transactions),
            destination('Tarjetas de crédito',
                Icons.credit_card_outlined, DashboardTarget.cards),
            destination('Deudas y préstamos',
                Icons.handshake_outlined, DashboardTarget.debts),
            const Divider(height: 24),
            destination('Presupuestos',
                Icons.savings_outlined, DashboardTarget.budgets),
            destination('Categorías',
                Icons.category_outlined, DashboardTarget.categories),
            destination('Reporte de gastos',
                Icons.pie_chart_outline_rounded, DashboardTarget.reports),
          ],
        ),
      ),
    );
  }
}