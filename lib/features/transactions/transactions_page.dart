import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../utils/money.dart';
import '../categories/categories_page.dart';
import 'transaction_form_dialog.dart';
import 'transaction_filter.dart';
import 'transaction_filters_bar.dart';
import 'transaction_details_dialog.dart';
import '../../data/credit_card_repository.dart';
import '../../data/debt_payment_repository.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool loading = true;
  bool saving = false;
  String? error;
  TransactionFilter filter = const TransactionFilter();
  int filterVersion = 0;

  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> cardPayments = [];
  List<Map<String, dynamic>> debtPayments = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
      filter = const TransactionFilter();
      filterVersion++;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final accountRows = await supabase
          .from('accounts')
          .select('id, name, currency, opening_balance, is_active')
          .eq('user_id', user.id)
          .order('name');

      final categoryRows = await supabase
          .from('categories')
          .select('id, name, category_type, is_active')
          .eq('user_id', user.id)
          .order('name');

      final transactionRows = await loadUserTransactions(user.id);
      final paymentRows = await loadUserCardPayments(user.id);
      final debtPaymentRows = await loadUserDebtPayments(user.id);
      calculateBalances(
        List<Map<String, dynamic>>.from(accountRows), transactionRows,
        cardPayments: paymentRows, debtPayments: debtPaymentRows,
      );

      if (!mounted) return;
      setState(() {
        accounts = List<Map<String, dynamic>>.from(accountRows);
        categories = List<Map<String, dynamic>>.from(categoryRows);
        transactions = List<Map<String, dynamic>>.from(transactionRows);
        cardPayments = paymentRows;
        debtPayments = debtPaymentRows;
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

  String currencySymbol(String? currency) =>
      currency == 'USD' ? 'US\$' : 'C\$';

  String typeLabel(String? type) {
    switch (type) {
      case 'income':
        return 'Ingreso';
      case 'expense':
        return 'Gasto';
      case 'transfer':
        return 'Transferencia';
      case 'deposit':
        return 'Depósito';
      case 'withdrawal':
        return 'Retiro';
      case 'card_payment':
        return 'Pago de tarjeta';
      case 'debt_payment':
        return 'Abono de deuda';
      default:
        return type ?? 'Movimiento';
    }
  }

  String accountName(String? id) {
    for (final account in accounts) {
      if (account['id'].toString() == id) {
        return account['name']?.toString() ?? 'Cuenta';
      }
    }
    return 'Cuenta eliminada';
  }

  String categoryName(String? id) {
    for (final category in categories) {
      if (category['id'].toString() == id) {
        return category['name']?.toString() ?? '';
      }
    }
    return '';
  }

  Future<void> addTransaction([Map<String, dynamic>? transaction]) async {
    if (saving || loading) return;
    final editing = transaction != null;
    if (editing && !['income', 'expense', 'transfer'].contains(transaction['transaction_type'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La edición está disponible para ingresos, gastos y transferencias.')),
      );
      return;
    }
    final availableAccounts = accounts.where((a) =>
    a['is_active'] == true || (editing &&
        (a['id'].toString() == transaction['account_id']?.toString() ||
            a['id'].toString() == transaction['destination_account_id']?.toString()))
    ).toList();
    if (availableAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea una cuenta activa.')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TransactionFormDialog(
        transaction: transaction,
        accounts: availableAccounts,
        categories: categories.where((c) => c['is_active'] == true ||
            (editing && c['id'].toString() == transaction['category_id']?.toString())).toList(),
      ),
    );
    if (result == null || !mounted) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      if (transaction == null) {
        await supabase.from('transactions').insert({...result, 'user_id': user.id});
      } else {
        final changes = <String, dynamic>{
          for (final key in ['amount', 'category_id', 'description', 'reference']) key: result[key],
        };
        final originalDate = DateTime.parse(transaction['transaction_date'].toString()).toLocal();
        final selectedDate = DateTime.parse(result['transaction_date'].toString()).toLocal();
        if (originalDate.year != selectedDate.year || originalDate.month != selectedDate.month ||
            originalDate.day != selectedDate.day) {
          changes['transaction_date'] = result['transaction_date'];
        }
        final updated = await supabase.from('transactions').update(changes)
            .eq('id', transaction['id']).eq('user_id', user.id)
            .eq('is_reconciled', false).select('id');
        if (updated.isEmpty) {
          throw StateError('No se actualizó: puede estar conciliado, ya no existir o faltar permisos.');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(editing ? 'Movimiento actualizado.' : 'Movimiento guardado correctamente.'),
      ));
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de base de datos: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteTransaction(Map<String, dynamic> tx) async {
    if (saving || loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
          '¿Eliminar este movimiento? Se actualizarán los saldos de las cuentas involucradas. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final deleted = await supabase.from('transactions').delete()
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('is_reconciled', false)
          .select('id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(deleted.isEmpty
            ? 'No se eliminó: puede estar conciliado, ya no existir o faltar permisos.'
            : 'Movimiento eliminado.'),
      ));
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<Map<String, dynamic>> get allMovements {
    final rows = [
      ...transactions,
      ...cardPayments.map((payment) {
        final card = payment['credit_cards'];
        final name = card is Map ? card['name']?.toString() ?? '' : '';
        return <String, dynamic>{
          ...payment,
          'transaction_type': 'card_payment',
          'description': name.isEmpty ? 'Pago de tarjeta' : 'Pago de tarjeta: $name',
          'source': 'credit_card_payment',

        };
      }),
      ...debtPayments.where((p) => p['account_id'] != null).map((payment) {
        final debt = payment['debts'];
        final name = debt is Map ? debt['description']?.toString() ?? '' : '';
        return <String, dynamic>{
          ...payment,
          'transaction_type': 'debt_payment',
          'transaction_date': payment['payment_date'],
          'amount': debtPaymentTotalCents(payment) / 100,
          'description': name.isEmpty ? 'Abono de deuda' : 'Abono de deuda: $name',
          'source': 'debt_payment',
        };
      }),
    ];
    rows.sort((a, b) {
      final first = DateTime.tryParse('${a['transaction_date']}');
      final second = DateTime.tryParse('${b['transaction_date']}');
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      final byDate = second.compareTo(first);
      return byDate != 0 ? byDate : a['id'].toString().compareTo(b['id'].toString());
    });
    return rows;
  }

  Future<void> toggleReconciliation(Map<String, dynamic> tx) async {
    if (saving || loading ||
        ['credit_card_payment', 'debt_payment'].contains(tx['source'])) return;
    final reconciled = tx['is_reconciled'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reconciled ? 'Quitar conciliación' : 'Conciliar movimiento'),
        content: Text(reconciled
            ? 'El movimiento volverá a permitir edición y eliminación.'
            : 'Confirma que verificaste este movimiento contra tu estado de cuenta. Quedará protegido contra edición y eliminación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final updated = await supabase.from('transactions')
          .update({'is_reconciled': !reconciled})
          .eq('id', tx['id']).eq('user_id', user.id)
          .eq('is_reconciled', reconciled).select('id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated.isEmpty
            ? 'No se actualizó. Revisa los permisos o si el registro cambió.'
            : reconciled ? 'Conciliación retirada.' : 'Movimiento conciliado.'),
      ));
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movements = allMovements;
    final visibleTransactions = movements.where(filter.matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            tooltip: 'Categorías', icon: const Icon(Icons.category_outlined),
            onPressed: loading || saving ? null : () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesPage()));
              if (mounted) await loadData();
            },
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving || loading ? null : addTransaction,
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(saving ? 'Guardando...' : 'Nuevo movimiento'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        const Text('No se pudieron cargar los movimientos'),
                        const SizedBox(height: 8),
                        SelectableText(error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: loadData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _buildBalanceCards(),
                      const SizedBox(height: 16),
                      TransactionFiltersBar(
                        key: ValueKey(filterVersion), accounts: accounts,
                        onChanged: (value) => setState(() => filter = value),
                      ),
                      Text('${visibleTransactions.length} de ${movements.length} movimientos'),
                      const SizedBox(height: 12),
                      if (visibleTransactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48),
                              SizedBox(height: 12),
                              Text('No hay movimientos para mostrar.'),
                              Text('Revisa los filtros o registra un movimiento.'),
                            ],
                          ),
                        )
                      else
                        ...visibleTransactions.map(_transactionCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCards() {
    final balances = calculateBalances(
      accounts, transactions, cardPayments: cardPayments, debtPayments: debtPayments,
    );
    int nioCents = 0;
    int usdCents = 0;
    for (final account in accounts.where((a) => a['is_active'] == true)) {
      final balance = balances[account['id'].toString()] ?? 0;
      if (account['currency'] == 'USD') {
        usdCents += balance;
      } else {
        nioCents += balance;
      }
    }
    final nio = nioCents / 100;
    final usd = usdCents / 100;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Córdobas · cuentas activas'),
                  const SizedBox(height: 8),
                  Text(
                    'C\$ ${nio.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dólares · cuentas activas'),
                  const SizedBox(height: 8),
                  Text(
                    'US\$ ${usd.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final type = tx['transaction_type']?.toString();
    final amount = double.tryParse('${tx['amount'] ?? 0}') ?? 0;
    final currency = tx['currency']?.toString() ?? 'NIO';
    final date = DateTime.tryParse('${tx['transaction_date'] ?? ''}')?.toLocal();
    final dateText = date == null
        ? '${tx['transaction_date'] ?? ''}'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final description = tx['description']?.toString().trim() ?? '';
    final isIncome = type == 'income' || type == 'deposit';
    final isExpense = ['expense', 'withdrawal', 'card_payment', 'debt_payment'].contains(type);
    final isExternalPayment = ['credit_card_payment', 'debt_payment'].contains(tx['source']);
    final isReconciled = tx['is_reconciled'] == true;

    return Card(
      child: ListTile(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => TransactionDetailsDialog(
            transaction: tx,
            account: accountName(tx['account_id']?.toString()),
            destination: accountName(tx['destination_account_id']?.toString()),
            category: categoryName(tx['category_id']?.toString()),
            onEdit: isExternalPayment || isReconciled ? null : () {
              Navigator.pop(context);
              addTransaction(tx);
            },
            onDelete: isExternalPayment || isReconciled ? null : () {
              Navigator.pop(context);
              deleteTransaction(tx);
            },
            onReconcile: isExternalPayment ? null : () {
              Navigator.pop(context);
              toggleReconciliation(tx);
            },
          ),
        ),
        leading: Tooltip(
          message: isExternalPayment ? 'Pago vinculado'
              : isReconciled ? 'Conciliado' : 'Pendiente de conciliar',
          child: CircleAvatar(child: Icon(
            isReconciled ? Icons.verified_outlined
                : isIncome ? Icons.arrow_downward
                : isExpense ? Icons.arrow_upward : Icons.swap_horiz,
          )),
        ),
        title: Text(
          description.isEmpty ? typeLabel(type) : description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$dateText • ${accountName(tx['account_id']?.toString())}'
          '${type == 'transfer' ? ' → ${accountName(tx['destination_account_id']?.toString())}' : ''}'
          '${tx['category_id'] == null ? '' : '\n${categoryName(tx['category_id']?.toString())}'}',
        ),
        isThreeLine: tx['category_id'] != null || type == 'transfer',
        trailing: Text(
          '${isIncome ? '+' : isExpense ? '−' : ''}${currencySymbol(currency)} ${amount.toStringAsFixed(2)}',
          textAlign: TextAlign.end,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome
                ? Colors.green
                : isExpense
                    ? Theme.of(context).colorScheme.error
                    : null,
          ),
        ),
      ),
    );
  }
}
