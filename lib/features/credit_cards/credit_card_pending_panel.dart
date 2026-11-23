import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/card_statement_repository.dart' show statementRows;
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
      final all = await statementRows('credit_card_holds', '*', uid);
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

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
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
      const [
        ZeroField('description', 'Descripción'),
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
      },
    );
    if (v == null || !mounted) return;
    await run(() async {
      await supabase.rpc(
        'save_card_hold',
        params: {
          'p_id': row?['id'],
          'p_card_id': widget.card['id'],
          'p_date': v['date'],
          'p_amount': moneyCents(v['amount']) / 100,
          'p_currency': v['currency'],
          'p_description': v['description'],
          'p_reference': v['reference'] ?? '',
        },
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
      info:
          'Úsalo cuando el banco publique la compra. Si ya la registraste en Movimientos, cancela y libera este flotante para evitar duplicarla.',
    );
    if (v == null || !mounted) return;
    await run(() async {
      await supabase.rpc(
        'process_card_hold',
        params: {
          'p_id': row['id'],
          'p_date': v['date'],
          'p_amount': moneyCents(v['amount']) / 100,
          'p_description': v['description'],
        },
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
            ExpansionTile(
              key: ValueKey(row['id']),
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${row['description']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${row['hold_date']}${'${row['reference']}'.isEmpty ? '' : ' · ${row['reference']}'}',
              ),
              trailing: Text(
                cardMoney(moneyCents(row['amount']), '${row['currency']}'),
              ),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
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
        ],
      ),
    ),
  );
}
