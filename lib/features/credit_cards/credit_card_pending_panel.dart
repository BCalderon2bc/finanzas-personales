import '../person_accounts/receipt_draft_field.dart';
import '../person_accounts/person_receipts_dialog.dart'
    show PendingReceipt, PersonReceiptsDialog;
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import 'credit_card_balances.dart';
import 'zero_plan_form.dart';

class CreditCardPendingPanel extends StatefulWidget {
  const CreditCardPendingPanel({
    super.key,
    required this.card,
    required this.onChanged,
  });
  final Map<String, dynamic> card;
  final Future<void> Function() onChanged;
  @override
  State<CreditCardPendingPanel> createState() => _CreditCardPendingPanelState();
}

class _CreditCardPendingPanelState extends State<CreditCardPendingPanel> {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> additions = [];
  bool busy = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw StateError('Inicia sesión nuevamente.');
      final results = await Future.wait([
        _cardRows('credit_card_holds', uid),
        _cardRows('credit_card_additionals', uid),
      ]);
      final all = results[0];
      if (!mounted) return;
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      final list = all
          .where(
            (r) =>
                r['credit_card_id'] == widget.card['id'] &&
                r['status'] == 'active',
          )
          .toList();
      list.sort((a, b) => '${b['hold_date']}'.compareTo('${a['hold_date']}'));
      setState(() {
        additions = results[1];
        rows = list;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = '$e';
        });
    }
  }

  Future<List<Map<String, dynamic>>> _cardRows(String table, String uid) async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      var query = supabase
          .from(table)
          .select()
          .eq('user_id', uid)
          .eq('credit_card_id', widget.card['id']);
      if (table == 'credit_card_holds') query = query.eq('status', 'active');
      final page = await query.order('id').range(offset, offset + 499);
      result.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < 500) break;
    }
    return result;
  }

  String cardLabel(Map<String, dynamic> row) {
    final id = row['additional_card_id'];
    if (id == null) return 'Tarjeta titular';
    final a = additions.where((a) => a['id'] == id).firstOrNull;
    return a == null
        ? 'Tarjeta adicional'
        : '${a['holder_name']} · ••${a['last_four']}';
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await widget.onChanged();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final v = await zeroForm(
      context,
      row == null ? 'Nuevo flotante' : 'Editar flotante',
      [
        ZeroField(
          'additional_card_id',
          'Tarjeta que hizo la compra',
          type: 'choice',
          options: {
            'primary': 'Tarjeta titular',
            for (final a in additions)
              if (a['is_active'] == true ||
                  a['id'] == row?['additional_card_id'])
                '${a['id']}': '${a['holder_name']} · ••${a['last_four']}',
          },
        ),
        const ZeroField('description', 'Descripción'),
        ZeroField('amount', 'Monto retenido', type: 'money', zero: true),
        ZeroField(
          'currency',
          'Moneda',
          type: 'choice',
          options: {'USD': 'Dólares (USD)', 'NIO': r'Córdobas (C$)'},
        ),
        ZeroField('date', 'Fecha', type: 'date'),
        ZeroField('reference', 'Referencia (opcional)', required: false),
      ],
      initial: {
        'description': row?['description'] ?? 'Compra en proceso',
        'amount': row?['amount'] ?? '',
        'currency': row?['currency'] ?? widget.card['currency'],
        'date':
            row?['hold_date'] ??
            DateTime.now().toIso8601String().substring(0, 10),
        'reference': row?['reference'] ?? '',
        'additional_card_id': row?['additional_card_id'] ?? 'primary',
      },
      attachReceipt: true,
    );
    if (v == null || !mounted) return;
    await run(() async {
      final uid = supabase.auth.currentUser!.id;
      final holdId = await supabase.rpc(
        'save_card_hold',
        params: {
          'p_additional_id': v['additional_card_id'] == 'primary'
              ? null
              : v['additional_card_id'],
          'p_id': row?['id'],
          'p_card_id': widget.card['id'],
          'p_date': v['date'],
          'p_amount': moneyCents(v['amount']) / moneyScale,
          'p_currency': v['currency'],
          'p_description': v['description'],
          'p_reference': v['reference'] ?? '',
        },
      );
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      if (mounted)
        await attachFinancialReceipt(
          context,
          v[receiptDraftKey] as PendingReceipt?,
          uid,
          'credit_card_holds',
          holdId,
        );
    });
  }

  Future<void> release(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liberar flotante'),
        content: const Text(
          'La retención dejará de consumir disponible. No se registrará una compra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (yes == true && mounted)
      await run(() async {
        await supabase.rpc('release_card_hold', params: {'p_id': row['id']});
      });
  }

  Future<void> process(Map<String, dynamic> row) async {
    final v = await zeroForm(
      context,
      'Pasar flotante a procesado',
      const [
        ZeroField('description', 'Descripción'),
        ZeroField('amount', 'Monto final', type: 'money'),
        ZeroField('date', 'Fecha de publicación', type: 'date'),
      ],
      initial: {
        'description': row['description'],
        'amount': row['amount'],
        'date': DateTime.now().toIso8601String().substring(0, 10),
      },
      attachReceipt: true,
      info:
          'Úsalo cuando el banco publique la compra. Si ya la registraste en Movimientos, cancela y libera este flotante para evitar duplicarla.',
    );
    if (v == null || !mounted) return;
    await run(() async {
      final txId = await supabase.rpc(
        'process_card_hold',
        params: {
          'p_id': row['id'],
          'p_date': v['date'],
          'p_amount': moneyCents(v['amount']) / moneyScale,
          'p_description': v['description'],
        },
      );
      if (mounted)
        await attachFinancialReceipt(
          context,
          v[receiptDraftKey] as PendingReceipt?,
          supabase.auth.currentUser!.id,
          'credit_card_transactions',
          txId,
        );
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Flotantes · ${rows.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FilledButton.icon(
                onPressed: busy || loading ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar flotante'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Reducen el disponible. Se suman al gasto cuando pasan a procesados.',
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Reintentar')),
          ],
          if (!loading && error == null && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay flotantes registrados.'),
            ),
          for (final row in rows)
            LayoutBuilder(
              builder: (context, constraints) => ExpansionTile(
                key: ValueKey(row['id']),
                tilePadding: EdgeInsets.zero,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['description']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (constraints.maxWidth < 550)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          formatRecordMoneyCents(
                            moneyCents(row['amount']),
                            '${row['currency']}',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${cardLabel(row)} · ${row['hold_date']}${'${row['reference']}'.isEmpty ? '' : ' · ${row['reference']}'}',
                ),
                trailing: constraints.maxWidth < 550
                    ? null
                    : Text(
                        formatRecordMoneyCents(
                          moneyCents(row['amount']),
                          '${row['currency']}',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (_) => PersonReceiptsDialog.movement(
                                  table: 'credit_card_holds',
                                  entryId: '${row['id']}',
                                  writable: true,
                                ),
                              ),
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Comprobantes'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => edit(row),
                        child: const Text('Editar'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => release(row),
                        child: const Text('Liberar'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => process(row),
                        child: const Text('Pasar a procesado'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
