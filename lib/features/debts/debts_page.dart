import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/debt_installment_repository.dart';
import '../../data/card_statement_logic.dart' show shortStatementDate;
import 'debt_installments_page.dart';
import 'debt_card.dart';
import 'debt_form_dialog.dart';
import 'debt_payment_dialog.dart';
import 'debt_payments_page.dart';
import 'debt_edit_dialog.dart';
import 'debt_due_status.dart';
import 'debts_summary.dart';
import 'loan_simulator_dialog.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key, this.initialSearch = ''});
  final String initialSearch;
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  List<Map<String, dynamic>> debts = [];
  Map<String, int> principalPaid = {};
  bool loading = true, saving = false;
  DebtInstallmentData? installmentData;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    searchController.text = widget.initialSearch;
    loadData();
  }

  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String money(int cents, String currency) => formatMoneyCents(cents, currency);
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String filter = 'all';

  List<Map<String, dynamic>> get visibleDebts {
    final now = DateTime.now();
    final query = searchController.text.trim().toLowerCase();
    return debts.where((debt) {
      if (query.isNotEmpty) {
        final description = debt['description']?.toString().toLowerCase() ?? '';
        final creditor = debt['creditor_name']?.toString().toLowerCase() ?? '';
        if (!description.contains(query) && !creditor.contains(query))
          return false;
      }
      final paid = principalPaid[debt['id'].toString()] ?? 0;
      final due = debtDueStatus(debt, paid, now);
      switch (filter) {
        case 'active':
          return ['active', 'overdue'].contains(debt['status']);
        case 'overdue':
          return due == DebtDueStatus.overdue;
        case 'today':
          return due == DebtDueStatus.today;
        case 'paused':
          return debt['status'] == 'paused';
        case 'paid':
          return debt['status'] == 'paid';
        case 'cancelled':
          return debt['status'] == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> editDebt(Map<String, dynamic> debt) async {
    if (loading || saving) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DebtEditDialog(debt: debt),
    );
    if (data == null || !mounted) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await supabase
          .from('debts')
          .update(data)
          .eq('id', debt['id'])
          .eq('user_id', user.id)
          .select('id')
          .single();
      if (!mounted) return;
      message('Deuda actualizada.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo actualizar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> addPayment(Map<String, dynamic> debt) async {
    if (loading || saving) return;
    if (!['active', 'overdue'].contains(debt['status'])) {
      message('La deuda no admite abonos en su estado actual.');
      return;
    }
    final pending =
        moneyCents(debt['original_amount']) -
        (principalPaid[debt['id'].toString()] ?? 0);
    if (pending < 0) {
      message('Revisa los abonos: superan el capital original.');
      return;
    }
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final rows = await readRows(
        'accounts',
        'id, name, currency, is_active',
        user.id,
      );
      final accounts = rows
          .where(
            (a) => a['is_active'] == true && a['currency'] == debt['currency'],
          )
          .toList();
      if (!mounted) return;
      if (accounts.isEmpty) {
        message('Necesitas una cuenta activa en la misma moneda.');
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => DebtPaymentDialog(
          currency: debt['currency'].toString(),
          remainingCents: pending,
          accounts: accounts,
          installments: installmentData?.payableFor('${debt['id']}') ?? [],
        ),
      );
      if (data == null || !mounted) return;
      final installmentId = data['installment_id'];
      await supabase.rpc(
        installmentId == null
            ? 'register_debt_payment'
            : 'register_debt_payment_for_installment',
        params: {
          'p_debt_id': debt['id'],
          'p_account_id': data['account_id'],
          'p_principal_amount': data['principal_amount'],
          'p_interest_amount': data['interest_amount'],
          'p_fee_amount': data['fee_amount'],
          'p_payment_date': data['payment_date'],
          'p_reference': data['reference'],
          if (installmentId != null) 'p_installment_id': installmentId,
        },
      );
      if (!mounted) return;
      message('Abono registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo guardar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<List<Map<String, dynamic>>> readRows(
    String table,
    String columns,
    String userId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      var query = supabase.from(table).select(columns).eq('user_id', userId);
      if (table == 'debt_payments') query = query.eq('is_voided', false);
      final result = await query.order('id').range(offset, offset + 499);
      final page = List<Map<String, dynamic>>.from(result);
      rows.addAll(page);
      if (page.length < 500) break;
    }
    return rows;
  }

  Future<void> loadData() async {
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final debtRows = await readRows(
        'debts',
        'id, description, creditor_name, currency, original_amount, status, due_date',
        user.id,
      );
      final paymentRows = await readRows(
        'debt_payments',
        'id, debt_id, principal_amount, currency',
        user.id,
      );
      final currencies = {
        for (final debt in debtRows) debt['id'].toString(): debt['currency'],
      };
      final paid = <String, int>{};
      for (final payment in paymentRows) {
        final id = payment['debt_id'].toString();
        if (!currencies.containsKey(id)) continue;
        if (currencies[id] != payment['currency']) {
          throw StateError('Hay un abono con moneda diferente a la deuda.');
        }
        paid[id] = (paid[id] ?? 0) + moneyCents(payment['principal_amount']);
      }
      final schedules = await loadDebtInstallments(user.id);
      if (!mounted || request != requestId) return;
      setState(() {
        debts = debtRows;
        principalPaid = paid;
        installmentData = schedules;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> addDebt() async {
    if (loading || saving) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const DebtFormDialog(),
    );
    if (data == null || !mounted) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await supabase.from('debts').insert({...data, 'user_id': user.id});
      if (!mounted) return;
      message('Deuda registrada.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo guardar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget debtCard(Map<String, dynamic> debt) {
    final paid = principalPaid[debt['id'].toString()] ?? 0;
    final pending = moneyCents(debt['original_amount']) - paid;
    final schedule = installmentData?.payableFor('${debt['id']}') ?? [];
    final next = schedule.isEmpty ? null : schedule.first;
    return DebtCard(
      nextInstallmentLabel:
          next == null || !['active', 'overdue'].contains(debt['status'])
          ? null
          : 'Cuota ${next['number']}: ${formatMoneyCents(installmentData!.progress(next).remaining, '${debt['currency']}')} · ${shortStatementDate(next['due_date'])}',
      onInstallments: saving
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DebtInstallmentsPage(debt: debt),
                ),
              );
              if (mounted) {
                await loadData();
              }
            },
      debt: debt,
      paidCents: paid,
      onEdit: saving ? null : () => editDebt(debt),
      onPayment: saving ? null : () => addPayment(debt),
      onHistory: saving
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DebtPaymentsPage(debtId: debt['id'].toString()),
                ),
              );
              if (mounted) await loadData();
            },
      onSimulate: saving
          ? null
          : () {
              showDialog<void>(
                context: context,
                builder: (_) => LoanSimulatorDialog(
                  principalCents: pending,
                  currency: debt['currency'].toString(),
                ),
              );
            },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Deudas y préstamos'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: loading || saving ? null : loadData,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading || saving || error != null ? null : addDebt,
      icon: const Icon(Icons.add),
      label: Text(saving ? 'Guardando...' : 'Nueva deuda'),
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
                  const Text('No se pudieron cargar las deudas.'),
                  SelectableText(error!),
                  TextButton(
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
                DebtsSummary(debts: debts, principalPaid: principalPaid),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar descripción o acreedor',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => searchController.clear()),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(
                    labelText: 'Mostrar deudas',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(value: 'active', child: Text('Activas')),
                    DropdownMenuItem(
                      value: 'overdue',
                      child: Text('Con capital vencido'),
                    ),
                    DropdownMenuItem(
                      value: 'today',
                      child: Text('Con vencimiento hoy'),
                    ),
                    DropdownMenuItem(value: 'paused', child: Text('Pausadas')),
                    DropdownMenuItem(value: 'paid', child: Text('Pagadas')),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Canceladas'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => filter = value);
                  },
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'El capital pendiente no incluye intereses ni comisiones. Registrar una deuda no modifica tus cuentas.',
                  ),
                ),
                Text('${visibleDebts.length} de ${debts.length} deudas'),
                if (visibleDebts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay deudas para este filtro.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...visibleDebts.map(debtCard),
              ],
            ),
          ),
  );
}
