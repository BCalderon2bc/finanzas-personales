import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../data/transaction_repository.dart';
import '../../data/credit_card_repository.dart';
import '../../data/debt_payment_repository.dart';
import '../../utils/money.dart';
import '../categories/categories_page.dart';
import 'transaction_form_dialog.dart';
import 'transaction_filter.dart';
import 'transaction_filters_bar.dart';
import 'transaction_details_dialog.dart';
import 'transaction_tile.dart';
import 'transaction_balances.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool loading = true, saving = false;
  String? error;
  TransactionFilter filter = const TransactionFilter();
  int requestId = 0;
  List<Map<String, dynamic>> accounts = [], categories = [], transactions = [];
  List<Map<String, dynamic>> cardPayments = [], debtPayments = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> loadData() async {
    if (!mounted) { return; }
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) { throw Exception('Debes iniciar sesión nuevamente.'); }
      final accountRows = await supabase.from('accounts')
          .select('id, name, currency, opening_balance, is_active')
          .eq('user_id', user.id).order('name');
      final categoryRows = await supabase.from('categories')
          .select('id, name, category_type, is_active, icon, color')
          .eq('user_id', user.id).order('name');
      final transactionRows = await loadUserTransactions(user.id);
      final paymentRows = await loadUserCardPayments(user.id);
      final debtPaymentRows = await loadUserDebtPayments(user.id);
      calculateBalances(
        List<Map<String, dynamic>>.from(accountRows), transactionRows,
        cardPayments: paymentRows, debtPayments: debtPaymentRows,
      );
      if (!mounted || request != requestId) { return; }
      setState(() {
        accounts = List<Map<String, dynamic>>.from(accountRows);
        categories = List<Map<String, dynamic>>.from(categoryRows);
        transactions = List<Map<String, dynamic>>.from(transactionRows);
        cardPayments = paymentRows;
        debtPayments = debtPaymentRows;
        loading = false;
      });
    } catch (e) {
      if (!mounted || request != requestId) { return; }
      setState(() { error = e.toString(); loading = false; });
    }
  }

  String typeLabel(String? type) => switch (type) {
    'income' => 'Ingreso',
    'expense' => 'Gasto',
    'transfer' => 'Transferencia',
    'deposit' => 'Depósito',
    'withdrawal' => 'Retiro',
    'card_payment' => 'Pago de tarjeta',
    'debt_payment' => 'Abono de deuda',
    'adjustment' => 'Ajuste',
    _ => type ?? 'Movimiento',
  };

  String accountName(String? id) {
    for (final account in accounts) {
      if (account['id'].toString() == id) {
        return account['name']?.toString() ?? 'Cuenta';
      }
    }
    return 'Cuenta no disponible';
  }

  Map<String, dynamic>? categoryFor(dynamic id) {
    if (id == null) { return null; }
    for (final category in categories) {
      if (category['id'].toString() == id.toString()) { return category; }
    }
    return null;
  }

  String categoryName(String? id) => categoryFor(id)?['name']?.toString() ?? '';

  Future<void> addTransaction([Map<String, dynamic>? transaction]) async {
    if (saving || loading) { return; }
    final editing = transaction != null;
    if (editing && !['income', 'expense', 'transfer'].contains(transaction['transaction_type'])) {
      message('La edición está disponible para ingresos, gastos y transferencias.');
      return;
    }
    final availableAccounts = accounts.where((a) =>
    a['is_active'] == true || (editing &&
        (a['id'].toString() == transaction['account_id']?.toString() ||
            a['id'].toString() == transaction['destination_account_id']?.toString()))
    ).toList();
    if (availableAccounts.isEmpty) {
      message('Primero crea una cuenta activa.');
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
    if (result == null || !mounted) { return; }
    final user = supabase.auth.currentUser;
    if (user == null) { return; }
    setState(() => saving = true);
    try {
      if (transaction == null) {
        await supabase.from('transactions').insert({...result, 'user_id': user.id});
      } else {
        final changes = <String, dynamic>{
          for (final key in ['amount', 'category_id', 'description', 'reference'])
            key: result[key],
        };
        final originalDate = DateTime.parse(transaction['transaction_date'].toString()).toLocal();
        final selectedDate = DateTime.parse(result['transaction_date'].toString()).toLocal();
        if (originalDate.year != selectedDate.year ||
            originalDate.month != selectedDate.month ||
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
      if (!mounted) { return; }
      message(editing ? 'Movimiento actualizado.' : 'Movimiento guardado correctamente.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) { message('Error de base de datos: ${e.message}'); }
    } catch (e) {
      if (mounted) { message('No se pudo guardar: $e'); }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  Future<void> deleteTransaction(Map<String, dynamic> tx) async {
    if (saving || loading) { return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
            '¿Eliminar este movimiento? Se actualizarán los saldos de las cuentas involucradas. '
                'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) { return; }
    final user = supabase.auth.currentUser;
    if (user == null) { return; }
    setState(() => saving = true);
    try {
      final deleted = await supabase.from('transactions').delete()
          .eq('id', tx['id']).eq('user_id', user.id)
          .eq('is_reconciled', false).select('id');
      if (!mounted) { return; }
      message(deleted.isEmpty
          ? 'No se eliminó: puede estar conciliado, ya no existir o faltar permisos.'
          : 'Movimiento eliminado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) { message('No se pudo eliminar: ${e.message}'); }
    } catch (e) {
      if (mounted) { message('No se pudo eliminar: $e'); }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  List<Map<String, dynamic>> get allMovements {
    final rows = <Map<String, dynamic>>[
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
      if (first == null) { return second == null ? 0 : 1; }
      if (second == null) { return -1; }
      final byDate = second.compareTo(first);
      return byDate != 0 ? byDate : a['id'].toString().compareTo(b['id'].toString());
    });
    return rows;
  }

  Future<void> toggleReconciliation(Map<String, dynamic> tx) async {
    if (saving || loading ||
        ['credit_card_payment', 'debt_payment', 'receivable_loan'].contains(tx['source'])) { return; }
    final reconciled = tx['is_reconciled'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reconciled ? 'Quitar conciliación' : 'Conciliar movimiento'),
        content: Text(reconciled
            ? 'El movimiento volverá a permitir edición y eliminación.'
            : 'Confirma que verificaste este movimiento contra tu estado de cuenta. '
            'Quedará protegido contra edición y eliminación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) { return; }
    final user = supabase.auth.currentUser;
    if (user == null) { return; }
    setState(() => saving = true);
    try {
      final updated = await supabase.from('transactions')
          .update({'is_reconciled': !reconciled})
          .eq('id', tx['id']).eq('user_id', user.id)
          .eq('is_reconciled', reconciled).select('id');
      if (!mounted) { return; }
      message(updated.isEmpty
          ? 'No se actualizó. Revisa los permisos o si el registro cambió.'
          : reconciled ? 'Conciliación retirada.' : 'Movimiento conciliado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) { message('No se pudo actualizar: ${e.message}'); }
    } catch (e) {
      if (mounted) { message('No se pudo actualizar: $e'); }
    } finally {
      if (mounted) { setState(() => saving = false); }
    }
  }

  Widget _buildBalanceCards() {
    final balances = calculateBalances(
      accounts, transactions,
      cardPayments: cardPayments, debtPayments: debtPayments,
    );
    int nioCents = 0, usdCents = 0;
    for (final account in accounts.where((a) => a['is_active'] == true)) {
      final balance = balances[account['id'].toString()] ?? 0;
      if (account['currency'] == 'USD') {
        usdCents += balance;
      } else {
        nioCents += balance;
      }
    }
    return TransactionBalances(nioCents: nioCents, usdCents: usdCents);
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final external = ['credit_card_payment', 'debt_payment', 'receivable_loan'].contains(tx['source']);
    final reconciled = tx['is_reconciled'] == true;
    return TransactionTile(
      transaction: tx,
      label: typeLabel(tx['transaction_type']?.toString()),
      account: accountName(tx['account_id']?.toString()),
      destination: accountName(tx['destination_account_id']?.toString()),
      category: categoryName(tx['category_id']?.toString()),
      categoryStyle: categoryFor(tx['category_id']),
      onTap: saving ? null : () => showDialog<void>(
        context: context,
        builder: (dialogContext) => TransactionDetailsDialog(
          transaction: tx,
          account: accountName(tx['account_id']?.toString()),
          destination: accountName(tx['destination_account_id']?.toString()),
          category: categoryName(tx['category_id']?.toString()),
          onEdit: external || reconciled ? null : () {
            Navigator.pop(dialogContext);
            addTransaction(tx);
          },
          onDelete: external || reconciled ? null : () {
            Navigator.pop(dialogContext);
            deleteTransaction(tx);
          },
          onReconcile: external ? null : () {
            Navigator.pop(dialogContext);
            toggleReconciliation(tx);
          },
        ),
      ),
    );
  }

  List<Widget> _groupedTransactions(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final dates = <String, DateTime>{};
    for (final tx in rows) {
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      final key = date == null ? 'invalid' : '${date.year}-${date.month}-${date.day}';
      groups.putIfAbsent(key, () => []).add(tx);
      if (date != null) {
        dates[key] = DateTime(date.year, date.month, date.day);
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final widgets = <Widget>[];
    for (final group in groups.entries) {
      final date = dates[group.key];
      var title = 'Fecha no disponible';
      if (date != null) {
        title = date == today ? 'Hoy' : date == yesterday ? 'Ayer'
            : '${date.day} de ${months[date.month - 1]} de ${date.year}';
      }
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(
              color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w700))),
          Text('${group.value.length} movimientos',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ]),
      ));
      widgets.addAll(group.value.map(_transactionCard));
    }
    return widgets;
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
            tooltip: 'Categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: loading || saving ? null : () async {
              await Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => const CategoriesPage()));
              if (mounted) { await loadData(); }
            },
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving || loading || error != null ? null : () => addTransaction(),
        icon: saving
            ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(saving ? 'Guardando...' : 'Nuevo movimiento'),
      ),
      body: loading ? const Center(child: CircularProgressIndicator())
          : error != null ? Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar los movimientos'),
          const SizedBox(height: 8),
          SelectableText(error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: loadData, child: const Text('Reintentar')),
        ]),
      ))
          : RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _buildBalanceCards(),
            const SizedBox(height: 16),
            TransactionFiltersBar(
              accounts: accounts,
              value: filter,
              onChanged: (value) => setState(() => filter = value),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                  '${visibleTransactions.length} de ${movements.length} movimientos',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ),
            const SizedBox(height: 12),
            if (visibleTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.receipt_long_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('No hay movimientos para mostrar.',
                      textAlign: TextAlign.center),
                  Text('Revisa los filtros o registra un movimiento.',
                      textAlign: TextAlign.center),
                ]),
              )
            else
              ..._groupedTransactions(visibleTransactions),
          ],
        ),
      ),
    );
  }
}