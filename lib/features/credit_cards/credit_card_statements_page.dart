import 'dart:convert';
import 'dart:math';
import 'statement_credit_dialog.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/card_statement_repository.dart';
import 'credit_card_statement_form.dart';
import 'credit_card_payment_dialog.dart';
import 'credit_card_balances.dart';

class CreditCardStatementsPage extends StatefulWidget {
  const CreditCardStatementsPage({super.key, required this.card});
  final Map<String, dynamic> card;
  @override
  State<CreditCardStatementsPage> createState() =>
      _CreditCardStatementsPageState();
}

class _CreditCardStatementsPageState extends State<CreditCardStatementsPage> {
  final pendingCredits = <String, String>{};
  String operationId() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    // UUID de la misma operación se conserva si se pierde la respuesta.
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  CardStatementData? data;
  bool loading = true, saving = false, showHistory = false;
  String? error;
  int requestId = 0;
  String get cardId => '${widget.card['id']}';
  @override
  void initState() {
    super.initState();
    load();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String owner() {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Debes iniciar sesión.');
    }
    return id;
  }

  void sameOwner(String id) {
    if (supabase.auth.currentUser?.id != id) {
      throw StateError('La sesión cambió. Abre nuevamente la pantalla.');
    }
  }

  Future<void> load() async {
    final request = ++requestId;
    if (!mounted) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await loadCardStatements(owner());
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> perform(Future<void> Function(String) action) async {
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

  Future<void> edit([Map<String, dynamic>? statement]) =>
      perform((userId) async {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => CreditCardStatementForm(statement: statement),
        );
        if (result == null || !mounted) {
          return;
        }
        sameOwner(userId);
        await supabase.rpc(
          'save_credit_card_statement',
          params: {
            'p_card_id': cardId,
            'p_currency': result['currency'],
            'p_closing_date': result['closing_date'],
            'p_due_date': result['due_date'],
            'p_balance': result['balance'],
            'p_minimum': result['minimum'],
            'p_notes': result['notes'],
            'p_statement_id': statement?['id'],
          },
        );
        message('Estado de cuenta guardado.');
      });
  Future<void> credit(Map<String, dynamic> s) => perform((userId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatementCreditDialog(statement: s, data: data!),
    );
    if (result == null || !mounted) return;
    sameOwner(userId);
    final params = <String, dynamic>{'p_statement_id': s['id'], ...result};
    final key = '$userId:${jsonEncode(params)}';
    final id = pendingCredits.putIfAbsent(key, operationId);
    await supabase.rpc(
      'register_card_statement_credit',
      params: {'p_id': id, ...params},
    );
    pendingCredits.remove(key);
    message('Reversión aplicada. No se debitó ninguna cuenta bancaria.');
  });
  Future<void> removeCredit(Map<String, dynamic> c) => perform((userId) async {
    final yes = await confirm(
      'Quitar aplicación al corte',
      'Se restaurará el pendiente de este corte. El reembolso seguirá registrado y la deuda total no cambiará. '
          'Si el reembolso era incorrecto, después puedes anularlo en el historial de movimientos.',
    );
    if (!yes || !mounted) return;
    sameOwner(userId);
    await supabase.rpc(
      'remove_card_statement_credit',
      params: {'p_id': c['id']},
    );
  });
  Future<void> pay(Map<String, dynamic> s, int cents) => perform((
    userId,
  ) async {
    final rows = await statementRows(
      'accounts',
      'id,name,currency,is_active',
      userId,
    );
    final accounts = rows
        .where((a) => a['is_active'] == true && a['currency'] == s['currency'])
        .toList();
    if (!mounted) {
      return;
    }
    if (accounts.isEmpty) {
      message('Necesitas una cuenta activa en ${s['currency']}.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreditCardPaymentDialog(
        accounts: accounts,
        currency: '${s['currency']}',
        statements: [s],
        initialStatementId: '${s['id']}',
        initialAmountCents: cents,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    sameOwner(userId);
    final linked = result['statement_id'];
    await supabase.rpc(
      linked == null
          ? 'register_credit_card_payment'
          : 'register_credit_card_payment_for_statement',
      params: {
        'p_card_id': cardId,
        'p_account_id': result['account_id'],
        'p_amount': result['amount'],
        'p_reference': result['reference'],
        if (linked != null) 'p_statement_id': linked,
      },
    );
    message('Pago registrado.');
  });
  Future<void> assign(Map<String, dynamic> s) => perform((userId) async {
    final used = data!.links.map((l) => '${l['payment_id']}').toSet();
    final available =
        data!.payments
            .where(
              (p) =>
                  p['is_voided'] != true &&
                  p['transaction_type'] == 'payment' &&
                  '${p['credit_card_id']}' == cardId &&
                  p['currency'] == s['currency'] &&
                  !used.contains('${p['id']}'),
            )
            .toList()
          ..sort(
            (a, b) => '${b['transaction_date']}'.compareTo(
              '${a['transaction_date']}',
            ),
          );
    if (available.isEmpty) {
      message('No hay pagos registrados sin asignar en esta moneda.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vincular un pago ya registrado'),
        content: SizedBox(
          width: 440,
          height: MediaQuery.sizeOf(context).height * .45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Elige solo un pago que no esté descontado del saldo al corte. Vincularlo no vuelve a descontar dinero de tu cuenta.',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: available
                      .map(
                        (p) => ListTile(
                          title: Text(
                            cardMoney(
                              moneyCents(p['amount']),
                              '${p['currency']}',
                            ),
                          ),
                          subtitle: Text(
                            '${shortStatementDate(p['transaction_date'])} · ${p['reference'] ?? 'Sin referencia'}',
                          ),
                          onTap: () =>
                              Navigator.pop(dialogContext, '${p['id']}'),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    sameOwner(userId);
    await supabase.rpc(
      'assign_credit_card_statement_payment',
      params: {'p_statement_id': s['id'], 'p_payment_id': selected},
    );
    message('Pago vinculado al corte.');
  });
  Future<void> unlink(String paymentId) => perform((userId) async {
    final yes = await confirm(
      'Quitar vínculo',
      'El pago seguirá registrado y descontado de su cuenta. Solo dejará de aplicarse a este corte.',
    );
    if (!yes || !mounted) {
      return;
    }
    sameOwner(userId);
    await supabase.rpc(
      'unassign_credit_card_statement_payment',
      params: {'p_payment_id': paymentId},
    );
  });
  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
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
  Future<void> voidStatement(Map<String, dynamic> s) => perform((userId) async {
    final yes = await confirm(
      'Anular estado de cuenta',
      'Se conserva el registro en el historial. No se anulan pagos ni cambia la deuda real de la tarjeta.',
    );
    if (!yes || !mounted) {
      return;
    }
    sameOwner(userId);
    await supabase.rpc(
      'void_credit_card_statement',
      params: {'p_statement_id': s['id']},
    );
  });
  Widget statementCard(Map<String, dynamic> s) {
    final p = data!.progress(s), currency = '${s['currency']}';
    final current = s['is_voided'] != true && s['is_archived'] != true;
    final status = s['is_voided'] == true
        ? 'Anulado'
        : s['is_archived'] == true
        ? 'Histórico'
        : p.settled
        ? 'Cubierto'
        : 'Vigente';
    final links = data!.links.where(
      (l) => '${l['statement_id']}' == '${s['id']}',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$currency · $status',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Corte: ${shortStatementDate(s['closing_date'])}'),
            Text('Vence: ${shortStatementDate(s['due_date'])}'),
            const Divider(height: 24),
            Text('Saldo al corte: ${cardMoney(p.balance, currency)}'),
            Text(
              'Mínimo informado: ${s['minimum_due'] == null ? 'Sin registrar' : cardMoney(moneyCents(s['minimum_due']), currency)}',
            ),
            Text('Pagos vinculados: ${cardMoney(p.paid, currency)}'),
            if (p.balanceCredit > 0)
              Text(
                'Reversiones aplicadas al saldo: ${cardMoney(p.balanceCredit, currency)}',
              ),
            if (p.minimumCredit > 0)
              Text(
                'Reversiones aplicadas al mínimo: ${cardMoney(p.minimumCredit, currency)}',
              ),
            const SizedBox(height: 8),
            Text(
              'Pendiente del período: ${cardMoney(p.remaining, currency)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              'Mínimo pendiente: ${s['minimum_due'] == null ? 'Sin registrar' : cardMoney(p.minimumRemaining, currency)}',
            ),
            if (!p.known)
              const Text(
                'Hay un vínculo que requiere revisión. No se presenta como pagado.',
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            if (p.excessLinked > 0)
              Text(
                'Pagos vinculados por encima del saldo al corte: ${cardMoney(p.excessLinked, currency)}.',
              ),
            if ((s['notes']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${s['notes']}'),
              ),
            if (current) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.minimumRemaining != null && p.minimumRemaining! > 0)
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => pay(s, p.minimumRemaining!),
                      child: const Text('Pagar mínimo'),
                    ),
                  if (p.remaining != null && p.remaining! > 0)
                    FilledButton(
                      onPressed: saving ? null : () => pay(s, p.remaining!),
                      child: const Text('Pagar saldo al corte'),
                    ),
                  TextButton(
                    onPressed: saving ? null : () => assign(s),
                    child: const Text('Vincular pago existente'),
                  ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => credit(s),
                    icon: const Icon(Icons.undo),
                    label: const Text('Aplicar reversión'),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => edit(s),
                    child: const Text('Editar corte'),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => voidStatement(s),
                    child: const Text('Anular corte'),
                  ),
                ],
              ),
            ],
            if (data!.credits.any(
              (c) => '${c['statement_id']}' == '${s['id']}',
            ))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Reversiones del corte'),
                children: data!.credits
                    .where((c) => '${c['statement_id']}' == '${s['id']}')
                    .map((c) {
                      final rows = data!.payments.where(
                        (t) => '${t['id']}' == '${c['refund_id']}',
                      );
                      final t = rows.isEmpty ? null : rows.first;
                      final status = c['is_removed'] == true
                          ? 'Aplicación retirada'
                          : t == null
                          ? 'Revisar'
                          : t['is_voided'] == true
                          ? 'Reembolso anulado'
                          : 'Aplicada';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${t?['description'] ?? 'Reversión'} · $status',
                        ),
                        subtitle: Text(
                          'Saldo: ${cardMoney(moneyCents(c['balance_credit']), currency)} · Mínimo: ${cardMoney(moneyCents(c['minimum_credit']), currency)}',
                        ),
                        trailing: c['is_removed'] == true
                            ? null
                            : IconButton(
                                tooltip: 'Quitar aplicación al corte',
                                onPressed: saving
                                    ? null
                                    : () => removeCredit(c),
                                icon: const Icon(Icons.link_off),
                              ),
                      );
                    })
                    .toList(),
              ),
            if (links.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Pagos vinculados'),
                children: links.map((l) {
                  final rows = data!.payments.where(
                    (p) => '${p['id']}' == '${l['payment_id']}',
                  );
                  final tx = rows.isEmpty ? null : rows.first;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tx == null
                          ? 'Pago no disponible'
                          : cardMoney(moneyCents(tx['amount']), currency),
                    ),
                    subtitle: Text(
                      tx == null
                          ? 'Revisa este vínculo'
                          : '${shortStatementDate(tx['transaction_date'])}${tx['is_voided'] == true ? ' · Anulado' : ''}',
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
        data?.statements
            .where(
              (s) =>
                  '${s['credit_card_id']}' == cardId &&
                  (showHistory ||
                      (s['is_voided'] != true && s['is_archived'] != true)),
            )
            .toList() ??
        <Map<String, dynamic>>[];
    rows.sort(
      (a, b) => '${b['closing_date']}'.compareTo('${a['closing_date']}'),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cortes y pagos'),
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
                          '${widget.card['name']}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'La deuda total cambia con los movimientos. El saldo al corte y el mínimo se copian del banco. '
                          'Registrar un corte no vuelve a cargar ese saldo a la tarjeta.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: saving ? null : () => edit(),
                          icon: const Icon(Icons.add),
                          label: Text(
                            saving ? 'Guardando...' : 'Registrar nuevo corte',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar historial'),
                          value: showHistory,
                          onChanged: (v) => setState(() => showHistory = v),
                        ),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Aún no hay estados de cuenta registrados.',
                            ),
                          ),
                        ...rows.map(statementCard),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Las compras nuevas y las devoluciones actualizan la deuda total. Los pagos y las reversiones aplicadas reducen el pendiente de este corte. '
                            'Usa Aplicar reversión con las reducciones confirmadas por el banco. El saldo y mínimo informados conservan sus importes originales; no descuentes de nuevo esas reducciones al editar el corte. '
                            'Cubrir el mínimo no significa liquidar la deuda ni garantiza evitar intereses.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              height: 1.5,
                            ),
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
