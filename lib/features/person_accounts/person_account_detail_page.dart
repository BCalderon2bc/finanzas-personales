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
  String? error;
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
            .eq('user_id', uid)
            .single(),
        personRows(
          'person_account_entries',
          uid,
          accountId: '${account['id']}',
        ),
        personRows(
          'person_account_closures',
          uid,
          accountId: '${account['id']}',
        ),
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
        account = Map<String, dynamic>.from(results[0] as Map);
        entries = rows;
        closures = List<Map<String, dynamic>>.from(
          results[2] as List,
        )..sort((a, b) => '${b['until_date']}'.compareTo('${a['until_date']}'));
        loading = false;
      });
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
    if (account['is_active'] != true) return;
    ExchangeRate? defaultRate;
    try {
      defaultRate = (await loadFinancialSettings())?.rate;
    } catch (_) {
      /* La tasa puede introducirse manualmente en el formulario. */
    }
    checkPersonSession(uid);
    if (!mounted) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PersonEntryDialog(
        personName: '${account['name']}',
        entry: entry,
        defaultRate: defaultRate,
      ),
    );
    if (data == null || !mounted) return;
    checkPersonSession(uid);
    if (entry == null) {
      await supabase.from('person_account_entries').insert({
        ...data,
        'user_id': uid,
        'person_account_id': account['id'],
      });
    } else {
      await supabase
          .from('person_account_entries')
          .update(data)
          .eq('id', entry['id'])
          .eq('user_id', uid)
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

  Widget entryCard(Map<String, dynamic> row, int running) {
    final plus = '${row['direction']}' == '1',
        voided = row['is_voided'] == true;
    final color = voided
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : plus
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF087F5B);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    personEntryLabel(row),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!voided && account['is_active'] == true && !isClosed(row))
                  PopupMenuButton<String>(
                    enabled: !saving,
                    onSelected: (v) {
                      if (v == 'edit')
                        editEntry(row);
                      else
                        voidEntry(row);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'void', child: Text('Anular')),
                    ],
                  ),
              ],
            ),
            if ('${row['description'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${row['description']}'),
              ),
            const SizedBox(height: 6),
            Text(
              '${dateText(row['entry_date'])}${voided ? ' · ANULADO' : ''}${isClosed(row) ? ' · CERRADO' : ''}',
            ),
            const SizedBox(height: 8),
            Text(
              '${plus ? '+' : '−'}${formatMoneyCents(moneyCents(row['amount']), '${row['currency']}')}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
                decoration: voided ? TextDecoration.lineThrough : null,
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
                  'Saldo después: ${personBalanceLabel(running)} ${formatMoneyCents(running.abs(), 'NIO')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var balance = 0;
    final running = <String, int>{};
    // entries se ordena de reciente a antiguo; recorrer al revés da el saldo histórico.
    for (final row in entries.reversed) {
      balance += personAccountBalance([row]);
      running['${row['id']}'] = balance;
    }
    final color = balance > 0
        ? Theme.of(context).colorScheme.error
        : balance < 0
        ? const Color(0xFF087F5B)
        : Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('${account['name']}'),
        actions: [
          IconButton(
            tooltip: 'Exportar estado de cuenta',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: loading || saving
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ExportReportsPage(
                        initialPersonId: '${account['id']}',
                      ),
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : load,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            enabled: !loading && !saving,
            onSelected: (v) {
              if (v == 'closures')
                openClosures();
              else if (v == 'edit')
                editAccount();
              else
                toggle();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'closures',
                child: Text('Cierres acordados'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Editar persona')),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            loading || saving || error != null || account['is_active'] != true
            ? null
            : () => editEntry(),
        icon: const Icon(Icons.add),
        label: Text(saving ? 'Guardando...' : 'Nuevo movimiento'),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      children: [
                        Container(
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
                              Text(
                                balance > 0
                                    ? 'Tu saldo es positivo (+).'
                                    : balance < 0
                                    ? 'Tu saldo es negativo (−).'
                                    : 'No hay saldo pendiente.',
                              ),
                              if (account['is_active'] != true)
                                const Text('Cuenta archivada'),
                            ],
                          ),
                        ),
                        Card(
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            onPressed: loading || saving ? null : deleteAccount,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar cuenta'),
                          ),
                        ),
                        if ('${account['notes'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('${account['notes']}'),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Compras de la otra persona (+) · Compras tuyas (−). Pagos tuyos (−) · Pagos que recibes (+).',
                          style: TextStyle(fontSize: 12),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar anulados'),
                          value: showVoided,
                          onChanged: (v) => setState(() => showVoided = v),
                        ),
                        if (entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Registra la primera compra o el saldo anterior para comenzar.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ...entries
                            .where((r) => showVoided || r['is_voided'] != true)
                            .map((r) => entryCard(r, running['${r['id']}']!)),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
