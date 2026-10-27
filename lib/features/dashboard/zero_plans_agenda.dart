import 'package:flutter/material.dart';
import '../../data/zero_plan_repository.dart';
import '../../data/card_statement_repository.dart' show statementRows;
import '../../utils/money.dart';
import '../credit_cards/zero_plans_page.dart';

class ZeroPlansAgenda extends StatefulWidget {
  const ZeroPlansAgenda({
    super.key,
    required this.refreshToken,
    required this.onChanged,
  });
  final Object refreshToken;
  final VoidCallback onChanged;
  @override
  State<ZeroPlansAgenda> createState() => _ZeroPlansAgendaState();
}

class _ZeroPlansAgendaState extends State<ZeroPlansAgenda> {
  ZeroPlanData? data;
  List<Map<String, dynamic>> cards = [], statements = [];
  String? error;
  bool loading = true, expanded = false;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ZeroPlansAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) load();
  }

  Future<void> load() async {
    final req = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = zeroUser();
      final values = await Future.wait<Object>([
        loadZeroPlans(uid),
        statementRows('credit_cards', 'id,name', uid),
        statementRows(
          'credit_card_statements',
          'id,is_voided,is_archived',
          uid,
        ),
      ]);
      zeroSession(uid);
      if (!mounted || req != request) return;
      setState(() {
        data = values[0] as ZeroPlanData;
        cards = values[1] as List<Map<String, dynamic>>;
        statements = values[2] as List<Map<String, dynamic>>;
        loading = false;
      });
    } catch (e) {
      if (mounted && req == request)
        setState(() {
          loading = false;
          error = '$e';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: LinearProgressIndicator(),
      );
    if (error != null)
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('No se pudieron cargar las cuotas tasa cero'),
        subtitle: Text(error!),
        trailing: IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      );
    final end = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day + 8,
    );
    final plans = {
      for (final p in data!.plans.where((p) => p['is_voided'] != true))
        '${p['id']}': p,
    };
    final rows =
        data!.installments
            .where(
              (i) =>
                  plans.containsKey('${i['plan_id']}') &&
                  data!.remaining(i) > 0 &&
                  DateTime.parse('${i['due_date']}').isBefore(end) &&
                  !statements.any(
                    (s) =>
                        s['id'] == i['statement_id'] &&
                        s['is_voided'] != true &&
                        s['is_archived'] != true,
                  ),
            )
            .toList()
          ..sort((a, b) => '${a['due_date']}'.compareTo('${b['due_date']}'));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        const Text(
          'Cuotas tasa cero por revisar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Vencidas o próximas 7 días, sin corte vigente vinculado. Si ya están en el estado de cuenta, vincúlalas para que no aparezcan también aquí.',
          style: TextStyle(fontSize: 12),
        ),
        ...rows.take(expanded ? rows.length : 4).map((i) {
          final p = plans['${i['plan_id']}']!,
              card = cards
                  .where((c) => c['id'] == p['credit_card_id'])
                  .firstOrNull;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(
                '${p['description']} · cuota ${i['number']}/${p['total_installments']}',
              ),
              subtitle: Text(
                '${card?['name'] ?? 'Tarjeta'} · ${zeroDateLabel(i['due_date'])}\nPendiente: ${formatMoneyCents(data!.remaining(i), '${p['currency']}')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: card == null
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ZeroPlansPage(card: card),
                        ),
                      );
                      if (mounted) widget.onChanged();
                    },
            ),
          );
        }),
        if (rows.length > 4)
          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(
              expanded
                  ? 'Mostrar menos'
                  : 'Ver todas las cuotas (${rows.length})',
            ),
          ),
      ],
    );
  }
}
