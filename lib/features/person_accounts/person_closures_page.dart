import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';
import '../../utils/money.dart';

String closureDate(dynamic value) {
  final d = DateTime.parse('$value');
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String closureIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PersonClosuresPage extends StatefulWidget {
  const PersonClosuresPage({super.key, required this.account});
  final Map<String, dynamic> account;
  @override
  State<PersonClosuresPage> createState() => _PersonClosuresPageState();
}

class _PersonClosuresPageState extends State<PersonClosuresPage> {
  List<Map<String, dynamic>> closures = [];
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await personRows(
        'person_account_closures',
        personUserId(),
        accountId: '${widget.account['id']}',
      );
      rows.sort((a, b) => '${b['until_date']}'.compareTo('${a['until_date']}'));
      if (mounted)
        setState(() {
          closures = rows;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> create() async {
    if (busy || loading) return;
    setState(() => busy = true);
    final notes = TextEditingController();
    try {
      final uid = personUserId(), today = DateTime.now();
      final first = closures.isEmpty
          ? DateTime(2000)
          : DateTime.parse(
              '${closures.first['until_date']}',
            ).add(const Duration(days: 1));
      if (first.isAfter(DateTime(today.year, today.month, today.day)))
        throw StateError(
          'Ya cerraste hasta hoy. Podrás cerrar de nuevo en una fecha posterior.',
        );
      final date = await showDatePicker(
        context: context,
        initialDate: today,
        firstDate: first,
        lastDate: today,
      );
      if (date == null || !mounted) return;
      checkPersonSession(uid);
      final preview = Map<String, dynamic>.from(
        await supabase.rpc(
              'person_closure_preview',
              params: {
                'p_account_id': widget.account['id'],
                'p_until': closureIso(date),
              },
            )
            as Map,
      );
      checkPersonSession(uid);
      if (!mounted) return;
      final balance = moneyCents(preview['balance_nio']);
      final snapshot = List<Map<String, dynamic>>.from(
        preview['snapshot'] as List,
      );
      var acknowledged = false;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setLocal) => AlertDialog(
            title: const Text('Confirmar saldo acordado'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${preview['name']} · Hasta ${closureDate(closureIso(date))} (incluido)',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${personBalanceLabel(balance)} ${formatMoneyCents(balance.abs(), 'NIO')}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cerrar no significa pagar. Se guarda el acuerdo y se protegen los movimientos hasta esta fecha. Las compras siguientes continúan sobre este saldo.',
                    ),
                    ExpansionTile(
                      title: Text('Revisar ${snapshot.length} movimientos'),
                      children: snapshot
                          .map(
                            (e) => ListTile(
                              title: Text(personEntryLabel(e)),
                              subtitle: Text(
                                '${closureDate(e['entry_date'])} · ${e['description']}${e['is_voided'] == true ? ' · ANULADO' : ''}',
                              ),
                              trailing: Text(
                                '${e['direction'].toString() == '1' ? '+' : '−'}${formatMoneyCents(moneyCents(e['amount_nio']), 'NIO')}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    TextField(
                      controller: notes,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notas del acuerdo (opcional)',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Ambos revisamos y aceptamos este saldo',
                      ),
                      value: acknowledged,
                      onChanged: (v) =>
                          setLocal(() => acknowledged = v == true),
                    ),
                    const Text(
                      'Esta es tu constancia manual. La otra persona no recibe ni firma nada desde la app.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: acknowledged ? () => Navigator.pop(c, true) : null,
                child: const Text('Guardar cierre'),
              ),
            ],
          ),
        ),
      );
      if (confirm != true) return;
      checkPersonSession(uid);
      await supabase.rpc(
        'person_close_account',
        params: {
          'p_account_id': widget.account['id'],
          'p_until': closureIso(date),
          'p_token': preview['token'],
          'p_notes': notes.text.trim(),
          'p_ack': true,
        },
      );
      checkPersonSession(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cierre guardado. El saldo continúa sin duplicarse.'),
        ),
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      notes.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Widget closureCard(Map<String, dynamic> row) {
    final balance = moneyCents(row['balance_nio']);
    final snapshot = List<Map<String, dynamic>>.from(row['snapshot'] as List);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hasta ${closureDate(row['until_date'])}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${row['name_at_close']} · ${personBalanceLabel(balance)} ${formatMoneyCents(balance.abs(), 'NIO')}',
            ),
            Text('Guardado: ${closureDate(row['created_at'])}'),
            if ('${row['notes']}'.isNotEmpty) Text('${row['notes']}'),
            ExpansionTile(
              title: Text('Historial acordado · ${snapshot.length} registros'),
              children: snapshot
                  .map(
                    (e) => ListTile(
                      title: Text(personEntryLabel(e)),
                      subtitle: Text(
                        '${closureDate(e['entry_date'])} · ${e['description']}\n${formatMoneyCents(moneyCents(e['amount']), '${e['currency']}')} · Tasa ${e['exchange_rate']}${e['is_voided'] == true ? ' · ANULADO' : ''}',
                      ),
                      trailing: Text(
                        '${e['direction'].toString() == '1' ? '+' : '−'}${formatMoneyCents(moneyCents(e['amount_nio']), 'NIO')}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cierres acordados'),
      actions: [
        IconButton(
          onPressed: loading || busy ? null : load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: loading || busy || error != null ? null : create,
          icon: const Icon(Icons.handshake_outlined),
          label: Text(busy ? 'Procesando…' : 'Revisar y guardar cierre'),
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${widget.account['name']}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Guarda hasta dónde revisaron la cuenta y qué saldo aceptaron. No genera un pago ni un saldo inicial adicional. Las correcciones a períodos cerrados se registran con fecha posterior.',
                    ),
                    if (error != null) ...[
                      SelectableText(error!),
                      TextButton(
                        onPressed: load,
                        child: const Text('Reintentar'),
                      ),
                    ] else if (closures.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Todavía no hay cierres acordados.'),
                      ),
                    ...closures.map(closureCard),
                  ],
                ),
        ),
      ),
    ),
  );
}
