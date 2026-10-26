import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

class DashboardNavigation extends StatelessWidget {
  const DashboardNavigation({
    super.key,
    required this.onOpen,
    this.onOpenReceivables,
    this.onChangePassword,
    this.onSettings,
    this.onExport,
    this.onPersonAccounts,
  });

  final ValueChanged<DashboardTarget> onOpen;
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onChangePassword;
  final VoidCallback? onSettings;
  final VoidCallback? onExport;
  final VoidCallback? onPersonAccounts;

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
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi Billete',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tu espacio financiero',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              selected: true,
              selectedTileColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Resumen principal'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            destination(
              'Cuentas y efectivo',
              Icons.account_balance_outlined,
              DashboardTarget.accounts,
            ),
            destination(
              'Movimientos',
              Icons.swap_horiz_rounded,
              DashboardTarget.transactions,
            ),
            destination(
              'Tarjetas de crédito',
              Icons.credit_card_outlined,
              DashboardTarget.cards,
            ),
            destination(
              'Deudas y préstamos',
              Icons.handshake_outlined,
              DashboardTarget.debts,
            ),
            ListTile(
              enabled: onOpenReceivables != null,
              leading: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF2563EB),
                  size: 21,
                ),
              ),
              title: const Text('Préstamos por cobrar'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: onOpenReceivables == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onOpenReceivables?.call();
                    },
            ),
            ListTile(
              enabled: onPersonAccounts != null,
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Cuentas con personas'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onPersonAccounts == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onPersonAccounts?.call();
                    },
            ),
            const Divider(height: 24),
            destination(
              'Presupuestos',
              Icons.savings_outlined,
              DashboardTarget.budgets,
            ),
            destination(
              'Categorías',
              Icons.category_outlined,
              DashboardTarget.categories,
            ),
            destination(
              'Reporte de gastos',
              Icons.pie_chart_outline_rounded,
              DashboardTarget.reports,
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar Excel / PDF'),
              trailing: const Icon(Icons.chevron_right_rounded),
              enabled: onExport != null,
              onTap: onExport == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onExport?.call();
                    },
            ),
            const Divider(height: 24),
            ListTile(
              enabled: onSettings != null,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configuraciones'),
              subtitle: const Text('Tasa de cambio'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onSettings == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onSettings?.call();
                    },
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'MI CUENTA',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              enabled: onChangePassword != null,
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Cambiar contraseña'),
              subtitle: const Text('Contraseña de inicio de sesión'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: onChangePassword == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onChangePassword?.call();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
