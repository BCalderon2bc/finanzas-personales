import '../help/app_help.dart';
import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../data/period_logic.dart';
import '../../data/person_account_repository.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import '../credit_cards/zero_plan_form.dart';

class RecurringExpensesPage extends StatefulWidget {
  const RecurringExpensesPage({super.key});
  @override
  State<RecurringExpensesPage> createState() => _RecurringExpensesPageState();
}

enum _ExpenseAction { edit, delete }

class _RecurringExpensesPageState extends State<RecurringExpensesPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> expenses = [], categories = [];
  Set<(String, String)> checkedMonths = {};
  Map<(String, String), ({int cents, String currency})> monthlyTotals = {};
  bool loading = true, saving = false, showInactive = false;
  String? error;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> load() async {
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = personUserId();
      final rows = await Future.wait([
        personRows('recurring_expenses', uid),
        personRows('recurring_expense_checks', uid),
        personRows('categories', uid),
        personRows('recurring_expense_monthly_totals', uid),
      ]);
      checkPersonSession(uid);
      if (!mounted || request != requestId) return;
      rows[0].sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );
      setState(() {
        expenses = rows[0];
        checkedMonths = {
          for (final row in rows[1])
            ('${row['recurring_expense_id']}', '${row['period']}'),
        };
        categories = rows[2];
        monthlyTotals = {
          for (final row in rows[3])
            ('${row['recurring_expense_id']}', '${row['period']}'): (
              cents: moneyCents(row['amount']),
              currency: '${row['currency']}',
            ),
        };
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> run(Future<void> Function(String) action) async {
    if (saving || loading) return;
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

  bool isVariable(Map<String, dynamic> expense) =>
      expense['tracking_type'] == 'variable';

  bool isChecked(Map<String, dynamic> expense) =>
      checkedMonths.contains(('${expense['id']}', isoDay(month)));

  Future<void> setChecked(Map<String, dynamic> expense, bool checked) async {
    if (saving ||
        loading ||
        error != null ||
        isVariable(expense) ||
        !recurringInMonth(expense, month)) {
      return;
    }
    final id = '${expense['id']}', period = isoDay(month);
    setState(() => saving = true);
    try {
      final uid = personUserId();
      final table = supabase.from('recurring_expense_checks');
      if (checked) {
        await table.upsert(
          {'user_id': uid, 'recurring_expense_id': id, 'period': period},
          onConflict: 'recurring_expense_id,period',
          ignoreDuplicates: true,
        );
      } else {
        await table
            .delete()
            .eq('user_id', uid)
            .eq('recurring_expense_id', id)
            .eq('period', period);
      }
      checkPersonSession(uid);
      if (!mounted) return;
      setState(() {
        if (checked) {
          checkedMonths.add((id, period));
        } else {
          checkedMonths.remove((id, period));
        }
      });
    } catch (e) {
      message('No se pudo guardar la marca del mes: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? expense]) => run((uid) async {
    final type = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          expense == null
              ? 'Tipo de gasto mensual'
              : 'Editar ${expense['name']}',
        ),
        children: [
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Fijo'),
            subtitle: const Text('Monto previsto y casilla de pagado'),
            selected: expense != null && !isVariable(expense),
            onTap: () => Navigator.pop(dialogContext, 'fixed'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Variable'),
            subtitle: const Text('Acumulado mensual ingresado a mano'),
            selected: expense != null && isVariable(expense),
            onTap: () => Navigator.pop(dialogContext, 'variable'),
          ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    checkPersonSession(uid);
    final variable = type == 'variable';
    final choices = {
      for (final c in categories.where(
        (c) =>
            c['category_type'] == 'expense' &&
            (c['is_active'] == true || c['id'] == expense?['category_id']),
      ))
        '${c['id']}': '${c['name']}',
    };
    if (!variable && choices.isEmpty)
      throw StateError('Primero crea una categoría activa de gasto.');
    final values = await zeroForm(
      context,
      expense == null ? 'Nuevo gasto mensual' : 'Editar gasto mensual',
      [
        const ZeroField('name', 'Nombre del gasto'),
        if (!variable)
          const ZeroField('amount', 'Monto mensual previsto', type: 'money'),
        const ZeroField(
          'currency',
          'Moneda',
          type: 'choice',
          options: {'NIO': 'Córdobas · NIO', 'USD': 'Dólares · USD'},
        ),
        if (!variable)
          ZeroField(
            'category_id',
            'Categoría de gasto',
            type: 'choice',
            options: choices,
          ),
        if (!variable)
          ZeroField(
            'due_day',
            'Día de vencimiento',
            type: 'choice',
            options: {for (var day = 1; day <= 31; day++) '$day': '$day'},
          ),
        const ZeroField('starts_on', 'Desde', type: 'date'),
        if (!variable)
          const ZeroField(
            'ends_on',
            'Hasta (opcional)',
            type: 'date',
            required: false,
          ),
        const ZeroField('is_active', 'Activo', type: 'bool'),
        const ZeroField('notes', 'Notas (opcional)', required: false),
      ],
      initial: {
        'currency': 'NIO',
        'starts_on': isoDay(variable ? month : DateTime.now()),
        'is_active': true,
        ...?expense,
        'due_day': '${expense?['due_day'] ?? 1}',
      },
      info: variable
          ? 'Es un control informativo. Después podrás editar el acumulado del mes en la tarjeta.'
          : 'El importe es una previsión mensual. Marca el servicio en la lista cuando lo hayas pagado y registra el gasto real en Movimientos.',
    );
    if (values == null || !mounted) return;
    checkPersonSession(uid);
    final data = {
      ...values,
      'tracking_type': type,
      'due_day': variable ? null : int.parse('${values['due_day']}'),
      if (variable) ...{'amount': null, 'category_id': null, 'ends_on': null},
      'notes': values['notes'] ?? '',
    };
    if (expense == null) {
      await supabase.from('recurring_expenses').insert({
        ...data,
        'user_id': uid,
      });
    } else {
      await supabase
          .from('recurring_expenses')
          .update(data)
          .eq('id', expense['id'])
          .eq('user_id', uid)
          .select('id')
          .single();
    }
  });

  Future<void> deleteExpense(Map<String, dynamic> expense) async {
    if (saving || loading || error != null) return;
    final owner = supabase.auth.currentUser?.id;
    if (owner == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar ${expense['name']}'),
        content: const Text(
          'Se eliminará el gasto de la lista junto con sus marcas y acumulados de todos los meses. Los registros de Movimientos se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar gasto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || error != null) return;
    await run((uid) async {
      checkPersonSession(owner);
      final deleted = await supabase
          .from('recurring_expenses')
          .delete()
          .eq('id', expense['id'])
          .eq('user_id', uid)
          .select('id')
          .maybeSingle();
      checkPersonSession(uid);
      message(
        deleted == null
            ? 'El gasto ya no está disponible.'
            : 'Gasto eliminado.',
      );
    });
  }

  Widget expenseMenu(Map<String, dynamic> expense) =>
      PopupMenuButton<_ExpenseAction>(
        tooltip: 'Opciones de ${expense['name']}',
        enabled: !saving,
        onSelected: (action) async {
          switch (action) {
            case _ExpenseAction.edit:
              await edit(expense);
            case _ExpenseAction.delete:
              await deleteExpense(expense);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _ExpenseAction.edit,
            child: Text('Editar gasto'),
          ),
          PopupMenuItem(
            value: _ExpenseAction.delete,
            child: Text('Eliminar gasto'),
          ),
        ],
      );

  Future<void> editMonthlyTotal(Map<String, dynamic> expense) async {
    if (saving || loading || error != null) return;
    final id = '${expense['id']}', period = isoDay(month);
    final saved = monthlyTotals[(id, period)];
    final currency = saved?.currency ?? '${expense['currency']}';
    setState(() => saving = true);
    try {
      final uid = personUserId();
      final values = await zeroForm(
        context,
        'Acumulado de ${expense['name']}',
        [
          ZeroField(
            'amount',
            'Gastado en el mes ($currency)',
            type: 'money',
            zero: true,
          ),
        ],
        initial: {'amount': ((saved?.cents ?? 0) / 100).toStringAsFixed(2)},
        info:
            'Escribe el total que llevas gastado. Este importe reemplaza al anterior del mes.',
      );
      if (values == null || !mounted) return;
      checkPersonSession(uid);
      final cents = moneyCents(values['amount']);
      await supabase.rpc(
        'set_recurring_variable_total',
        params: {
          'p_expense': id,
          'p_period': period,
          'p_amount': cents / 100,
          'p_currency': currency,
        },
      );
      checkPersonSession(uid);
      if (mounted)
        setState(
          () =>
              monthlyTotals[(id, period)] = (cents: cents, currency: currency),
        );
    } catch (e) {
      message('No se pudo guardar el acumulado: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget variableCard(Map<String, dynamic> expense, {required bool inMonth}) {
    final theme = Theme.of(context);
    final total = monthlyTotals[('${expense['id']}', isoDay(month))];
    final amount = formatMoneyCents(
      total?.cents ?? 0,
      total?.currency ?? '${expense['currency']}',
    );
    final notes = '${expense['notes'] ?? ''}'.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${expense['name']}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                expenseMenu(expense),
              ],
            ),
            const Text('Gastado este mes'),
            Text(amount, style: theme.textTheme.titleLarge),
            if (notes.isNotEmpty) Text(notes),
            if (inMonth)
              TextButton.icon(
                onPressed: saving ? null : () => editMonthlyTotal(expense),
                icon: const Icon(Icons.edit_note),
                label: const Text('Actualizar acumulado'),
              )
            else
              Text(expense['is_active'] == true ? 'Fuera del mes' : 'Pausado'),
          ],
        ),
      ),
    );
  }

  void changeMonth(int offset) {
    setState(() => month = DateTime(month.year, month.month + offset));
  }

  Widget serviceCard(Map<String, dynamic> expense, {required bool inMonth}) {
    final checked = isChecked(expense);
    final theme = Theme.of(context);
    final amount = formatMoneyCents(
      moneyCents(expense['amount']),
      '${expense['currency']}',
    );
    final notes = '${expense['notes'] ?? ''}'.trim();
    final status = inMonth
        ? (checked ? 'Pagado' : 'Pendiente')
        : (expense['is_active'] == true ? 'Fuera del mes' : 'Pausado');
    return Card(
      margin: EdgeInsets.zero,
      color: checked && inMonth
          ? theme.colorScheme.primaryContainer.withValues(alpha: .45)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.only(right: 4),
                controlAffinity: ListTileControlAffinity.leading,
                value: checked,
                onChanged: inMonth && !saving
                    ? (value) => setChecked(expense, value == true)
                    : null,
                title: Text(
                  '${expense['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(amount, style: theme.textTheme.titleMedium),
                      if (inMonth)
                        Text(
                          'Vence el día ${recurringDue(expense, month).day}',
                        ),
                      Text(status),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(notes),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            expenseMenu(expense),
          ],
        ),
      ),
    );
  }

  Widget section(
    String title,
    List<Map<String, dynamic>> items, {
    bool inMonth = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title · ${items.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        AdaptiveColumns(
          minColumnWidth: 340,
          maxColumns: 3,
          children: [
            for (final item in items)
              if (isVariable(item))
                variableCard(item, inMonth: inMonth)
              else
                serviceCard(item, inMonth: inMonth),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = <Map<String, dynamic>>[],
        paid = <Map<String, dynamic>>[],
        inactive = <Map<String, dynamic>>[],
        variables = <Map<String, dynamic>>[];
    final plannedAmounts = {'NIO': 0, 'USD': 0};
    final pendingAmounts = {'NIO': 0, 'USD': 0};
    for (final expense in expenses) {
      if (!recurringInMonth(expense, month)) {
        inactive.add(expense);
        continue;
      }
      if (isVariable(expense)) {
        variables.add(expense);
        continue;
      }
      final currency = '${expense['currency']}';
      final amount = moneyCents(expense['amount']);
      plannedAmounts[currency] = plannedAmounts[currency]! + amount;
      if (isChecked(expense)) {
        paid.add(expense);
      } else {
        pending.add(expense);
        pendingAmounts[currency] = pendingAmounts[currency]! + amount;
      }
    }
    pending.sort(
      (a, b) => recurringDue(a, month).compareTo(recurringDue(b, month)),
    );
    final count = pending.length + paid.length;
    final compact = compactLayout(context);
    final add = loading || saving || error != null ? null : () => edit();
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos fijos y suscripciones'),
        actions: [
          const AppHelpButton(topic: 'recurring'),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: compact
          ? CompactActionBar(label: 'Nuevo gasto mensual', onPressed: add)
          : null,
      floatingActionButton: compact
          ? null
          : FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo gasto mensual'),
            ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: widePageMaxWidth),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      if (!saving) await load();
                    },
                    child: ListView(
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        pageGutter(context),
                        12,
                        pageGutter(context),
                        compact ? 24 : 100,
                      ),
                      children: [
                        if (error case final problem?) ...[
                          const Text('No se pudo cargar la lista mensual.'),
                          SelectableText(problem),
                          TextButton(
                            onPressed: load,
                            child: const Text('Reintentar'),
                          ),
                        ] else ...[
                          Card(
                            margin: EdgeInsets.zero,
                            color: theme.colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Mes anterior',
                                        onPressed: saving
                                            ? null
                                            : () => changeMonth(-1),
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${months[month.month - 1]} ${month.year}',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.titleLarge,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Mes siguiente',
                                        onPressed: saving
                                            ? null
                                            : () => changeMonth(1),
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                  if (count > 0) ...[
                                    Text(
                                      '${paid.length} de $count gastos fijos marcados como pagados',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(height: 14),
                            AdaptiveColumns(
                              minColumnWidth: 280,
                              children: [
                                for (final currency in ['NIO', 'USD'])
                                  Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currency == 'NIO'
                                                ? 'Córdobas'
                                                : 'Dólares',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Fijos previstos · ${formatMoneyCents(plannedAmounts[currency]!, currency)}',
                                          ),
                                          Text(
                                            'Pendiente previsto · ${formatMoneyCents(pendingAmounts[currency]!, currency)}',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (pending.isNotEmpty)
                              section('Pendientes', pending),
                            if (paid.isNotEmpty) section('Pagados', paid),
                          ],
                          if (variables.isNotEmpty)
                            section('Gastos variables', variables),
                          if (count == 0 && variables.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No hay servicios activos para este mes. Puedes agregar agua, luz, internet u otra suscripción.',
                              ),
                            ),
                          if (inactive.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Mostrar servicios pausados o fuera del mes',
                              ),
                              value: showInactive,
                              onChanged: (value) =>
                                  setState(() => showInactive = value),
                            ),
                            if (showInactive)
                              section(
                                'Otros servicios',
                                inactive,
                                inMonth: false,
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
