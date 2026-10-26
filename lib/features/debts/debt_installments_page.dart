import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/debt_installment_repository.dart';
import '../../data/card_statement_repository.dart' show statementRows;
import '../../data/card_statement_logic.dart' show shortStatementDate;
import 'debt_installment_plan_dialog.dart';
import 'debt_payment_dialog.dart';

class DebtInstallmentsPage extends StatefulWidget {
  const DebtInstallmentsPage({super.key, required this.debt});
  final Map<String, dynamic> debt;
  @override
  State<DebtInstallmentsPage> createState() => _DebtInstallmentsPageState();
}

class _DebtInstallmentsPageState extends State<DebtInstallmentsPage> {
  DebtInstallmentData? data;
  late Map<String, dynamic> debt;
  bool loading = true, saving = false, history = false;
  String? error;
  int requestId = 0;
  String get debtId => '${widget.debt['id']}';
  String money(int? n) => formatMoneyCents(n, '${debt['currency']}');
  @override
  void initState() {
    super.initState();
    debt = widget.debt;
    load();
  }

  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  String owner() {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Debes iniciar sesión.');
    }
    return id;
  }

  void same(String id) {
    if (supabase.auth.currentUser?.id != id) {
      throw StateError('La sesión cambió.');
    }
  }

  Future<void> load() async {
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = owner();
      final results = await Future.wait<Object>([
        loadDebtInstallments(uid),
        supabase
            .from('debts')
            .select('id,description,currency,original_amount,status,due_date')
            .eq('id', debtId)
            .eq('user_id', uid)
            .single(),
      ]);
      same(uid);
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        data = results[0] as DebtInstallmentData;
        debt = Map<String, dynamic>.from(results[1] as Map);
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> run(Future<void> Function(String) action) async {
    if (loading || saving) {
      return;
    }
    setState(() => saving = true);
    try {
      await action(owner());
      if (mounted) {
        await load();
      }
    } catch (e) {
      message('No se pudo completar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> configure([Map<String, dynamic>? i]) => run((uid) async {
    final v = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DebtInstallmentPlanDialog(
        currency: '${debt['currency']}',
        installment: i,
      ),
    );
    if (v == null || !mounted) {
      return;
    }
    same(uid);
    if (i == null) {
      await supabase.rpc(
        'create_debt_installment_plan',
        params: {
          'p_debt_id': debtId,
          'p_amount': v['amount'],
          'p_first_due': v['first_due'],
          'p_count': v['count'],
          'p_month_day': v['day'],
          'p_last_amount': v['last'],
        },
      );
    } else {
      await supabase.rpc(
        'update_debt_installment',
        params: {
          'p_installment_id': i['id'],
          'p_amount': v['amount'],
          'p_due_date': v['first_due'],
          'p_notes': v['notes'],
        },
      );
    }
    message('Calendario guardado.');
  });
  int get principalRemaining {
    var paid = 0;
    for (final p in data!.payments) {
      if ('${p['debt_id']}' == debtId && p['is_voided'] != true) {
        if (p['currency'] != debt['currency']) {
          throw StateError('Un abono tiene una moneda diferente al préstamo.');
        }
        paid += moneyCents(p['principal_amount']);
      }
    }
    return moneyCents(debt['original_amount']) - paid;
  }

  Future<void> pay(Map<String, dynamic> i) => run((uid) async {
    final remaining = principalRemaining;
    if (remaining < 0) {
      throw StateError('Los abonos superan el capital original.');
    }
    final rows = await statementRows(
      'accounts',
      'id,name,currency,is_active',
      uid,
    );
    final accounts = rows
        .where(
          (a) => a['is_active'] == true && a['currency'] == debt['currency'],
        )
        .toList();
    if (!mounted) {
      return;
    }
    if (accounts.isEmpty) {
      message('Necesitas una cuenta activa en ${debt['currency']}.');
      return;
    }
    final v = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DebtPaymentDialog(
        currency: '${debt['currency']}',
        remainingCents: remaining,
        accounts: accounts,
        installments: [i],
        initialInstallmentId: '${i['id']}',
        expectedTotalCents: data!.progress(i).remaining,
      ),
    );
    if (v == null || !mounted) {
      return;
    }
    same(uid);
    final linked = v['installment_id'];
    await supabase.rpc(
      linked == null
          ? 'register_debt_payment'
          : 'register_debt_payment_for_installment',
      params: {
        'p_debt_id': debtId,
        'p_account_id': v['account_id'],
        'p_principal_amount': v['principal_amount'],
        'p_interest_amount': v['interest_amount'],
        'p_fee_amount': v['fee_amount'],
        'p_payment_date': v['payment_date'],
        'p_reference': v['reference'],
        if (linked != null) 'p_installment_id': linked,
      },
    );
    message('Abono registrado.');
  });
  Future<void> link(Map<String, dynamic> i) => run((uid) async {
    final used = data!.links.map((l) => '${l['payment_id']}').toSet();
    final rows = data!.payments
        .where(
          (p) =>
              '${p['debt_id']}' == debtId &&
              p['currency'] == debt['currency'] &&
              p['is_voided'] != true &&
              !used.contains('${p['id']}'),
        )
        .toList();
    if (rows.isEmpty) {
      message('No hay abonos sin asignar para este préstamo.');
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vincular abono existente'),
        content: SizedBox(
          width: 420,
          height: MediaQuery.sizeOf(context).height * .45,
          child: ListView(
            children: rows
                .map(
                  (p) => ListTile(
                    title: Text(money(debtPaymentTotalCents(p))),
                    subtitle: Text(shortStatementDate(p['payment_date'])),
                    onTap: () => Navigator.pop(c, '${p['id']}'),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (id == null || !mounted) {
      return;
    }
    same(uid);
    await supabase.rpc(
      'assign_debt_installment_payment',
      params: {'p_installment_id': i['id'], 'p_payment_id': id},
    );
  });
  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirmar'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> unlink(String id) => run((uid) async {
    if (!await confirm(
          'El abono seguirá registrado. Solo se quita su aplicación a la cuota.',
        ) ||
        !mounted) {
      return;
    }
    same(uid);
    await supabase.rpc(
      'unassign_debt_installment_payment',
      params: {'p_payment_id': id},
    );
  });
  Future<void> archive() => run((uid) async {
    if (!await confirm(
          'Se archivará el calendario vigente, conservando sus cuotas y pagos. La deuda y los abonos reales no cambian.',
        ) ||
        !mounted) {
      return;
    }
    same(uid);
    await supabase.rpc(
      'archive_debt_installment_plan',
      params: {'p_debt_id': debtId},
    );
  });
  Widget installmentCard(Map<String, dynamic> i) {
    final p = data!.progress(i),
        current = i['is_archived'] != true && i['is_voided'] != true;
    final active = ['active', 'overdue'].contains(debt['status']);
    final links = data!.links.where(
      (l) => '${l['installment_id']}' == '${i['id']}',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cuota ${i['number']} · ${!current
                  ? 'Histórica'
                  : p.settled
                  ? 'Cubierta'
                  : 'Pendiente'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text('Vence: ${shortStatementDate(i['due_date'])}'),
            Text('Programado: ${money(moneyCents(i['amount']))}'),
            Text('Abonos vinculados: ${money(p.paid)}'),
            Text(
              'Pendiente: ${money(p.remaining)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if ((i['notes']?.toString() ?? '').isNotEmpty)
              Text('${i['notes']}'),
            if (current)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (!p.settled && p.remaining != null && active)
                    FilledButton(
                      onPressed: saving ? null : () => pay(i),
                      child: const Text('Registrar abono'),
                    ),
                  TextButton(
                    onPressed: saving ? null : () => link(i),
                    child: const Text('Vincular abono'),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => configure(i),
                    child: const Text('Editar cuota'),
                  ),
                ],
              ),
            if (links.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Abonos vinculados'),
                children: links.map((l) {
                  final values = data!.payments.where(
                    (p) => '${p['id']}' == '${l['payment_id']}',
                  );
                  final tx = values.isEmpty ? null : values.first;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tx == null
                          ? 'Abono no disponible'
                          : money(debtPaymentTotalCents(tx)),
                    ),
                    subtitle: Text(
                      tx?['is_voided'] == true
                          ? 'Anulado'
                          : shortStatementDate(tx?['payment_date']),
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar vínculo',
                      onPressed: saving
                          ? null
                          : () => unlink('${l['payment_id']}'),
                      icon: const Icon(Icons.link_off),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        data?.installments
            .where(
              (i) =>
                  '${i['debt_id']}' == debtId &&
                  (history ||
                      (i['is_archived'] != true && i['is_voided'] != true)),
            )
            .toList() ??
        <Map<String, dynamic>>[];
    rows.sort((a, b) => '${a['due_date']}'.compareTo('${b['due_date']}'));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuotas del préstamo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(error!),
                      TextButton(
                        onPressed: load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          '${debt['description']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'El calendario contiene pagos esperados, no deuda adicional. Cada abono conserva su desglose real de capital, intereses y comisiones.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              saving ||
                                  ![
                                    'active',
                                    'overdue',
                                  ].contains(debt['status'])
                              ? null
                              : () => configure(),
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Configurar cuotas mensuales'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar calendarios anteriores'),
                          value: history,
                          onChanged: (v) => setState(() => history = v),
                        ),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Todavía no hay cuotas configuradas.'),
                          ),
                        ...rows.map(installmentCard),
                        TextButton(
                          onPressed: saving ? null : archive,
                          child: const Text('Archivar calendario vigente'),
                        ),
                        const Text(
                          'Un abono se vincula completo a una cuota. Vincularlo no descuenta dinero otra vez. Si se anula, deja de cubrirla. '
                          'Si liquidaste el préstamo anticipadamente, revisa y archiva las cuotas futuras que ya no correspondan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
