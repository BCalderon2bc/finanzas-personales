import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../utils/money.dart';
import 'account_form_dialog.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<Map<String, dynamic>> accounts = [];
  Map<String, int> currentBalances = {};

  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Debes iniciar sesión nuevamente.');
      }

      final result = await supabase
          .from('accounts')
          .select(
        'id, name, account_type, currency, opening_balance, '
            'institution_id, account_reference, is_active, notes, '
            'created_at, financial_institutions(name)',
      )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final rows = await loadUserTransactions(user.id);
      final balances = calculateBalances(
        List<Map<String, dynamic>>.from(result), rows,
      );
      if (!mounted) return;

      setState(() {
        currentBalances = balances;
        accounts = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> addAccount([Map<String, dynamic>? account]) async {
    if (saving || loading) return;

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AccountFormDialog(account: account),
    );

    if (data == null || !mounted) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }

    setState(() => saving = true);

    try {
      if (account == null) {
        await supabase.from('accounts').insert({...data, 'user_id': user.id});
      } else {
        final changes = <String, dynamic>{
          for (final key in ['name', 'institution_id', 'account_reference', 'notes']) key: data[key],
        };
        await supabase.from('accounts').update(changes).eq('id', account['id'])
            .eq('user_id', user.id).select('id').single();
      }

      if (!mounted) return;

      showMessage(account == null ? 'Cuenta creada correctamente.' : 'Cuenta actualizada correctamente.');

      await loadAccounts();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      showMessage('Error de base de datos: ${e.message}');
    } catch (e) {
      if (!mounted) return;

      showMessage('No se pudo guardar la cuenta: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> toggleAccount(Map<String, dynamic> account) async {
    if (saving || loading) return;
    final active = account['is_active'] != true;
    if (!active) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Desactivar cuenta'),
        content: Text('¿Desactivar "${account['name']}"? Se conserva su historial. No aparecerá para nuevos movimientos ni en los totales de cuentas activas.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desactivar'))],
      ));
      if (confirmed != true || !mounted) return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) { showMessage('Debes iniciar sesión nuevamente.'); return; }
    setState(() => saving = true);
    try {
      await supabase.from('accounts').update({'is_active': active}).eq('id', account['id'])
          .eq('user_id', user.id).select('id').single();
      if (!mounted) return;
      showMessage(active ? 'Cuenta activada.' : 'Cuenta desactivada.');
      await loadAccounts();
    } on PostgrestException catch (e) {
      if (mounted) showMessage('No se pudo actualizar: ${e.message}');
    } catch (e) {
      if (mounted) showMessage('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String formatBalance(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;

    return amount.toStringAsFixed(2);
  }

  String accountTypeLabel(String? type) {
    switch (type) {
      case 'savings':
        return 'Ahorro';
      case 'checking':
        return 'Cuenta corriente';
      case 'cash':
        return 'Efectivo';
      case 'wallet':
        return 'Billetera digital';
      case 'investment':
        return 'Inversión';
      case 'other':
        return 'Otra cuenta';
      default:
        return type ?? 'Cuenta';
    }
  }

  IconData accountIcon(String? type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'checking':
        return Icons.account_balance_outlined;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis cuentas'),
        actions: [
          IconButton(
            onPressed: loading || saving ? null : loadAccounts,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving || loading ? null : () => addAccount(),
        icon: saving
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.add),
        label: Text(saving ? 'Guardando...' : 'Nueva cuenta'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No se pudieron cargar las cuentas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SelectableText(error!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loadAccounts,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Todavía no tienes cuentas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Registra tu banco, cuenta de ahorro o efectivo '
                    'para empezar a controlar tu dinero.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving || loading ? null : () => addAccount(),
                icon: const Icon(Icons.add),
                label: const Text('Crear primera cuenta'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadAccounts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final account = accounts[index];

          final currency = account['currency']?.toString() ?? 'NIO';
          final symbol = currency == 'USD' ? 'US\$' : 'C\$';
          final name = account['name']?.toString() ?? 'Cuenta';
          final type = account['account_type']?.toString();
          final balance = formatBalance(
            account['opening_balance'] ?? 0,
          );

          final institutionData = account['financial_institutions'];
          String? institutionName;

          if (institutionData is Map) {
            institutionName = institutionData['name']?.toString();
          }

          final isActive = account['is_active'] != false;

          return Card(
            child: ListTile(
              onTap: saving ? null : () => addAccount(account),
              trailing: PopupMenuButton<String>(
                enabled: !saving, tooltip: 'Opciones de la cuenta',
                onSelected: (value) {
                  if (value == 'edit') { addAccount(account); } else { toggleAccount(account); }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Desactivar' : 'Activar')),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                child: Icon(accountIcon(type)),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accountTypeLabel(type)),
                  if (institutionName != null)
                    Text(institutionName),
                  Text(isActive ? 'Activa' : 'Inactiva'),
                  if ((account['account_reference']?.toString() ?? '').isNotEmpty)
                    Text('Referencia: ${account['account_reference']}'),
                  if ((account['notes']?.toString() ?? '').isNotEmpty) Text(account['notes'].toString()),
                  Text('Saldo inicial: $symbol $balance'),
                  Text(
                    'Saldo actual: $symbol '
                    '${((currentBalances[account['id'].toString()] ?? 0) / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
