import 'receipt_history.dart';
import 'receipt_draft_field.dart';
import '../../widgets/adaptive_layout.dart';
import '../help/app_help.dart';
import 'person_closures_page.dart';
import '../reports/export_reports_page.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';
import '../../data/financial_settings_repository.dart';
import '../../data/exchange_rate.dart';
import '../../utils/money.dart';
import 'person_account_form_dialog.dart';
import 'person_entry_dialog.dart';
import 'person_entry_changes_dialog.dart';
import 'person_share_dialog.dart';
import 'person_receipts_dialog.dart';

class PersonAccountDetailPage extends StatefulWidget {
  const PersonAccountDetailPage({super.key, required this.account});
  final Map<String, dynamic> account;
  @override
  State<PersonAccountDetailPage> createState() =>
      _PersonAccountDetailPageState();
}

class _PersonAccountDetailPageState extends State<PersonAccountDetailPage> {
  late Map<String, dynamic> account;
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> closures = [];
  bool loading = true, saving = false, showVoided = false;
  String? error, viewerId;
  Map<String, dynamic>? access;
  bool get isOwner => viewerId != null && account['user_id'] == viewerId;
  bool get canAdd => isOwner || access?['can_add'] == true;
  String get otherName => isOwner
      ? '${account['name']}'
      : '${access?['owner_email'] ?? 'Titular de la cuenta'}';

  bool canEdit(Map<String, dynamic> entry) =>
      isOwner ||
      access?['can_edit_all'] == true ||
      (access?['can_edit_own'] == true && entry['created_by'] == viewerId);

  Map<String, dynamic> fromViewer(Map<String, dynamic> entry) => isOwner
      ? entry
      : {...entry, 'direction': -int.parse('${entry['direction']}')};

  String entryAuthor(Map<String, dynamic> row) {
    final author = row['created_by'] ?? row['user_id'];
    if (author == viewerId) return 'Tú';
    if (author == account['user_id']) return otherName;
    return row['created_by_label'] as String? ?? 'Colaborador anterior';
  }

  int requestId = 0;
  @override
  void initState() {
    super.initState();
    account = widget.account;
    load();
  }

  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  ReceiptFilter receiptFilter = ReceiptFilter.all;
  Map<String, int>? receiptCounts;
  int receiptRequest = 0;

  String receiptFolder(Map<String, dynamic> row) =>
      '${account['id']}/${row['id']}';

  Future<void> refreshReceiptCounts() async {
    final request = ++receiptRequest;
    final uid = viewerId;
    if (uid == null) return;
    try {
      final counts = await loadReceiptCounts(
        uid,
        'person-receipts',
        entries.map(receiptFolder),
      );
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = counts);
    } catch (_) {
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = null);
    }
  }

  Future<void> load() async {
    final req = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = personUserId();
      final results = await Future.wait<Object>([
        supabase
            .from('person_accounts')
            .select()
            .eq('id', account['id'])
            .single(),
        personRows(
          'person_account_entries',
          uid,
          accountId: '${account['id']}',
          includeShared: true,
        ),
        personRows(
          'person_account_closures',
          uid,
          accountId: '${account['id']}',
          includeShared: true,
        ),
        personShares(uid, accountId: '${account['id']}'),
      ]);
      checkPersonSession(uid);
      if (!mounted || req != requestId) return;
      final rows = List<Map<String, dynamic>>.from(results[1] as List);
      rows.sort((a, b) {
        final byDate = '${b['entry_date']}'.compareTo('${a['entry_date']}');
        return byDate != 0
            ? byDate
            : '${b['created_at']}:${b['id']}'.compareTo(
                '${a['created_at']}:${a['id']}',
              );
      });
      personAccountBalance(rows);
      setState(() {
        viewerId = uid;
        account = Map<String, dynamic>.from(results[0] as Map);
        access = (results[3] as List<Map<String, dynamic>>).firstOrNull;
        entries = rows;
        closures = List<Map<String, dynamic>>.from(
          results[2] as List,
        )..sort((a, b) => '${b['until_date']}'.compareTo('${a['until_date']}'));
        loading = false;
      });
      await refreshReceiptCounts();
    } catch (e) {
      if (mounted && req == requestId)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> run(Future<void> Function(String uid) action) async {
    if (loading || saving) return;
    setState(() => saving = true);
    try {
      await action(personUserId());
      if (mounted) await load();
    } catch (e) {
      message('No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteAccount() async {
    if (loading || saving) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    final id = '${account['id']}';
    var requested = false;
    setState(() => saving = true);
    void finish() {
      if (!mounted) return;
      ++requestId;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cuenta eliminada.')),
      );
    }

    try {
      final preview = Map<String, dynamic>.from(
        await supabase.rpc(
              'person_account_delete_preview',
              params: {'p_account_id': id},
            )
            as Map,
      );
      checkPersonSession(uid);
      if (!mounted) return;
      final balance = moneyCents(preview['balance_nio']);
      var confirmation = '';
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, dialogSetState) => AlertDialog(
            title: const Text('Eliminar cuenta con persona'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${preview['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${personBalanceLabel(balance)} · ${formatMoneyCents(balance.abs(), 'NIO')}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se borrarán la cuenta, sus ${preview['entry_count']} movimientos (incluidos los anulados) '
                      'y sus ${preview['closure_count']} cierres acordados.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Esta acción es permanente. Eliminar este registro no equivale a pagar ni a cobrar el saldo pendiente.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Escribe ELIMINAR',
                      ),
                      onChanged: (v) => dialogSetState(() => confirmation = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: confirmation == 'ELIMINAR'
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar definitivamente'),
              ),
            ],
          ),
        ),
      );
      if (yes != true || !mounted) return;
      checkPersonSession(uid);
      requested = true;
      await supabase.rpc(
        'delete_person_account',
        params: {
          'p_account_id': id,
          'p_token': preview['token'],
          'p_confirmation': 'ELIMINAR',
        },
      );
      checkPersonSession(uid);
      finish();
    } catch (e) {
      // Si se perdió la respuesta del servidor, verificar antes de mostrar un
      // fallo de una cuenta que realmente ya fue eliminada.
      if (requested && supabase.auth.currentUser?.id == uid) {
        try {
          final existing = await supabase
              .from('person_accounts')
              .select('id')
              .eq('id', id)
              .eq('user_id', uid)
              .maybeSingle();
          checkPersonSession(uid);
          if (existing == null) {
            finish();
            return;
          }
        } catch (_) {
          /* Se podrá actualizar o volver a intentar. */
        }
      }
      message('No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editAccount() => run((uid) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PersonAccountFormDialog(account: account),
    );
    if (data == null || !mounted) return;
    checkPersonSession(uid);
    await supabase
        .from('person_accounts')
        .update(data)
        .eq('id', account['id'])
        .eq('user_id', uid)
        .select('id')
        .single();
  });
  Future<void> toggle() => run((uid) async {
    final active = account['is_active'] != true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(active ? 'Activar cuenta' : 'Archivar cuenta'),
        content: Text(
          active
              ? 'Podrás volver a registrar movimientos.'
              : 'Se conservarán el saldo y el historial. Para corregir o registrar movimientos tendrás que activarla.',
        ),
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
    );
    if (confirm != true || !mounted) return;
    checkPersonSession(uid);
    await supabase
        .from('person_accounts')
        .update({'is_active': active})
        .eq('id', account['id'])
        .eq('user_id', uid)
        .select('id')
        .single();
  });
  Future<void> editEntry([Map<String, dynamic>? entry]) => run((uid) async {
    if (account['is_active'] != true ||
        (entry == null ? !canAdd : !canEdit(entry)))
      return;
    ExchangeRate? defaultRate;
    try {
      defaultRate = (await loadFinancialSettings())?.rate;
    } catch (_) {
      /* La tasa puede introducirse manualmente en el formulario. */
    }
    checkPersonSession(uid);
    if (!mounted) return;
    final draft = await showDialog<PersonEntryDraft>(
      context: context,
      builder: (_) => PersonEntryDialog(
        personName: otherName,
        entry: entry == null ? null : fromViewer(entry),
        defaultRate: defaultRate,
      ),
    );
    if (draft == null || !mounted) return;
    checkPersonSession(uid);
    final values = fromViewer(draft.values);
    if (entry == null) {
      final accountId = '${account['id']}';
      final insert = supabase.from('person_account_entries').insert({
        ...values,
        'user_id': account['user_id'],
        'person_account_id': accountId,
      });
      final receipt = draft.receipt;
      if (receipt == null) {
        await insert;
      } else {
        final saved = await insert.select('id').single();
        if (!mounted) return;
        final uploaded = await uploadSavedReceipt(
          context,
          receipt: receipt,
          uid: uid,
          folder: '$accountId/${saved['id']}',
          person: true,
        );
        if (uploaded) message('Movimiento y comprobante guardados.');
        return;
      }
    } else {
      await supabase
          .from('person_account_entries')
          .update(values)
          .eq('id', entry['id'])
          .eq('user_id', account['user_id'])
          .eq('person_account_id', account['id'])
          .eq('is_voided', false)
          .select('id')
          .single();
    }
    message(
      entry == null ? 'Movimiento registrado.' : 'Movimiento actualizado.',
    );
  });
  Future<void> voidEntry(Map<String, dynamic> entry) => run((uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Anular movimiento'),
        content: const Text(
          'Dejará de contar en el saldo y se conservará visible en el historial de anulados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    checkPersonSession(uid);
    await supabase
        .from('person_account_entries')
        .update({'is_voided': true})
        .eq('id', entry['id'])
        .eq('user_id', uid)
        .eq('is_voided', false)
        .select('id')
        .single();
  });
  String dateText(dynamic value) {
    final d = DateTime.tryParse('$value');
    return d == null
        ? '$value'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  bool isClosed(Map<String, dynamic> row) => closures.any(
    (c) => '${row['entry_date']}'.compareTo('${c['until_date']}') <= 0,
  );

  Future<void> openClosures() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PersonClosuresPage(account: account),
      ),
    );
    if (mounted) await load();
  }

  Future<void> openChanges([String? entryId]) => showDialog<void>(
    context: context,
    builder: (_) => PersonEntryChangesDialog(
      accountId: '${account['id']}',
      isOwner: isOwner,
      entryId: entryId,
    ),
  );

  Widget entryCard(Map<String, dynamic> row, int running) {
    final visibleRow = fromViewer(row);
    final plus = '${visibleRow['direction']}' == '1',
        voided = row['is_voided'] == true;
    final color = voided
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : plus
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF35745C);
    return Card(
      key: ValueKey(row['id']),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  row['kind'] == 'payment'
                      ? Icons.handshake_outlined
                      : row['kind'] == 'opening'
                      ? Icons.history
                      : Icons.shopping_bag_outlined,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    personEntryLabel(visibleRow),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones del movimiento',
                  enabled: !saving,
                  onSelected: (action) {
                    if (action == 'history') {
                      openChanges('${row['id']}');
                    } else if (action == 'edit') {
                      editEntry(row);
                    } else {
                      voidEntry(row);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('Ver cambios'),
                    ),
                    if (!voided &&
                        account['is_active'] == true &&
                        !isClosed(row) &&
                        canEdit(row)) ...[
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      if (isOwner)
                        const PopupMenuItem(
                          value: 'void',
                          child: Text('Anular'),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            AdaptiveColumns(
              minColumnWidth: 245,
              spacing: 18,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ('${row['description'] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${row['description']}'),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${dateText(row['entry_date'])}${voided ? ' · ANULADO' : ''}${isClosed(row) ? ' · CERRADO' : ''}',
                    ),
                    Text('Registrado por: ${entryAuthor(row)}'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          (receiptCounts?[receiptFolder(row)] ?? 0) == 0
                              ? 'Comprobantes'
                              : 'Comprobantes (${receiptCounts![receiptFolder(row)]})',
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final writable =
                                    !voided &&
                                    account['is_active'] == true &&
                                    !isClosed(row);
                                final editable = writable && canEdit(row);
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) => PersonReceiptsDialog(
                                    accountId: '${account['id']}',
                                    entryId: '${row['id']}',
                                    canAdd:
                                        editable ||
                                        (writable &&
                                            canAdd &&
                                            row['created_by'] == viewerId),
                                    canRemove: editable,
                                  ),
                                );
                                if (mounted) await refreshReceiptCounts();
                              },
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plus ? '+' : '−'}${formatMoneyCents(moneyCents(row['amount']), '${row['currency']}')}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color,
                          decoration: voided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (row['currency'] == 'USD')
                        Text(
                          'Tasa: C\$${row['exchange_rate']} / US\$1 · Equivalente: ${formatMoneyCents(moneyCents(row['amount_nio']), 'NIO')}',
                        ),
                      if (!voided)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Saldo tras el movimiento: ${personBalanceLabel(running)} ${formatMoneyCents(running.abs(), 'NIO')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> shareAccount() => run((_) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PersonShareDialog(accountId: '${account['id']}'),
    );
  });

  void exportAccount() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExportReportsPage(initialPersonId: '${account['id']}'),
      ),
    );
  }

  Widget accountSummary(int balance, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GuideAnchor(
        id: 'balance',
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withAlpha(16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                personBalanceLabel(balance),
                style: TextStyle(fontSize: 18, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                formatMoneyCents(balance.abs(), 'NIO'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Saldo actual en córdobas'),
              if (!isOwner)
                Text(
                  canAdd ||
                          access?['can_edit_own'] == true ||
                          access?['can_edit_all'] == true
                      ? 'Cuenta compartida'
                      : 'Cuenta compartida · Solo ver',
                ),
              if (account['is_active'] != true) const Text('Cuenta archivada'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: saving ? null : () => openChanges(),
        icon: const Icon(Icons.history_rounded),
        label: const Text('Historial de cambios'),
      ),
      if (isOwner) ...[
        const SizedBox(height: 8),
        GuideAnchor(
          id: 'closures',
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Cierres acordados'),
              subtitle: Text(
                closures.isEmpty
                    ? 'Revisar y acordar el saldo'
                    : 'Último: ${dateText(closures.first['until_date'])} · ${personBalanceLabel(moneyCents(closures.first['balance_nio']))} ${formatMoneyCents(moneyCents(closures.first['balance_nio']).abs(), 'NIO')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: saving ? null : openClosures,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: loading || saving ? null : deleteAccount,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar cuenta'),
          ),
        ),
      ],
      if ('${account['notes'] ?? ''}'.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('${account['notes']}'),
        ),
    ],
  );

  Widget movementHistory(
    Iterable<Map<String, dynamic>> visibleHistory,
    Map<String, int> running,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Historial de movimientos',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        'Últimos movimientos ingresados primero',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      AdaptiveColumns(
        minColumnWidth: 235,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar anulados'),
            value: showVoided,
            onChanged: (v) => setState(() => showVoided = v),
          ),
          if (receiptCounts != null)
            ReceiptFilterField(
              value: receiptFilter,
              onChanged: (value) => setState(() => receiptFilter = value),
            ),
        ],
      ),
      const SizedBox(height: 10),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Registra la primera compra o el saldo anterior para comenzar.',
            textAlign: TextAlign.center,
          ),
        ),
      if (entries.isNotEmpty && visibleHistory.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No hay movimientos que coincidan con los filtros.'),
        ),
      for (final row in visibleHistory)
        entryCard(row, running['${row['id']}']!),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final compact = compactLayout(context);
    final gutter = pageGutter(context);
    final label = saving ? 'Guardando...' : 'Nuevo movimiento';
    final VoidCallback? add =
        loading || saving || error != null || account['is_active'] != true
        ? null
        : () => editEntry();
    var balance = 0;
    final running = <String, int>{};
    // El saldo por movimiento sigue su fecha contable, aunque el historial
    // se muestre por fecha de registro.
    for (final row in entries.reversed) {
      balance += personAccountBalance([fromViewer(row)]);
      running['${row['id']}'] = balance;
    }
    final history = [...entries]
      ..sort((a, b) {
        final aCreated = DateTime.tryParse('${a['created_at']}');
        final bCreated = DateTime.tryParse('${b['created_at']}');
        if (aCreated != null && bCreated != null) {
          final byCreated = bCreated.compareTo(aCreated);
          if (byCreated != 0) return byCreated;
        } else if (aCreated != null || bCreated != null) {
          return aCreated != null ? -1 : 1;
        }

        final byDate = '${b['entry_date']}'.compareTo('${a['entry_date']}');
        return byDate != 0 ? byDate : '${b['id']}'.compareTo('${a['id']}');
      });
    final visibleHistory = history.where(
      (row) =>
          (showVoided || row['is_voided'] != true) &&
          (receiptCounts == null ||
              receiptFilter.matches(receiptCounts?[receiptFolder(row)] ?? 0)),
    );
    final color = balance > 0
        ? Theme.of(context).colorScheme.error
        : balance < 0
        ? const Color(0xFF35745C)
        : Theme.of(context).colorScheme.primary;
    return GuideScope(
      topic: 'person_detail',
      ready: !loading && error == null,
      excludedTargets: {if (!canAdd) 'add', if (!isOwner) 'closures'},
      child: Scaffold(
        appBar: AppBar(
          title: GuideAnchor(
            id: 'title',
            child: Text(
              otherName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            const AppHelpButton(topic: 'people'),
            if (isOwner && !compact) ...[
              IconButton(
                tooltip: 'Compartir cuenta',
                icon: const Icon(Icons.share_outlined),
                onPressed: loading || saving || error != null
                    ? null
                    : shareAccount,
              ),
              IconButton(
                tooltip: 'Exportar estado de cuenta',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: loading || saving || error != null
                    ? null
                    : exportAccount,
              ),
            ],
            IconButton(
              tooltip: 'Actualizar',
              onPressed: loading || saving ? null : load,
              icon: const Icon(Icons.refresh),
            ),
            if (isOwner)
              PopupMenuButton<String>(
                enabled: !loading && !saving && error == null,
                onSelected: (v) {
                  if (v == 'share')
                    shareAccount();
                  else if (v == 'export')
                    exportAccount();
                  else if (v == 'closures')
                    openClosures();
                  else if (v == 'edit')
                    editAccount();
                  else
                    toggle();
                },
                itemBuilder: (_) => [
                  if (compact) ...[
                    const PopupMenuItem(
                      value: 'share',
                      child: Text('Compartir cuenta'),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Exportar estado de cuenta'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'closures',
                    child: Text('Cierres acordados'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar persona'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      account['is_active'] == true
                          ? 'Archivar cuenta'
                          : 'Activar cuenta',
                    ),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: compact && canAdd
            ? GuideAnchor(
                id: 'add',
                child: CompactActionBar(label: label, onPressed: add),
              )
            : null,
        floatingActionButton: !compact && canAdd
            ? GuideAnchor(
                id: 'add',
                child: FloatingActionButton.extended(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: Text(label),
                ),
              )
            : null,
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        SelectableText(error!),
                        TextButton(
                          onPressed: load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          16,
                          gutter,
                          compact ? 24 : 110,
                        ),
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 880;
                              return Wrap(
                                spacing: 24,
                                runSpacing: 18,
                                children: [
                                  SizedBox(
                                    width: wide ? 300 : constraints.maxWidth,
                                    child: accountSummary(balance, color),
                                  ),
                                  SizedBox(
                                    width: wide
                                        ? constraints.maxWidth - 324
                                        : constraints.maxWidth,
                                    child: movementHistory(
                                      visibleHistory,
                                      running,
                                    ),
                                  ),
                                ],
                              );
                            },
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
