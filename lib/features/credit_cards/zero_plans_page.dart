import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/card_statement_repository.dart' show statementRows;
import '../../data/zero_plan_repository.dart';
import '../../utils/money.dart';
import 'credit_card_balances.dart';
import 'zero_plan_form.dart';

class ZeroPlansPage extends StatefulWidget {
  const ZeroPlansPage({super.key, required this.card});
  final Map<String, dynamic> card;
  @override
  State<ZeroPlansPage> createState() => _ZeroPlansPageState();
}

class _ZeroPlansPageState extends State<ZeroPlansPage> {
  final commands = ZeroCommands();
  ZeroPlanData? data;
  Map<String, dynamic>? card;
  List<Map<String, dynamic>> accounts = [], categories = [], statements = [];
  bool loading = true, busy = false, showVoided = false;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> load() async {
    final req = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = zeroUser();
      final rows = await Future.wait<Object>([
        loadZeroPlans(uid),
        supabase
            .from('credit_cards')
            .select()
            .eq('user_id', uid)
            .eq('id', widget.card['id'])
            .single(),
        statementRows('accounts', 'id,name,currency,is_active', uid),
        statementRows('categories', 'id,name,category_type,is_active', uid),
        statementRows(
          'credit_card_statements',
          'id,credit_card_id,currency,closing_date,due_date,is_archived,is_voided',
          uid,
        ),
      ]);
      zeroSession(uid);
      if (!mounted || req != request) return;
      setState(() {
        data = rows[0] as ZeroPlanData;
        card = Map<String, dynamic>.from(rows[1] as Map);
        accounts = rows[2] as List<Map<String, dynamic>>;
        categories = rows[3] as List<Map<String, dynamic>>;
        statements = rows[4] as List<Map<String, dynamic>>;
        loading = false;
      });
    } catch (e) {
      if (mounted && req == request)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy || loading) return;
    setState(() => busy = true);
    try {
      await f();
      if (mounted) await load();
    } catch (e) {
      message('No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() => run(() async {
    final mode = await zeroForm(
      context,
      '¿Cómo vas a ingresar el plan?',
      const [
        ZeroField(
          'mode',
          'Origen del plan',
          type: 'choice',
          options: {
            'new': 'Compra nueva: sumar el total a la tarjeta',
            'included': 'Plan anterior: pendiente YA incluido en la tarjeta',
            'opening': 'Plan anterior: pendiente NO incluido en la tarjeta',
          },
        ),
      ],
      info:
          'Si ya registraste la compra o su pendiente como deuda inicial, usa YA incluido. Si el saldo de la app no incluye ese pendiente, usa NO incluido: solo añadirá lo que falta. Una compra nueva se registra como gasto una sola vez.',
    );
    if (mode == null || !mounted) return;
    final source = '${mode['mode']}';
    final v = await zeroForm(
      context,
      'Datos del plan tasa cero',
      [
        const ZeroField('description', 'Compra / descripción'),
        const ZeroField(
          'currency',
          'Moneda del plan',
          type: 'choice',
          options: {'NIO': 'Córdobas', 'USD': 'Dólares'},
        ),
        const ZeroField(
          'original_amount',
          'Monto original completo',
          type: 'money',
        ),
        const ZeroField(
          'total_installments',
          'Cantidad TOTAL de cuotas (1 a 120)',
        ),
        if (source != 'new')
          const ZeroField(
            'historical_paid',
            'Cuotas COMPLETAS ya pagadas antes de ingresarlo',
          ),
        const ZeroField(
          'monthly_amount',
          'Cuota mensual del banco (opcional)',
          type: 'money',
          required: false,
        ),
        const ZeroField('purchase_date', 'Fecha de compra', type: 'date'),
        const ZeroField(
          'first_due',
          'Vencimiento de la PRIMERA cuota',
          type: 'date',
        ),
        if (source == 'new')
          ZeroField(
            'category_id',
            'Categoría del gasto',
            type: 'choice',
            required: false,
            options: {
              '': 'Sin categoría',
              for (final c in categories.where(
                (c) =>
                    c['is_active'] == true && c['category_type'] == 'expense',
              ))
                '${c['id']}': '${c['name']}',
            },
          ),
      ],
      initial: {
        'currency': card!['currency'],
        'historical_paid': '0',
        'purchase_date': zeroDate(DateTime.now()),
        'first_due': zeroDate(DateTime.now()),
      },
      info:
          'Tasa de interés 0%. La moneda no se convierte. Indica la fecha de la PRIMERA cuota del plan original, incluso si ya pagaste algunas. Si dejas vacía la cuota mensual, se divide el monto y el último pago absorbe los centavos.',
    );
    if (v == null || !mounted) return;
    final count = int.tryParse('${v['total_installments']}'),
        paid = source == 'new' ? 0 : int.tryParse('${v['historical_paid']}');
    if (count == null || paid == null || paid < 0 || paid >= count)
      throw StateError(
        'Revisa la cantidad de cuotas y las ya pagadas. Debe quedar al menos una pendiente.',
      );
    final amounts = zeroSplit(
      moneyCents(v['original_amount']),
      count,
      monthly: v['monthly_amount'] == null
          ? null
          : moneyCents(v['monthly_amount']),
    );
    final pending = amounts.skip(paid).fold<int>(0, (s, a) => s + a),
        currency = '${v['currency']}';
    final first = DateTime.parse('${v['first_due']}'),
        purchase = DateTime.parse('${v['purchase_date']}');
    if (first.isBefore(purchase))
      throw StateError('La primera cuota no puede vencer antes de la compra.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revisar antes de guardar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${v['description']} · $currency'),
              Text(
                'Original: ${formatMoneyCents(moneyCents(v['original_amount']), currency)}',
              ),
              Text('Pagadas previamente: $paid de $count'),
              Text(
                'Pendiente del plan: ${formatMoneyCents(pending, currency)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Próximo vencimiento: ${zeroDateLabel(zeroMonthlyDate(first, paid))}',
              ),
              const SizedBox(height: 12),
              Text(
                source == 'included'
                    ? 'Confirmo que este pendiente YA está dentro de la deuda de la app. No cambiará el saldo ni el disponible.'
                    : source == 'opening'
                    ? 'Se añadirá SOLO el pendiente a la deuda inicial y bajará el disponible. No se registrará como gasto nuevo.'
                    : 'Se registrará UNA compra por el monto completo. Subirá la deuda, bajará el disponible y se contará el gasto en la fecha de compra.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Las cuotas se muestran para controlar el plan; no se suman otra vez a la deuda. El pago de un corte puede incluir cuotas y otras compras.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar y guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    v['total_installments'] = count;
    v['historical_paid'] = paid;
    v['entry_mode'] = source;
    v['credit_card_id'] = card!['id'];
    v['confirmed'] = true;
    v['purchase_timestamp'] = DateTime(
      purchase.year,
      purchase.month,
      purchase.day,
      12,
    ).toUtc().toIso8601String();
    await commands.run('zero_plan_create', {'p_data': v}, operation: true);
    message('Plan registrado sin duplicar cuotas ni pagos anteriores.');
  });
  Future<void> pay(
    Map<String, dynamic> p,
    Map<String, dynamic> i, {
    bool existing = false,
  }) => run(() async {
    final curr = '${p['currency']}', pending = data!.remaining(i);
    final availablePayments = data!.transactions
        .where(
          (t) =>
              t['credit_card_id'] == p['credit_card_id'] &&
              t['currency'] == curr &&
              t['transaction_type'] == 'payment' &&
              t['is_voided'] != true &&
              data!.unassigned(t) > 0,
        )
        .toList();
    final options = {
      for (final a in accounts.where(
        (a) => a['is_active'] == true && a['currency'] == curr,
      ))
        '${a['id']}': '${a['name']} ($curr)',
    };
    if (existing && availablePayments.isEmpty)
      throw StateError(
        'No hay pagos con importe libre en esta tarjeta y moneda.',
      );
    if (!existing && options.isEmpty)
      throw StateError('Necesitas una cuenta activa en $curr.');
    final v = await zeroForm(
      context,
      existing ? 'Vincular pago registrado' : 'Registrar pago de cuota',
      [
        if (existing)
          ZeroField(
            'payment_id',
            'Pago ya registrado',
            type: 'choice',
            options: {
              for (final t in availablePayments)
                '${t['id']}':
                    '${zeroDateLabel(t['transaction_date'])} · Libre ${formatMoneyCents(data!.unassigned(t), curr)} · ${t['description'] ?? ''}',
            },
          )
        else
          ZeroField(
            'account_id',
            'Cuenta de débito / efectivo',
            type: 'choice',
            options: options,
          ),
        const ZeroField(
          'amount',
          'Monto que corresponde a esta cuota',
          type: 'money',
        ),
        if (!existing)
          const ZeroField('date', 'Fecha real del pago', type: 'date'),
      ],
      initial: {
        'amount': (pending / 100).toStringAsFixed(2),
        'date': zeroDate(DateTime.now()),
      },
      info: existing
          ? 'Solo clasifica parte de un pago existente: NO vuelve a descontar tu cuenta ni la tarjeta.'
          : 'Registra el pago una sola vez: descuenta esta cuenta y reduce la deuda de tarjeta y el pendiente de esta cuota. Si ya anotaste el pago, cancela y usa Vincular pago registrado.',
    );
    if (v == null) return;
    final amount = moneyCents(v['amount']);
    if (amount > pending)
      throw StateError('El monto supera lo pendiente de la cuota.');
    final date = existing ? null : DateTime.parse('${v['date']}');
    await commands.run('zero_plan_allocate', {
      'p_installment_id': i['id'],
      'p_amount': v['amount'],
      'p_payment_id': existing ? v['payment_id'] : null,
      'p_account_id': existing ? null : v['account_id'],
      'p_payment_date': date == null
          ? null
          : DateTime(
              date.year,
              date.month,
              date.day,
              12,
            ).toUtc().toIso8601String(),
    }, operation: true);
    message(
      existing ? 'Pago vinculado sin otro descuento.' : 'Pago registrado.',
    );
  });
  Future<void> linkStatement(
    Map<String, dynamic> p,
    Map<String, dynamic> i,
  ) => run(() async {
    final v = await zeroForm(
      context,
      'Cuota incluida en un corte',
      [
        ZeroField(
          'statement_id',
          'Estado de cuenta',
          type: 'choice',
          required: false,
          options: {
            '': 'Sin corte vinculado',
            for (final s in statements.where(
              (s) =>
                  s['credit_card_id'] == p['credit_card_id'] &&
                  s['currency'] == p['currency'] &&
                  s['is_voided'] != true &&
                  s['is_archived'] != true,
            ))
              '${s['id']}':
                  'Corte ${zeroDateLabel(s['closing_date'])} · vence ${zeroDateLabel(s['due_date'])}',
          },
        ),
      ],
      initial: {
        'statement_id':
            statements.any(
              (s) =>
                  s['id'] == i['statement_id'] &&
                  s['is_voided'] != true &&
                  s['is_archived'] != true,
            )
            ? i['statement_id']
            : null,
      },
      info:
          'El saldo al corte que registraste del banco debe incluir esta cuota. Vincularla NO aumenta ese saldo ni crea otra compra. Al pagar desde aquí, el pago se vincula también al corte.',
    );
    if (v != null)
      await commands.run('zero_plan_statement', {
        'p_installment_id': i['id'],
        'p_statement_id': v['statement_id'],
      });
  });
  Future<void> voidPlan(Map<String, dynamic> p) => run(() async {
    final v = await zeroForm(
      context,
      'Anular plan creado por error',
      const [ZeroField('reason', 'Motivo')],
      info: p['entry_mode'] == 'included'
          ? 'Se anula el control del plan. La deuda que ya tenías registrada se conserva. Los pagos bancarios se conservan.'
          : 'Se retirará el cargo o deuda inicial que creó este plan. No se anulan los pagos bancarios: si hubo pagos, revisa su historial y corrige esos registros por separado. No uses esta opción para liquidar un plan real.',
    );
    if (v != null)
      await commands.run('zero_plan_void', {
        'p_id': p['id'],
        'p_reason': v['reason'],
      });
  });
  Widget installment(Map<String, dynamic> p, Map<String, dynamic> i) {
    final remaining = data!.remaining(i),
        paid = data!.paid(i),
        curr = '${p['currency']}',
        historical = i['historical_paid'] == true;
    final links = data!.allocations
        .where((a) => a['installment_id'] == i['id'] && a['is_removed'] != true)
        .toList();
    final statement = statements
        .where((s) => s['id'] == i['statement_id'])
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cuota ${i['number']} de ${p['total_installments']} · ${zeroDateLabel(i['due_date'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Monto: ${formatMoneyCents(moneyCents(i['amount']), curr)} · Pagado: ${formatMoneyCents(paid, curr)}',
            ),
            Text(
              historical
                  ? 'Pagada antes de ingresar el plan'
                  : remaining == 0
                  ? 'Cuota cubierta'
                  : 'Pendiente: ${formatMoneyCents(remaining, curr)}',
            ),
            if (i['statement_id'] != null)
              Text(
                'Incluida en corte ${zeroDateLabel(statement?['closing_date'])}${statement?['is_voided'] == true ? ' · ANULADO: revisar vínculo' : ''}',
              ),
            if (!historical && p['is_voided'] != true)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (remaining > 0) ...[
                    TextButton(
                      onPressed: busy ? null : () => pay(p, i),
                      child: const Text('Pagar cuota'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => pay(p, i, existing: true),
                      child: const Text('Vincular pago registrado'),
                    ),
                  ],
                  TextButton(
                    onPressed: busy ? null : () => linkStatement(p, i),
                    child: const Text('Vincular / quitar corte'),
                  ),
                ],
              ),
            ...links.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${formatMoneyCents(moneyCents(a['amount']), curr)} · ${data!.live(a) ? 'Pago vinculado' : 'Pago anulado / por revisar'}',
                ),
                subtitle: Text(
                  'Pago: ${zeroDateLabel(data!.payment(a['payment_id'])?['transaction_date'])}',
                ),
                trailing: IconButton(
                  tooltip: 'Quitar vínculo; conserva el pago bancario',
                  onPressed: busy || p['is_voided'] == true
                      ? null
                      : () => run(() async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Quitar vínculo'),
                              content: const Text(
                                'La cuota volverá a quedar pendiente. El pago y su descuento bancario se conservan; solo se quita su asignación a esta cuota.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Quitar vínculo'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true)
                            await commands.run('zero_plan_unlink', {
                              'p_id': a['id'],
                            });
                        }),
                  icon: const Icon(Icons.link_off),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget discrepancyNotice() {
    final currencies = <String>[];
    for (final currency in cardCurrencies) {
      final tracked = data!.plans
          .where(
            (p) =>
                p['credit_card_id'] == card!['id'] &&
                p['currency'] == currency &&
                p['is_voided'] != true,
          )
          .fold<int>(0, (sum, p) => sum + data!.pending('${p['id']}'));
      final balance = cardBalance(card!, data!.transactions, currency);
      if (balance != null && tracked > balance) currencies.add(currency);
    }
    if (currencies.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Revisa los pagos o el origen de los planes en ${currencies.join(' / ')}: su pendiente supera la deuda total registrada. Puede haber pagos de tarjeta todavía sin vincular a las cuotas, devoluciones o un plan ingresado dos veces. Vincular un pago existente no vuelve a descontar dinero.',
        ),
      ),
    );
  }

  Widget planCard(Map<String, dynamic> p) {
    final list = data!.forPlan('${p['id']}'),
        pending = data!.pending('${p['id']}'),
        curr = '${p['currency']}';
    final inCuts = list
        .where(
          (i) =>
              i['statement_id'] != null &&
              statements.any(
                (s) => s['id'] == i['statement_id'] && s['is_voided'] != true,
              ),
        )
        .fold<int>(0, (sum, i) => sum + data!.remaining(i));
    final covered = list.where((i) => data!.remaining(i) == 0).length,
        next = list.where((i) => data!.remaining(i) > 0).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${p['description']}${p['is_voided'] == true ? ' · ANULADO' : ''}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            Text(
              'Original: ${formatMoneyCents(moneyCents(p['original_amount']), curr)} · Interés: 0%',
            ),
            Text('$covered de ${p['total_installments']} cuotas cubiertas'),
            Text(
              'Pendiente: ${formatMoneyCents(pending, curr)}',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            Text(
              'De ese pendiente, vinculado a cortes: ${formatMoneyCents(inCuts, curr)}',
            ),
            Text(
              'Sin corte vinculado: ${formatMoneyCents(pending - inCuts, curr)}',
            ),
            if (next != null)
              Text(
                'Próxima cuota: ${zeroDateLabel(next['due_date'])} · ${formatMoneyCents(data!.remaining(next), curr)}',
              ),
            Text(
              p['entry_mode'] == 'new'
                  ? 'Origen: compra nueva registrada una sola vez'
                  : p['entry_mode'] == 'opening'
                  ? 'Origen: pendiente añadido a deuda inicial'
                  : 'Origen: pendiente ya incluido en tu tarjeta',
              style: const TextStyle(fontSize: 12),
            ),
            if (p['is_voided'] == true) Text('Motivo: ${p['void_reason']}'),
            ExpansionTile(
              title: const Text('Ver cuotas, pagos y cortes'),
              children: list.map((i) => installment(p, i)).toList(),
            ),
            if (p['is_voided'] != true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => voidPlan(p),
                  child: const Text('Anular plan por error'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans =
        data?.plans
            .where(
              (p) =>
                  p['credit_card_id'] == widget.card['id'] &&
                  (showVoided || p['is_voided'] != true),
            )
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes tasa cero'),
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
            onPressed: loading || busy || error != null ? null : add,
            icon: const Icon(Icons.add),
            label: Text(busy ? 'Procesando…' : 'Agregar plan tasa cero'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${card?['name'] ?? widget.card['name']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'La deuda total y el uso del límite incluyen el capital pendiente de los planes. Las cuotas distribuyen ese capital: no vuelven a sumarlo. El disponible es una estimación; usa la tasa del banco en la tarjeta.',
                      ),
                      if (error != null) ...[
                        SelectableText(error!),
                        TextButton(
                          onPressed: load,
                          child: const Text('Reintentar'),
                        ),
                      ] else ...[
                        for (final curr in cardCurrencies)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Deuda TOTAL ${curr == 'NIO' ? 'en córdobas' : 'en dólares'}: ${cardMoney(cardBalance(card!, data!.transactions, curr), curr)}',
                                  ),
                                  Text(
                                    'De esa deuda, pendiente controlado en tasa cero: ${cardMoney(data!.plans.where((p) => p['credit_card_id'] == card!['id'] && p['currency'] == curr && p['is_voided'] != true).fold<int>(0, (s, p) => s + data!.pending('${p['id']}')), curr)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Text(
                          'Disponible estimado: ${cardMoney(cardAvailable(card!, cardBalance(card!, data!.transactions, 'NIO'), cardBalance(card!, data!.transactions, 'USD')), '${card!['currency']}')}',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Si una cuota está incluida en el corte del banco, registra ese corte con su monto real y vincula la cuota. Este módulo no calcula ni modifica automáticamente tu saldo al corte ni el pago mínimo.',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mostrar planes anulados'),
                          value: showVoided,
                          onChanged: (v) => setState(() => showVoided = v),
                        ),
                        if (plans.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Todavía no hay planes para mostrar.'),
                          ),
                        discrepancyNotice(),
                        ...plans.map(planCard),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
