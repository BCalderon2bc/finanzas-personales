import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/receivable_loan_repository.dart';
import '../../data/receivable_loan_logic.dart';
import '../../widgets/void_payment_dialog.dart';
import 'receivable_loan_dialogs.dart';
import 'receivable_loans_summary.dart';

class ReceivableLoansPage extends StatefulWidget {
  const ReceivableLoansPage({super.key});
  @override
  State<ReceivableLoansPage> createState() => _ReceivableLoansPageState();
}

class _ReceivableLoansPageState extends State<ReceivableLoansPage> {
  List<Map<String, dynamic>> loans = [],
      payments = [],
      accounts = [],
      creditCards = [];
  final search = TextEditingController();
  bool loading = true, saving = false;
  String? error;
  String filter = 'pending';
  int requestId = 0;
  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void checkSession(String userId) {
    if (supabase.auth.currentUser?.id != userId) {
      throw StateError('La sesión cambió. Actualiza la pantalla.');
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
        throw StateError('Debes iniciar sesión nuevamente.');
      }
      final data = await loadReceivableLoanData(user.id);
      final accountRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('accounts')
            .select('id, name, currency, is_active')
            .eq('user_id', user.id)
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        accountRows.addAll(page);
        if (page.length < 500) {
          break;
        }
      }
      final cardRows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('credit_cards')
            .select('id, name, card_reference, is_active')
            .eq('user_id', user.id)
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        cardRows.addAll(page);
        if (page.length < 500) {
          break;
        }
      }
      for (final l in data.loans.where((l) => l['is_voided'] != true)) {
        receivablePending(l, data.payments);
      }
      checkSession(user.id);
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        loans = data.loans;
        payments = data.payments;
        accounts = accountRows;
        creditCards = cardRows;
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

  Future<void> createLoan() async {
    if (loading || saving) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    setState(() => saving = true);
    try {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ReceivableLoanFormDialog(
          accounts: accounts,
          creditCards: creditCards,
        ),
      );
      if (data == null || !mounted) {
        return;
      }
      checkSession(user.id);
      await supabase.rpc('register_receivable_loan_v2', params: data);
      if (!mounted) {
        return;
      }
      message('Préstamo registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      message(e.message);
    } catch (e) {
      message('No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> collect(Map<String, dynamic> loan) async {
    if (loading || saving || loan['is_voided'] == true) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    final available = accounts
        .where(
          (a) => a['is_active'] == true && a['currency'] == loan['currency'],
        )
        .toList();
    if (available.isEmpty) {
      message(
        'Necesitas una cuenta activa en ${loan['currency']} para recibir el cobro.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ReceivableLoanPaymentDialog(
          loan: loan,
          pendingCents: receivablePending(loan, payments),
          accounts: available,
        ),
      );
      if (data == null || !mounted) {
        return;
      }
      checkSession(user.id);
      await supabase.rpc('register_receivable_loan_payment', params: data);
      if (!mounted) {
        return;
      }
      message('Cobro registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      message(e.message);
    } catch (e) {
      message('No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> voidRecord({
    Map<String, dynamic>? loan,
    Map<String, dynamic>? payment,
  }) async {
    if (loading || saving) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(payment != null ? 'Anular cobro' : 'Anular préstamo'),
        content: Text(
          payment != null
              ? 'Se retirará el capital y los intereses recibidos de la cuenta. El capital volverá a quedar pendiente.'
              : 'Se anula el registro por error. Se retira el descuento de la cuenta o el cargo vinculado en la tarjeta. '
                    'No uses esta opción para registrar una deuda que no te pagaron.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || saving || loading) {
      return;
    }
    setState(() => saving = true);
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => const VoidPaymentDialog(),
      );
      if (reason == null || !mounted) {
        return;
      }
      checkSession(user.id);
      await supabase.rpc(
        payment != null
            ? 'void_receivable_loan_payment'
            : 'void_receivable_loan',
        params: {
          if (payment != null)
            'p_payment_id': payment['id']
          else
            'p_loan_id': loan!['id'],
          'p_reason': reason,
        },
      );
      if (!mounted) {
        return;
      }
      message('Registro anulado.');
      await loadData();
    } on PostgrestException catch (e) {
      message(e.message);
    } catch (e) {
      message('No se pudo anular: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> deleteLoan(Map<String, dynamic> loan) async {
    if (loading || saving) return;
    if (loan['is_voided'] != true) {
      message('Primero anula el préstamo antes de eliminarlo definitivamente.');
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    setState(() => saving = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => DeleteReceivableLoanDialog(loan: loan),
      );
      if (confirmed != true || !mounted) return;
      checkSession(user.id);
      await supabase.rpc(
        'delete_void_receivable_loan',
        params: {'p_loan_id': loan['id'], 'p_confirmation': 'ELIMINAR'},
      );
      checkSession(user.id);
      if (!mounted) return;
      message('Préstamo eliminado definitivamente. Los saldos se conservan.');
      await loadData();
    } on PostgrestException catch (e) {
      message(e.message);
    } catch (e) {
      message('No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String accountName(dynamic id) {
    for (final a in accounts) {
      if (a['id'].toString() == id?.toString()) {
        return a['name'].toString();
      }
    }
    return 'Cuenta no disponible';
  }

  String creditCardName(dynamic id) {
    for (final c in creditCards) {
      if (c['id'].toString() == id?.toString()) {
        return c['name'].toString();
      }
    }
    return 'Tarjeta no disponible';
  }

  Future<void> history(Map<String, dynamic> loan) async {
    final rows =
        payments
            .where((p) => p['loan_id'].toString() == loan['id'].toString())
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['payment_date'].toString(),
            ).compareTo(DateTime.parse(a['payment_date'].toString())),
          );
    final currency = loan['currency'].toString();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cobros · ${loan['borrower_name']}'),
        content: SizedBox(
          width: 550,
          height: MediaQuery.sizeOf(ctx).height * 0.55,
          child: rows.isEmpty
              ? const Center(child: Text('Todavía no registras cobros.'))
              : ListView(
                  children: rows.map((p) {
                    final voided = p['is_voided'] == true;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${receivableDate(DateTime.parse(p['payment_date'].toString()).toLocal())}${voided ? ' · Anulado' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Capital: ${receivableMoney(moneyCents(p['principal_amount']), currency)}',
                            ),
                            Text(
                              'Intereses: ${receivableMoney(moneyCents(p['interest_amount']), currency)}',
                            ),
                            Text('Cuenta: ${accountName(p['account_id'])}'),
                            if ((p['reference']?.toString() ?? '').isNotEmpty)
                              SelectableText('Referencia: ${p['reference']}'),
                            if (voided) Text('Motivo: ${p['void_reason']}'),
                            if (!voided)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pop(ctx, p),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Anular cobro'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      await voidRecord(payment: selected);
    }
  }

  Widget loanCard(Map<String, dynamic> loan) {
    final currency = loan['currency'].toString();
    final pending = receivablePending(loan, payments);
    final original = moneyCents(loan['principal_amount']);
    final voided = loan['is_voided'] == true;
    final overdue = receivableOverdue(loan, pending, DateTime.now());
    final color = voided
        ? const Color(0xFF64748B)
        : overdue
        ? const Color(0xFFB42318)
        : const Color(0xFF7C3AED);
    final due = DateTime.tryParse('${loan['due_date']}');
    final hasPayments = payments.any(
      (p) =>
          p['loan_id'].toString() == loan['id'].toString() &&
          p['is_voided'] != true,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_outline_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan['borrower_name'].toString(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        voided
                            ? 'Anulado'
                            : pending == 0
                            ? 'Capital recuperado'
                            : overdue
                            ? 'Capital vencido'
                            : 'Pendiente de cobro',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((loan['description']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(loan['description'].toString()),
              ),
            const SizedBox(height: 16),
            Text(
              voided ? 'Registro sin efecto en saldos' : 'Capital que te deben',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            Text(
              receivableMoney(voided ? 0 : pending, currency),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 27,
              ),
            ),
            const SizedBox(height: 10),
            Text('Capital registrado: ${receivableMoney(original, currency)}'),
            if (!voided)
              Text(
                'Recuperado: ${receivableMoney(original - pending, currency)}',
              ),
            const SizedBox(height: 12),
            if (!voided)
              LinearProgressIndicator(
                value: ((original - pending) / original)
                    .clamp(0.0, 1.0)
                    .toDouble(),
                color: color,
                backgroundColor: color.withAlpha(15),
                minHeight: 7,
              ),
            const SizedBox(height: 12),
            Text(
              'Fecha: ${receivableDate(DateTime.parse(loan['loan_date'].toString()).toLocal())}',
            ),
            if (due != null) Text('Vence: ${receivableDate(due)}'),
            Text(
              loan['is_historical'] == true
                  ? 'Préstamo anterior · sin cargo nuevo'
                  : loan['credit_card_id'] != null
                  ? 'Origen: crédito · ${creditCardName(loan['credit_card_id'])}'
                  : 'Origen: cuenta / débito · ${accountName(loan['account_id'])}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            if ((loan['reference']?.toString() ?? '').isNotEmpty)
              SelectableText('Referencia: ${loan['reference']}'),
            if (voided) Text('Motivo: ${loan['void_reason']}'),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (voided)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: saving ? null : () => deleteLoan(loan),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Eliminar definitivamente'),
                  ),
                if (!voided && !hasPayments)
                  TextButton(
                    onPressed: saving ? null : () => voidRecord(loan: loan),
                    child: const Text('Anular registro'),
                  ),
                TextButton.icon(
                  onPressed: saving ? null : () => history(loan),
                  icon: const Icon(Icons.history),
                  label: const Text('Cobros'),
                ),
                if (!voided)
                  FilledButton.icon(
                    onPressed: saving ? null : () => collect(loan),
                    icon: const Icon(Icons.south_west_rounded),
                    label: const Text('Registrar cobro'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible =
        loans.where((l) {
          if (query.isNotEmpty &&
              !'${l['borrower_name']} ${l['description'] ?? ''}'
                  .toLowerCase()
                  .contains(query)) {
            return false;
          }
          final voided = l['is_voided'] == true;
          if (filter == 'voided') {
            return voided;
          }
          if (voided) {
            return false;
          }
          final pending = receivablePending(l, payments);
          if (filter == 'pending') {
            return pending > 0;
          }
          if (filter == 'paid') {
            return pending == 0;
          }
          if (filter == 'overdue') {
            return receivableOverdue(l, pending, DateTime.now());
          }
          return true;
        }).toList()..sort(
          (a, b) => a['borrower_name'].toString().toLowerCase().compareTo(
            b['borrower_name'].toString().toLowerCase(),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Préstamos por cobrar'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || saving || error != null ? null : createLoan,
        icon: const Icon(Icons.add),
        label: Text(saving ? 'Guardando...' : 'Dinero que presté'),
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
                    const Text('No se pudieron cargar los préstamos.'),
                    SelectableText(error!),
                    TextButton(
                      onPressed: loadData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView(
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      ReceivableLoansSummary(loans: loans, payments: payments),
                      const SizedBox(height: 20),
                      TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Buscar persona o descripción',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: filter,
                        decoration: const InputDecoration(labelText: 'Mostrar'),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendientes'),
                          ),
                          DropdownMenuItem(
                            value: 'overdue',
                            child: Text('Vencidos'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('Capital recuperado'),
                          ),
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Todos los vigentes'),
                          ),
                          DropdownMenuItem(
                            value: 'voided',
                            child: Text('Anulados'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => filter = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'No hay préstamos para este filtro.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...visible.map(loanCard),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class DeleteReceivableLoanDialog extends StatefulWidget {
  const DeleteReceivableLoanDialog({super.key, required this.loan});
  final Map<String, dynamic> loan;
  @override
  State<DeleteReceivableLoanDialog> createState() =>
      _DeleteReceivableLoanDialogState();
}

class _DeleteReceivableLoanDialogState
    extends State<DeleteReceivableLoanDialog> {
  final confirmation = TextEditingController();
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Eliminar préstamo definitivamente'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.loan['borrower_name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Capital original: ${receivableMoney(moneyCents(widget.loan['principal_amount']), '${widget.loan['currency']}')}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Se eliminará este préstamo anulado y sus cobros anulados. No podrás recuperarlos desde la app. No modifica otra vez los saldos. Si tuvo un cargo en tarjeta, ese cargo permanece anulado en su historial.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmation,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Escribe ELIMINAR para confirmar',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: confirmation.text.trim() == 'ELIMINAR'
            ? () => Navigator.pop(context, true)
            : null,
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Eliminar definitivamente'),
      ),
    ],
  );
}
