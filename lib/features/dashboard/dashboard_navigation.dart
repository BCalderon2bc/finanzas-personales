import '../recurring_expenses/recurring_expenses_page.dart';
import '../help/app_help.dart';
import '../../widgets/app_version_footer.dart';
import 'package:flutter/material.dart';
import 'dashboard_overview.dart';

class DashboardNavigation extends StatelessWidget {
  const DashboardNavigation({
    super.key,
    required this.onOpen,
    required this.activeEmail,
    this.activeName,
    this.onOpenReceivables,
    this.onSettings,
    this.onExport,
    this.onPersonAccounts,
  });

  final ValueChanged<DashboardTarget> onOpen;
  final String activeEmail;
  final String? activeName;
  final VoidCallback? onOpenReceivables;
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

    Widget action(String title, IconData icon, VoidCallback? callback) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          enabled: callback != null,
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: callback == null
              ? null
              : () {
                  Navigator.pop(context);
                  callback();
                },
        );

    Widget group(
      String title,
      IconData icon,
      List<Widget> children, {
      bool expanded = false,
    }) => ExpansionTile(
      key: PageStorageKey('navigation-group-$title'),
      initiallyExpanded: expanded,
      leading: Icon(icon),
      title: Text(title),
      childrenPadding: const EdgeInsets.only(left: 12),
      children: children,
    );

    return Drawer(
      child: PrimaryScrollController.none(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  // The drawer must not inherit the dashboard guide controller.
                  primary: false,
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Text(
                        'Mi Billete',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_circle_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  activeName ?? 'Usuario activo',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeEmail,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      selected: true,
                      leading: const Icon(Icons.dashboard_outlined),
                      title: const Text('Resumen principal'),
                      onTap: () => Navigator.pop(context),
                    ),
                    group(
                      'Tu dinero',
                      Icons.account_balance_wallet_outlined,
                      [
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
                      ],
                      expanded: true,
                    ),
                    group('Deudas y personas', Icons.handshake_outlined, [
                      destination(
                        'Deudas y préstamos',
                        Icons.handshake_outlined,
                        DashboardTarget.debts,
                      ),
                      action(
                        'Préstamos por cobrar',
                        Icons.payments_outlined,
                        onOpenReceivables,
                      ),
                      action(
                        'Cuentas con personas',
                        Icons.people_alt_outlined,
                        onPersonAccounts,
                      ),
                    ]),
                    group('Planificación', Icons.event_repeat_outlined, [
                      ListTile(
                        leading: const Icon(Icons.event_repeat_outlined),
                        title: const Text('Gastos fijos y suscripciones'),
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RecurringExpensesPage(),
                            ),
                          );
                        },
                      ),
                      destination(
                        'Presupuestos',
                        Icons.savings_outlined,
                        DashboardTarget.budgets,
                      ),
                    ]),
                    group('Reportes', Icons.assessment_outlined, [
                      destination(
                        'Gastos por categoría',
                        Icons.pie_chart_outline_rounded,
                        DashboardTarget.reports,
                      ),
                      action(
                        'Reportes PDF / Excel',
                        Icons.file_download_outlined,
                        onExport,
                      ),
                    ]),
                    group('Configuración y ayuda', Icons.settings_outlined, [
                      destination(
                        'Categorías',
                        Icons.category_outlined,
                        DashboardTarget.categories,
                      ),
                      action(
                        'Configuraciones',
                        Icons.settings_outlined,
                        onSettings,
                      ),
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('Manual y ayuda'),
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AppManualPage(),
                            ),
                          );
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              const Divider(height: 1),
              const AppVersionFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
