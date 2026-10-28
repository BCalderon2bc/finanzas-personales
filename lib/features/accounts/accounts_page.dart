import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../data/credit_card_repository.dart';
import '../../data/debt_payment_repository.dart';
import '../../utils/money.dart';
import 'account_form_dialog.dart';
import 'account_wallet.dart';
import 'account_details.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<Map<String, dynamic>> accounts = [];
  Map<String, int> currentBalances = {};
  bool loading = true, saving = false;
  String? error;
  int requestId = 0;

  String? selectedAccountId;

  Map<String, dynamic>? get selectedAccount {
    for (final account in accounts) {
      if (account['id'].toString() == selectedAccountId) {
        return account;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    if (!mounted) return;
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final result = await supabase
          .from('accounts')
          .select(
            'id, name, account_type, currency, opening_balance, '
            'institution_id, account_reference, account_number, account_holder, account_iban, is_active, notes, card_design, '
            'created_at, financial_institutions(name, code)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final accountRows = List<Map<String, dynamic>>.from(result);
      final rows = await loadUserTransactions(user.id);
      final payments = await loadUserCardPayments(user.id);
      final debtPayments = await loadUserDebtPayments(user.id);
      final balances = calculateBalances(
        accountRows,
        rows,
        cardPayments: payments,
        debtPayments: debtPayments,
      );
      if (!mounted || request != requestId) return;

      final sortedAccounts = List<Map<String, dynamic>>.from(result)
        ..sort((a, b) {
          final balanceA = balances[a['id'].toString()] ?? 0;
          final balanceB = balances[b['id'].toString()] ?? 0;
          final hasMoneyA = balanceA > 0;
          final hasMoneyB = balanceB > 0;

          if (hasMoneyA != hasMoneyB) {
            return hasMoneyA ? -1 : 1;
          }

          return a['name'].toString().toLowerCase().compareTo(
            b['name'].toString().toLowerCase(),
          );
        });

      setState(() {
        accounts = sortedAccounts;
        currentBalances = balances;
        if (!accounts.any(
          (account) => account['id'].toString() == selectedAccountId,
        )) {
          selectedAccountId = accounts.isEmpty
              ? null
              : accounts.first['id'].toString();
        }
        loading = false;
      });
    } catch (e) {
      if (!mounted || request != requestId) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> addAccount([Map<String, dynamic>? account]) async {
    if (saving || loading) return;
    final user = supabase.auth.currentUser;
    if (user == null) {
      showMessage('Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }
    setState(() => saving = true);
    try {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => AccountFormDialog(account: account),
      );
      if (data == null || !mounted) return;
      if (supabase.auth.currentUser?.id != user.id) {
        throw StateError('La sesión cambió. Abre nuevamente el formulario.');
      }
      if (account == null) {
        await supabase.from('accounts').insert({...data, 'user_id': user.id});
      } else {
        final changes = <String, dynamic>{
          for (final key in [
            'name',
            'institution_id',
            'account_reference',
            'account_number',
            'account_holder',
            'account_iban',
            'notes',
            'card_design',
            'opening_balance',
          ])
            if (data.containsKey(key)) key: data[key],
        };
        await supabase
            .from('accounts')
            .update(changes)
            .eq('id', account['id'])
            .eq('user_id', user.id)
            .select('id')
            .single();
      }
      if (!mounted) return;
      showMessage(
        account == null
            ? 'Cuenta creada correctamente.'
            : 'Cuenta actualizada correctamente.',
      );
      await loadAccounts();
    } on PostgrestException catch (e) {
      if (mounted) showMessage('Error de base de datos: ${e.message}');
    } catch (e) {
      if (mounted) showMessage('No se pudo guardar la cuenta: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> toggleAccount(Map<String, dynamic> account) async {
    if (saving || loading) return;
    final active = account['is_active'] != true;
    setState(() => saving = true);
    try {
      if (!active) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Desactivar cuenta'),
            content: Text(
              '¿Desactivar "${account['name']}"? Se conserva su historial. '
              'No aparecerá para nuevos movimientos ni en los totales de cuentas activas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Desactivar'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Debes iniciar sesión nuevamente.');
      await supabase
          .from('accounts')
          .update({'is_active': active})
          .eq('id', account['id'])
          .eq('user_id', user.id)
          .select('id')
          .single();
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

  void showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
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
    bottomNavigationBar: MediaQuery.sizeOf(context).width >= 650
        ? null
        : SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: saving || loading || error != null
                  ? null
                  : () => addAccount(),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(saving ? 'Guardando...' : 'Nueva cuenta'),
            ),
          ),
    floatingActionButton: MediaQuery.sizeOf(context).width < 650
        ? null
        : FloatingActionButton.extended(
            onPressed: saving || loading || error != null
                ? null
                : () => addAccount(),
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(saving ? 'Guardando...' : 'Nueva cuenta'),
          ),
    body: SafeArea(top: false, child: _buildBody()),
  );

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: SingleChildScrollView(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 16),
              const Text(
                'Todavía no tienes cuentas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Registra tu banco, cuenta de ahorro o efectivo '
                'para empezar a controlar tu dinero.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : () => addAccount(),
                icon: const Icon(Icons.add),
                label: const Text('Crear primera cuenta'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = selectedAccount;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: loadAccounts,
          child: ListView(
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              16,
              12,
              MediaQuery.sizeOf(context).width < 650 ? 24 : 110,
            ),
            children: [
              AccountWallet(
                accounts: accounts,
                balances: currentBalances,
                selectedId: selectedAccountId,
                onSelected: saving
                    ? null
                    : (id) => setState(() => selectedAccountId = id),
              ),
              const SizedBox(height: 14),
              if (selected != null)
                AccountDetails(
                  account: selected,
                  balanceCents: currentBalances[selected['id'].toString()] ?? 0,
                  onEdit: saving ? null : () => addAccount(selected),
                  onToggle: saving ? null : () => toggleAccount(selected),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
