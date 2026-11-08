import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';
import '../../utils/money.dart';

class PersonEntryChangesDialog extends StatefulWidget {
  const PersonEntryChangesDialog({
    super.key,
    required this.accountId,
    required this.isOwner,
    this.entryId,
  });

  final String accountId;
  final bool isOwner;
  final String? entryId;

  @override
  State<PersonEntryChangesDialog> createState() =>
      _PersonEntryChangesDialogState();
}

class _PersonEntryChangesDialogState extends State<PersonEntryChangesDialog> {
  static const pageSize = 25;
  final rows = <Map<String, dynamic>>[];
  bool loading = false;
  bool hasMore = true;
  String? error;
  String? viewerId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading || !hasMore) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = viewerId ??= personUserId();
      checkPersonSession(uid);
      var query = supabase
          .from('person_entry_changes')
          .select(
            'id, entry_id, action, actor_id, actor_label, actor_is_owner, changed_at, before_values, after_values',
          )
          .eq('person_account_id', widget.accountId);
      if (widget.entryId case final entryId?) {
        query = query.eq('entry_id', entryId);
      }
      if (rows.isNotEmpty) query = query.lt('id', rows.last['id']);
      final page = await query
          .order('id', ascending: false)
          .limit(pageSize + 1);
      checkPersonSession(uid);
      if (!mounted) return;
      setState(() {
        rows.addAll(page.take(pageSize));
        hasMore = page.length > pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (supabase.auth.currentUser?.id != viewerId) {
          rows.clear();
          hasMore = false;
          error = 'La sesión cambió. Cierra y abre de nuevo esta pantalla.';
        } else {
          error =
              e is PostgrestException &&
                  (e.code == 'PGRST205' || e.code == '42P01')
              ? 'Instala la migración 11 en Supabase para habilitar el historial.'
              : 'No se pudo cargar el historial. Intenta de nuevo.';
        }
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String actorLabel(Map<String, dynamic> row) {
    final actor = row['actor_id'];
    if (actor == null) return 'Acción del sistema';
    if (actor == viewerId) return 'Tú';
    if (row['actor_is_owner'] == true) return 'Titular de la cuenta';
    final label = row['actor_label']?.toString().trim() ?? '';
    return label.isEmpty ? 'Colaborador' : '$label · Colaborador';
  }

  String dateLabel(Object? value, {bool withTime = false}) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return 'Sin fecha';
    String pad(int number) => number.toString().padLeft(2, '0');
    final day = '${pad(date.day)}/${pad(date.month)}/${date.year}';
    return withTime ? '$day · ${pad(date.hour)}:${pad(date.minute)}' : day;
  }

  String movementLabel(Map<String, dynamic> data) {
    final direction = int.tryParse('${data['direction']}') ?? 1;
    return personEntryLabel({
      ...data,
      'direction': widget.isOwner ? direction : -direction,
    });
  }

  Widget eventCard(Map<String, dynamic> row) {
    final before = row['before_values'] as Map<String, dynamic>?;
    final after = row['after_values'] as Map<String, dynamic>;
    final currency = '${after['currency']}';
    final (action, icon) = switch (row['action']) {
      'created' => ('Registró el movimiento', Icons.add_circle_outline),
      'voided' => ('Anuló el movimiento', Icons.block_outlined),
      _ => ('Editó el movimiento', Icons.edit_outlined),
    };
    final changes = <(String, String)>[];
    if (before != null) {
      void add(String title, String oldValue, String newValue) {
        if (oldValue != newValue) changes.add((title, '$oldValue → $newValue'));
      }

      add('Movimiento', movementLabel(before), movementLabel(after));
      add(
        'Monto',
        formatMoneyCents(moneyCents(before['amount']), '${before['currency']}'),
        formatMoneyCents(moneyCents(after['amount']), currency),
      );
      if (before['exchange_rate'] != after['exchange_rate']) {
        add(
          'Tasa de cambio',
          '${before['exchange_rate']}',
          '${after['exchange_rate']}',
        );
      }
      add(
        'Fecha del movimiento',
        dateLabel(before['entry_date']),
        dateLabel(after['entry_date']),
      );
      String description(Map<String, dynamic> values) =>
          (values['description']?.toString() ?? '').isEmpty
          ? 'Sin descripción'
          : '${values['description']}';
      add('Descripción', description(before), description(after));
      add(
        'Estado',
        before['is_voided'] == true ? 'Anulado' : 'Vigente',
        after['is_voided'] == true ? 'Anulado' : 'Vigente',
      );
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(action, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${actorLabel(row)} · ${dateLabel(row['changed_at'], withTime: true)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${movementLabel(after)} · ${formatMoneyCents(moneyCents(after['amount']), currency)}',
            ),
            if (widget.entryId == null || before == null) ...[
              Text(
                'Fecha del movimiento · ${dateLabel(after['entry_date'])}',
                style: theme.textTheme.bodySmall,
              ),
              if ('${after['description'] ?? ''}'.isNotEmpty)
                Text(
                  '${after['description']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            for (final (title, value) in changes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('$title · $value'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entryId == null
          ? 'Historial de cambios'
          : 'Cambios del movimiento',
    ),
    content: SizedBox(
      width: 580,
      height: MediaQuery.sizeOf(context).height * .58,
      child: ListView(
        children: [
          Text(
            'Se muestran los cambios registrados desde que se habilitó el historial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...rows.map(eventCard),
          if (rows.isEmpty && !loading && error == null)
            const Text('Aún no hay cambios registrados.'),
          if (error case final message?) Text(message),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && hasMore)
            TextButton(onPressed: load, child: const Text('Reintentar'))
          else if (hasMore && rows.isNotEmpty)
            TextButton(onPressed: load, child: const Text('Cargar más')),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
