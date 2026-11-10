import 'zero_plans_page.dart';
import '../person_accounts/receipt_draft_field.dart';
import '../help/app_help.dart';
import 'dart:convert';
import 'dart:math';
import 'statement_credit_dialog.dart';
import 'package:flutter/material.dart';
import '../person_accounts/person_receipts_dialog.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import '../../data/card_statement_repository.dart';
import '../../data/card_statement_pdf.dart';
import 'credit_card_statement_form.dart';
import 'credit_card_face.dart';
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
  String get bank => cardBankKey(cardBankName(widget.card));
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

  String documentId(Map<String, dynamic> statement) =>
      '${statement['statement_group_id'] ?? statement['id']}';

  Future<void> edit([Map<String, dynamic>? statement]) =>
      perform((userId) async {
        final editable = statement == null
            ? <Map<String, dynamic>>[]
            : [
                statement,
                for (final row in data!.statements)
                  if (row['id'] != statement['id'] &&
                      row['credit_card_id'] == statement['credit_card_id'] &&
                      documentId(row) == documentId(statement) &&
                      row['is_archived'] != true &&
                      row['is_voided'] != true)
                    row,
              ];
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => CreditCardStatementForm(
            statements: editable,
            bank: bank,
            cardReference: widget.card['card_reference']?.toString(),
          ),
        );
        if (result == null || !mounted) return;
        sameOwner(userId);
        final folderId = await supabase.rpc(
          'save_credit_card_statement_with_overdue',
          params: {
            'p_card_id': cardId,
            'p_closing_date': result['closing_date'],
            'p_bonus_payment_date': result['bonus_payment_date'],
            'p_due_date': result['due_date'],
            'p_notes': result['notes'],
            'p_rows': result['rows'],
            'p_edit_id': statement?['id'],
          },
        );
        if (!mounted) return;
        sameOwner(userId);
        await attachFinancialReceipt(
          context,
          result[receiptDraftKey] as PendingReceipt?,
          userId,
          'credit_card_statements',
          folderId,
        );
        message('Estado de cuenta guardado.');
      });

  Future<void> openStatementFiles(List<Map<String, dynamic>> group) {
    final documents = <String, bool>{};
    for (final row in group) {
      final id = documentId(row);
      documents[id] = documents[id] == true || row['is_voided'] != true;
    }
    final target =
        group.where(isCurrentStatement).firstOrNull ??
        group.where((row) => row['is_voided'] != true).firstOrNull ??
        group.first;
    return showDialog<void>(
      context: context,
      builder: (_) => PersonReceiptsDialog.statement(
        entryId: documentId(target),
        statementDocuments: documents,
      ),
    );
  }

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
    final receipt = result.remove(receiptDraftKey) as PendingReceipt?;
    final saved = await supabase.rpc(
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
    if (mounted)
      await attachFinancialReceipt(
        context,
        receipt,
        userId,
        'credit_card_transactions',
        saved,
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
      'Anular corte en ${currencyName(s)}',
      'Esta moneda pasará al historial. Los pagos registrados siguen aplicados a la deuda de la tarjeta.',
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
  String currencyName(Map<String, dynamic> row) => switch (row['currency']) {
    'NIO' => 'córdobas',
    'USD' => 'dólares',
    final value => '$value',
  };

  Widget dates(Map<String, dynamic> row) => Wrap(
    spacing: 20,
    runSpacing: 4,
    children: [
      Text('Corte · ${shortStatementDate(row['closing_date'])}'),
      Text('Fecha máxima de pago · ${shortStatementDate(row['due_date'])}'),
      if (row['bonus_payment_date'] != null)
        Text(
          'Para bonificar · ${shortStatementDate(row['bonus_payment_date'])}',
        ),
    ],
  );

  Widget statementCard(
    List<Map<String, dynamic>> group,
    List<Map<String, dynamic>> visible,
  ) {
    final first = visible.first;
    final current = visible.where(isCurrentStatement).toList();
    final sharedDates = visible.every(
      (row) =>
          row['closing_date'] == first['closing_date'] &&
          row['due_date'] == first['due_date'] &&
          row['bonus_payment_date'] == first['bonus_payment_date'],
    );
    final sharedNotes = visible.every((row) => row['notes'] == first['notes']);
    final sharedEdit =
        current.isNotEmpty &&
        current.every((row) => documentId(row) == documentId(current.first));
    final note = first['notes']?.toString().trim() ?? '';
    return Card(
      key: ValueKey(documentId(group.first)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Estado de cuenta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (sharedDates) ...[const SizedBox(height: 6), dates(first)],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: saving ? null : () => openStatementFiles(group),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Documento del banco'),
                ),
                if (sharedEdit)
                  TextButton.icon(
                    onPressed: saving ? null : () => edit(current.first),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      group.length == current.length
                          ? 'Editar corte'
                          : 'Editar ${currencyName(current.first)}',
                    ),
                  ),
              ],
            ),
            if (sharedNotes && note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Notas · $note'),
              ),
            const SizedBox(height: 14),
            AdaptiveColumns(
              minColumnWidth: 330,
              children: [
                for (final row in visible)
                  currencyPanel(
                    row,
                    showDates: !sharedDates,
                    showNotes: !sharedNotes,
                    editSeparately: !sharedEdit,
                    showPlanLink: row == first,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget currencyPanel(
    Map<String, dynamic> s, {
    required bool showDates,
    required bool showNotes,
    required bool editSeparately,
    required bool showPlanLink,
  }) {
    final p = data!.progress(s), currency = '${s['currency']}';
    final balanceCaption = switch (bank) {
      'avanz' => 'Pago de contado informado',
      'bac' || 'ficohsa' || 'lafise' => 'Importe registrado del corte',
      _ => 'Saldo al corte',
    };
    final current = isCurrentStatement(s);
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
    final theme = Theme.of(context);
    final name = currencyName(s);
    return DecoratedBox(
      key: ValueKey(s['id']),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${name[0].toUpperCase()}${name.substring(1)} · $currency',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(status, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (current)
                  PopupMenuButton<VoidCallback>(
                    tooltip: 'Más acciones en $name',
                    enabled: !saving,
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem<VoidCallback>(
                        value: () => assign(s),
                        child: const Text('Vincular pago existente'),
                      ),
                      PopupMenuItem<VoidCallback>(
                        value: () => credit(s),
                        child: const Text('Aplicar reversión'),
                      ),
                      if (editSeparately)
                        PopupMenuItem<VoidCallback>(
                          value: () => edit(s),
                          child: const Text('Editar esta moneda'),
                        ),
                      PopupMenuItem<VoidCallback>(
                        value: () => voidStatement(s),
                        child: const Text('Anular esta moneda'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Mínimo pendiente', style: theme.textTheme.bodyMedium),
            Text(
              s['minimum_due'] == null
                  ? 'Sin registrar'
                  : cardMoney(p.minimumRemaining, currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showDates) ...[const SizedBox(height: 8), dates(s)],
            const SizedBox(height: 8),
            Text('$balanceCaption · ${cardMoney(p.balance, currency)}'),
            Text(
              'Saldo pendiente · ${cardMoney(p.remaining, currency)}',
              style: theme.textTheme.bodySmall,
            ),
            if (!p.known)
              Text(
                'Revisa los pagos o reversiones vinculados a esta moneda.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (p.excessLinked > 0)
              Text(
                'Pagos por encima del saldo del corte · ${cardMoney(p.excessLinked, currency)}',
              ),
            if (showNotes && (s['notes']?.toString().trim() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Notas · ${s['notes']}'),
              ),
            if (current &&
                ((p.minimumRemaining ?? 0) > 0 || (p.remaining ?? 0) > 0)) ...[
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
                      child: const Text('Pagar pendiente'),
                    ),
                ],
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Desglose del corte'),
              children: [
                Text(
                  'Mínimo informado · ${s['minimum_due'] == null ? 'Sin registrar' : cardMoney(moneyCents(s['minimum_due']), currency)}',
                ),
                if (statementShowsOverdue(bank) && s['overdue_due'] != null)
                  Text(
                    'Pago atrasado informado · ${cardMoney(moneyCents(s['overdue_due']), currency)}',
                  ),
                Text('Pagos vinculados · ${cardMoney(p.paid, currency)}'),
                if (p.balanceCredit > 0)
                  Text(
                    'Reversiones al saldo · ${cardMoney(p.balanceCredit, currency)}',
                  ),
                if (p.minimumCredit > 0)
                  Text(
                    'Reversiones al mínimo · ${cardMoney(p.minimumCredit, currency)}',
                  ),
                if (showPlanLink)
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ZeroPlansPage(card: widget.card),
                              ),
                            );
                            if (mounted) await load();
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Ver cuotas y planes tasa cero'),
                  ),
              ],
            ),
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
                        leading: t == null
                            ? null
                            : MovementReceiptsButton(
                                table: 'credit_card_transactions',
                                record: t,
                                iconOnly: true,
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
                    leading: tx == null
                        ? null
                        : MovementReceiptsButton(
                            table: 'credit_card_transactions',
                            record: tx,
                            iconOnly: true,
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
    final groups = groupCardStatements(
      (data?.statements ?? const <Map<String, dynamic>>[]).where(
        (row) => '${row['credit_card_id']}' == cardId,
      ),
    );
    final visibleGroups = [
      for (final group in groups)
        (
          group: group,
          visible: showHistory
              ? group
              : group.where(isCurrentStatement).toList(),
        ),
    ].where((entry) => entry.visible.isNotEmpty);
    return GuideScope(
      topic: 'statements',
      ready: !loading && error == null,
      child: Scaffold(
        appBar: AppBar(
          title: GuideAnchor(id: 'title', child: const Text('Cortes y pagos')),
          actions: [
            const AppHelpButton(topic: 'statements'),
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
              constraints: const BoxConstraints(maxWidth: 920),
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
                          GuideAnchor(
                            id: 'explanation',
                            child: const Text(
                              'Cada corte reúne el documento del banco y sus montos en córdobas y dólares. '
                              'Debajo verás cuánto queda por pagar en cada moneda.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          GuideAnchor(
                            id: 'add',
                            child: FilledButton.icon(
                              onPressed: saving ? null : () => edit(),
                              icon: const Icon(Icons.add),
                              label: Text(
                                saving
                                    ? 'Guardando...'
                                    : 'Registrar nuevo corte',
                              ),
                            ),
                          ),
                          GuideAnchor(
                            id: 'history',
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mostrar historial'),
                              value: showHistory,
                              onChanged: (v) => setState(() => showHistory = v),
                            ),
                          ),
                          if (visibleGroups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                groups.isEmpty
                                    ? 'Aún no hay estados de cuenta registrados.'
                                    : 'No hay cortes vigentes. Activa el historial para ver los anteriores.',
                              ),
                            ),
                          for (final (:group, :visible) in visibleGroups)
                            statementCard(group, visible),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Las compras nuevas y las devoluciones actualizan la deuda total. Los pagos y las reversiones aplicadas reducen el pendiente de este corte. '
                              'Usa Aplicar reversión con las reducciones confirmadas por el banco. El saldo y mínimo informados conservan sus importes originales; no descuentes de nuevo esas reducciones al editar el corte. '
                              'Cubrir el mínimo no significa liquidar la deuda ni garantiza evitar intereses.',
                              style: TextStyle(
                                color: Color(0xFF596B7D),
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
      ),
    );
  }
}
