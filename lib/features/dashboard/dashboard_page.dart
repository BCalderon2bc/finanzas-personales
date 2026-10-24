import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../widgets/dashboard_tile.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../transactions/transactions_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Finanzas'),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mi panel financiero',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Sesión: $email'),
                const SizedBox(height: 24),
                DashboardTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Cuentas y efectivo',
                  subtitle: 'Bancos, efectivo, ahorros y saldos iniciales',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountsPage(),
                      ),
                    );
                  },
                ),
                DashboardTile(
                  icon: Icons.receipt_long,
                  title: 'Ingresos, gastos y transferencias',
                  subtitle: 'Registrar movimientos y consultar saldos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsPage()),
                  ),
                ),
                DashboardTile(
                  icon: Icons.category_outlined,
                  title: 'Categorías',
                  subtitle: 'Organiza tus ingresos y gastos',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesPage())),
                ),
                const DashboardTile(
                  icon: Icons.credit_card,
                  title: 'Deudas y tarjetas',
                  subtitle: 'Préstamos, tarjetas de crédito y cuotas',
                  enabled: false,
                ),
                const DashboardTile(
                  icon: Icons.account_balance,
                  title: 'Presupuestos',
                  subtitle: 'Control mensual de gastos',
                  enabled: false,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Los módulos que aparecen como próximos se habilitarán '
                      'conforme construyamos la aplicación.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
