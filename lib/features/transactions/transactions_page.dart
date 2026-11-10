import '../../utils/card_cash_advance.dart';
import '../../widgets/mobile_navigation.dart';
import '../person_accounts/receipt_history.dart';
import '../person_accounts/receipt_draft_field.dart';
import '../../widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import '../../utils/entry_order.dart';
import '../help/app_help.dart';
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

  ReceiptFilter receiptFilter = ReceiptFilter.all;
  Map<String, int>? receiptCounts;
  int receiptRequest = 0;

  Future<void> refreshReceiptCounts() async {
    final request = ++receiptRequest;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final counts = await loadReceiptCounts(
        uid,
        'movement-receipts',
        allMovements.map(financialReceiptFolder).whereType<String>(),
      );
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = counts);
    } catch (_) {
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = null);
    }
  }

  Future<void> loadData() async {
    if (!mounted) {
      return;
    }
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Debes iniciar sesión nuevamente.');
      }
      final accountRows = await supabase
          .from('accounts')
          .select('id, name, currency, opening_balance, is_active')
          .eq('user_id', user.id)
          .order('name');
      final categoryRows = await supabase
          .from('categories')
          .select('id, name, category_type, is_active, icon, color')
          .eq('user_id', user.id)
          .order('name');
      final transactionRows = await loadUserTransactions(user.id);
      final paymentRows = await loadUserCardPayments(user.id);
      final debtPaymentRows = await loadUserDebtPayments(user.id);
      calculateBalances(
        List<Map<String, dynamic>>.from(accountRows),
        transactionRows,
        cardPayments: paymentRows,
        debtPayments: debtPaymentRows,
      );
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        accounts = List<Map<String, dynamic>>.from(accountRows);
        categories = List<Map<String, dynamic>>.from(categoryRows);
        transactions = List<Map<String, dynamic>>.from(transactionRows);
        cardPayments = paymentRows;
        debtPayments = debtPaymentRows;
        loading = false;
      });
      await refreshReceiptCounts();
    } catch (e) {
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        error = e.toString();
        loading = false;
      });
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
    if (id == null) {
      return null;
    }
    for (final category in categories) {
      if (category['id'].toString() == id.toString()) {
        return category;
      }
    }
    return null;
  }

  String categoryName(String? id) => categoryFor(id)?['name']?.toString() ?? '';

  Future<void> addTransaction([Map<String, dynamic>? transaction]) async {
    if (saving || loading) {
      return;
    }
    final editing = transaction != null;
    if (editing &&
        ![
          'income',
          'expense',
          'transfer',
        ].contains(transaction['transaction_type'])) {
      message(
        'La edición está disponible para ingresos, gastos y transferencias.',
      );
      return;
    }
    final availableAccounts = accounts
        .where(
          (a) =>
              a['is_active'] == true ||
              (editing &&
                  (a['id'].toString() ==
                          transaction['account_id']?.toString() ||
                      a['id'].toString() ==
                          transaction['destination_account_id']?.toString())),
        )
        .toList();
    if (availableAccounts.isEmpty) {
      message('Primero crea una cuenta activa.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TransactionFormDialog(
        transaction: transaction,
        accounts: availableAccounts,
        categories: categories
            .where(
              (c) =>
                  c['is_active'] == true ||
                  (editing &&
                      c['id'].toString() ==
                          transaction['category_id']?.toString()),
            )
            .toList(),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      return;
    }
    setState(() => saving = true);
    try {
      final fx =
          transaction?['source'] == 'fx_transfer' ||
          result['destination_currency'] != null;
      final table = fx ? 'app_fx_transfers' : 'transactions';
      if (transaction == null) {
        final receipt = result.remove(receiptDraftKey) as PendingReceipt?;
        final payload = <String, dynamic>{...result, 'user_id': user.id};
        if (fx) {
          payload.remove('transaction_type');
          payload.remove('category_id');
        }
        final insert = supabase.from(table).insert(payload);
        if (receipt == null) {
          await insert;
        } else {
          final saved = await insert.select('id').single();
          if (mounted)
            await attachFinancialReceipt(
              context,
              receipt,
              user.id,
              table,
              saved['id'],
            );
        }
      } else {
        final changes = <String, dynamic>{
          for (final key in [
            'amount',
            if (!fx) 'category_id',
            'description',
            if (!fx) 'expense_kind',
            'reference',
            if (fx) ...['exchange_rate', 'destination_amount'],
          ])
            key: result[key],
        };
        final originalDate = DateTime.parse(
          transaction['transaction_date'].toString(),
        ).toLocal();
        final selectedDate = DateTime.parse(
          result['transaction_date'].toString(),
        ).toLocal();
        if (originalDate.year != selectedDate.year ||
            originalDate.month != selectedDate.month ||
            originalDate.day != selectedDate.day) {
          changes['transaction_date'] = result['transaction_date'];
        }
        final updated = await supabase
            .from(table)
            .update(changes)
            .eq('id', transaction['id'])
            .eq('user_id', user.id)
            .eq('is_reconciled', false)
            .select('id');
        if (updated.isEmpty) {
          throw StateError(
            'No se actualizó: puede estar conciliado, ya no existir o faltar permisos.',
          );
        }
      }
      if (!mounted) {
        return;
      }
      message(
        editing
            ? 'Movimiento actualizado.'
            : 'Movimiento guardado correctamente.',
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        message('Error de base de datos: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        message('No se pudo guardar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> deleteTransaction(Map<String, dynamic> tx) async {
    if (saving || loading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
          '¿Eliminar este movimiento? Se actualizarán los saldos de las cuentas involucradas. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      return;
    }
    setState(() => saving = true);
    try {
      final deleted = await supabase
          .from(
            tx['source'] == 'fx_transfer' ? 'app_fx_transfers' : 'transactions',
          )
          .delete()
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('is_reconciled', false)
          .select('id');
      if (!mounted) {
        return;
      }
      message(
        deleted.isEmpty
            ? 'No se eliminó: puede estar conciliado, ya no existir o faltar permisos.'
            : 'Movimiento eliminado.',
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        message('No se pudo eliminar: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        message('No se pudo eliminar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
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
          'description': name.isEmpty
              ? 'Pago de tarjeta'
              : 'Pago de tarjeta: $name',
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
          'description': name.isEmpty
              ? 'Abono de deuda'
              : 'Abono de deuda: $name',
          'source': 'debt_payment',
        };
      }),
    ];
    rows.sort(compareNewestEntry);
    return rows;
  }

  Future<void> toggleReconciliation(Map<String, dynamic> tx) async {
    if (saving ||
        loading ||
        [
          'credit_card_payment',
          'debt_payment',
          'receivable_loan',
          cashAdvanceDepositSource,
        ].contains(tx['source'])) {
      return;
    }
    final reconciled = tx['is_reconciled'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reconciled ? 'Quitar conciliación' : 'Conciliar movimiento',
        ),
        content: Text(
          reconciled
              ? 'El movimiento volverá a permitir edición y eliminación.'
              : 'Confirma que verificaste este movimiento contra tu estado de cuenta. '
                    'Quedará protegido contra edición y eliminación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      return;
    }
    setState(() => saving = true);
    try {
      final updated = await supabase
          .from(
            tx['source'] == 'fx_transfer' ? 'app_fx_transfers' : 'transactions',
          )
          .update({'is_reconciled': !reconciled})
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('is_reconciled', reconciled)
          .select('id');
      if (!mounted) {
        return;
      }
      message(
        updated.isEmpty
            ? 'No se actualizó. Revisa los permisos o si el registro cambió.'
            : reconciled
            ? 'Conciliación retirada.'
            : 'Movimiento conciliado.',
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        message('No se pudo actualizar: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        message('No se pudo actualizar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _buildBalanceCards() {
    final balances = calculateBalances(
      accounts,
      transactions,
      cardPayments: cardPayments,
      debtPayments: debtPayments,
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
    final external = [
      'credit_card_payment',
      'debt_payment',
      'receivable_loan',
      cashAdvanceDepositSource,
    ].contains(tx['source']);
    final reconciled = tx['is_reconciled'] == true;
    return TransactionTile(
      transaction: tx,
      receiptCount: receiptCounts?[financialReceiptFolder(tx)] ?? 0,
      label: tx['expense_kind'] == 'card_insurance'
          ? 'Seguro de tarjeta'
          : typeLabel(tx['transaction_type']?.toString()),
      account: accountName(tx['account_id']?.toString()),
      destination: accountName(tx['destination_account_id']?.toString()),
      category: categoryName(tx['category_id']?.toString()),
      categoryStyle: categoryFor(tx['category_id']),
      onTap: saving
          ? null
          : () async {
              await showDialog<void>(
                context: context,
                builder: (dialogContext) => TransactionDetailsDialog(
                  transaction: tx,
                  account: accountName(tx['account_id']?.toString()),
                  destination: accountName(
                    tx['destination_account_id']?.toString(),
                  ),
                  category: categoryName(tx['category_id']?.toString()),
                  onEdit: external || reconciled
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          addTransaction(tx);
                        },
                  onDelete: external || reconciled
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          deleteTransaction(tx);
                        },
                  onReconcile: external
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          toggleReconciliation(tx);
                        },
                ),
              );
              if (mounted) await refreshReceiptCounts();
            },
    );
  }

  // Sin agrupar por fecha efectiva: un registro retroactivo recién ingresado
  // debe conservarse antes de los registros anteriores.
  List<Widget> _historyRows(List<Map<String, dynamic>> rows) {
    return [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Últimos ingresados primero',
          style: TextStyle(fontSize: 12),
        ),
      ),
      for (final row in rows) _transactionCard(row),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final compact = compactLayout(context);
    final gutter = pageGutter(context);
    final VoidCallback? add = saving || loading || error != null
        ? null
        : () => addTransaction();
    final label = saving ? 'Guardando...' : 'Nuevo movimiento';
    final movements = allMovements;
    final visibleTransactions = movements
        .where(
          (row) =>
              filter.matches(row) &&
              (receiptCounts == null ||
                  receiptFilter.matches(
                    receiptCounts?[financialReceiptFolder(row)] ?? 0,
                  )),
        )
        .toList();
    return GuideScope(
      topic: 'movements',
      ready: !loading && error == null,
      child: Scaffold(
        appBar: AppBar(
          title: GuideAnchor(id: 'title', child: const Text('Movimientos')),
          actions: [
            const AppHelpButton(topic: 'movements'),
            IconButton(
              tooltip: 'Categorías',
              icon: const Icon(Icons.category_outlined),
              onPressed: loading || saving
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CategoriesPage(),
                        ),
                      );
                      if (mounted) {
                        await loadData();
                      }
                    },
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: loading || saving ? null : loadData,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuideAnchor(
                    id: 'add',
                    child: CompactActionBar(label: label, onPressed: add),
                  ),
                  const MobileNavigation(index: 1),
                ],
              )
            : null,
        floatingActionButton: compact
            ? null
            : GuideAnchor(
                id: 'add',
                child: FloatingActionButton.extended(
                  onPressed: add,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(label),
                ),
              ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: SingleChildScrollView(
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
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: widePageMaxWidth),
                  child: RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        16,
                        gutter,
                        compact ? 24 : 100,
                      ),
                      children: [
                        GuideAnchor(
                          id: 'balances',
                          child: _buildBalanceCards(),
                        ),
                        const SizedBox(height: 16),
                        GuideAnchor(
                          id: 'filters',
                          child: TransactionFiltersBar(
                            accounts: accounts,
                            value: filter,
                            receiptFilter: receiptCounts == null
                                ? null
                                : receiptFilter,
                            onReceiptChanged: (value) =>
                                setState(() => receiptFilter = value),
                            onChanged: (value) =>
                                setState(() => filter = value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            '${visibleTransactions.length} de ${movements.length} movimientos',
                            style: const TextStyle(
                              color: Color(0xFF596B7D),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visibleTransactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'No hay movimientos para mostrar.',
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'Revisa los filtros o registra un movimiento.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ..._historyRows(visibleTransactions),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
