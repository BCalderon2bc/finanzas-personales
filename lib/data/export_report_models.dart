import '../utils/money.dart';
import 'card_statement_logic.dart';
import 'debt_installment_logic.dart';

class MoneyCell {
  const MoneyCell(this.cents);
  final int cents;
}

class ReportTable {
  const ReportTable(this.name, this.columns, this.rows);
  final String name;
  final List<String> columns;
  final List<List<Object?>> rows;
}

class ReportTotal {
  const ReportTotal(this.currency, this.label, this.cents);
  final String currency, label;
  final int cents;
}

class ExportReport {
  const ExportReport({
    required this.title,
    required this.period,
    required this.generatedAt,
    required this.tables,
    required this.totals,
    required this.notes,
  });
  final String title, period;
  final DateTime generatedAt;
  final List<ReportTable> tables;
  final List<ReportTotal> totals;
  final List<String> notes;
  int get rowCount => tables.fold(0, (n, t) => n + t.rows.length);
}

class ExportMovement {
  const ExportMovement({
    required this.date,
    required this.values,
    required this.currency,
    required this.categoryId,
    required this.income,
    required this.expense,
    required this.unknown,
  });
  final DateTime date;
  final List<Object?> values;
  final String currency;
  final String? categoryId;
  final int income, expense;
  final bool unknown;
}

String reportDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
bool inReportRange(DateTime date, DateTime start, DateTime end) =>
    daysUntil(date, start) >= 0 && daysUntil(date, end) <= 0;
String _lookup(
  List<Map<String, dynamic>> rows,
  dynamic id,
  String key,
  String fallback,
) {
  for (final row in rows) {
    if ('${row['id']}' == '$id') {
      return row[key]?.toString() ?? fallback;
    }
  }
  return fallback;
}

List<ExportMovement> normalizeExportMovements({
  required List<Map<String, dynamic>> accountMovements,
  required List<Map<String, dynamic>> cardMovements,
  required List<Map<String, dynamic>> debtPayments,
  required List<Map<String, dynamic>> accounts,
  required List<Map<String, dynamic>> categories,
  required List<Map<String, dynamic>> cards,
  required List<Map<String, dynamic>> debts,
}) {
  final result = <ExportMovement>[];
  void add(
    Map<String, dynamic> row,
    String type,
    String account,
    int amount,
    int income,
    int expense, {
    bool unknown = false,
    String? description,
  }) {
    final date = DateTime.tryParse(
      '${row['transaction_date'] ?? row['payment_date']}',
    )?.toLocal();
    if (date == null) {
      throw FormatException('Hay un movimiento con fecha inválida.');
    }
    final currency = '${row['currency']}';
    if (!['NIO', 'USD'].contains(currency)) {
      throw StateError('Moneda no admitida: $currency');
    }
    final category = row['category_id']?.toString();
    result.add(
      ExportMovement(
        date: date,
        currency: currency,
        categoryId: category,
        income: income,
        expense: expense,
        unknown: unknown,
        values: [
          reportDate(date),
          type,
          account,
          _lookup(categories, category, 'name', 'Sin categoría'),
          description ?? row['description']?.toString() ?? '',
          currency,
          MoneyCell(amount),
          row['reference']?.toString() ?? '',
        ],
      ),
    );
  }

  const native = {
    'income': 'Ingreso',
    'expense': 'Gasto',
    'transfer': 'Transferencia',
    'deposit': 'Depósito',
    'withdrawal': 'Retiro',
  };
  for (final tx in accountMovements) {
    if (tx['is_voided'] == true) {
      continue;
    }
    final type = '${tx['transaction_type']}', amount = moneyCents(tx['amount']);
    var account = _lookup(
      accounts,
      tx['account_id'],
      'name',
      'Cuenta no disponible',
    );
    if (type == 'transfer') {
      account +=
          ' → ${_lookup(accounts, tx['destination_account_id'], 'name', 'Cuenta no disponible')}';
    }
    add(
      tx,
      native[type] ?? 'Movimiento por revisar',
      account,
      amount,
      type == 'income' ? amount : 0,
      type == 'expense' ? amount : 0,
      unknown: !native.containsKey(type),
    );
  }
  const cardTypes = {
    'purchase': 'Compra con tarjeta',
    'refund': 'Devolución de tarjeta',
    'interest': 'Intereses de tarjeta',
    'fee': 'Comisión de tarjeta',
    'payment': 'Pago de tarjeta',
  };
  for (final tx in cardMovements) {
    if (tx['is_voided'] == true) {
      continue;
    }
    final type = '${tx['transaction_type']}', amount = moneyCents(tx['amount']);
    final funding = tx['is_receivable_funding'] == true;
    final expense = funding || type == 'payment'
        ? 0
        : type == 'refund'
        ? -amount
        : ['purchase', 'interest', 'fee'].contains(type)
        ? amount
        : 0;
    add(
      tx,
      funding
          ? 'Préstamo desde tarjeta'
          : cardTypes[type] ?? 'Ajuste de tarjeta por revisar',
      _lookup(cards, tx['credit_card_id'], 'name', 'Tarjeta no disponible'),
      type == 'refund' ? -amount : amount,
      0,
      expense,
      unknown: !cardTypes.containsKey(type),
      description: type == 'payment' && tx['account_debit_amount'] != null
          ? '${tx['description'] ?? ''} · Débito de cuenta: ${formatMoneyCents(moneyCents(tx['account_debit_amount']), '${tx['account_debit_currency']}')}'
                '${tx['payment_exchange_rate'] == null ? '' : ' · Tasa C\$ ${tx['payment_exchange_rate']} por US\$1'}'
          : null,
    );
  }
  for (final p in debtPayments) {
    if (p['is_voided'] == true) {
      continue;
    }
    final currency = '${p['currency']}';
    final capital = moneyCents(p['principal_amount']),
        interest = moneyCents(p['interest_amount']),
        fee = moneyCents(p['fee_amount']);
    final debt = _lookup(
      debts,
      p['debt_id'],
      'description',
      'Préstamo no disponible',
    );
    add(
      p,
      'Abono de préstamo',
      p['account_id'] == null
          ? 'Registro manual'
          : _lookup(accounts, p['account_id'], 'name', 'Cuenta no disponible'),
      capital + interest + fee,
      0,
      interest + fee,
      description:
          '$debt · Capital: ${formatMoneyCents(capital, currency)}; '
          'intereses: ${formatMoneyCents(interest, currency)}; comisiones: ${formatMoneyCents(fee, currency)}',
    );
  }
  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
}

ExportReport movementsReport(
  List<ExportMovement> all,
  DateTime start,
  DateTime end,
  String currency,
  DateTime generatedAt,
) {
  final rows = all
      .where(
        (m) =>
            (currency == 'all' || m.currency == currency) &&
            inReportRange(m.date, start, end),
      )
      .toList();
  final totals = <ReportTotal>[];
  for (final c in ['NIO', 'USD']) {
    if (currency != 'all' && currency != c) {
      continue;
    }
    final selected = rows.where((m) => m.currency == c);
    var income = 0, expense = 0;
    for (final row in selected) {
      income += row.income;
      expense += row.expense;
    }
    totals.addAll([
      ReportTotal(c, 'Ingresos', income),
      ReportTotal(c, 'Gasto neto', expense),
      ReportTotal(c, 'Ingresos menos gastos', income - expense),
    ]);
  }
  return ExportReport(
    title: 'Movimientos',
    period: '${reportDate(start)} al ${reportDate(end)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Movimientos', const [
        'Fecha',
        'Tipo',
        'Cuenta / tarjeta',
        'Categoría',
        'Descripción',
        'Moneda',
        'Monto',
        'Referencia',
      ], rows.map((m) => m.values).toList()),
    ],
    totals: totals,
    notes: [
      'Los totales separan NIO y USD; no se convierten ni se suman monedas diferentes.',
      'Pagos de tarjeta y capital de préstamos no se vuelven a contar como gasto. Los intereses y comisiones pagados sí se incluyen. Las transferencias y préstamos por cobrar no se consideran ingresos o gastos personales.',
      if (rows.any((m) => m.unknown))
        'Hay ajustes con efecto sin definir: se muestran en el detalle y se excluyen del resumen de ingresos/gastos.',
    ],
  );
}

ExportReport debtsReport({
  required List<Map<String, dynamic>> debts,
  required List<Map<String, dynamic>> payments,
  required DebtInstallmentData installments,
  required String currency,
  required DateTime generatedAt,
}) {
  final rows = <List<Object?>>[], quotas = <List<Object?>>[];
  final totals = <ReportTotal>[];
  final sums = <String, int>{'NIO': 0, 'USD': 0};
  const status = {
    'active': 'Activa',
    'overdue': 'Vencida',
    'paused': 'Pausada',
    'paid': 'Pagada',
    'cancelled': 'Cancelada',
  };
  for (final debt in debts) {
    if (currency != 'all' && debt['currency'] != currency) {
      continue;
    }
    final c = '${debt['currency']}';
    var paid = 0;
    for (final p in payments) {
      if ('${p['debt_id']}' == '${debt['id']}' && p['is_voided'] != true) {
        if (p['currency'] != c) {
          throw StateError('Un abono tiene moneda diferente al préstamo.');
        }
        paid += moneyCents(p['principal_amount']);
      }
    }
    final original = moneyCents(debt['original_amount']),
        pending = original - paid;
    if (pending < 0) {
      throw StateError('Los abonos superan el capital de un préstamo.');
    }
    if (debt['status'] != 'cancelled') {
      sums[c] = (sums[c] ?? 0) + pending;
    }
    rows.add([
      debt['description'] ?? '',
      debt['creditor_name'] ?? '',
      c,
      MoneyCell(original),
      MoneyCell(paid),
      MoneyCell(pending),
      status[debt['status']] ?? '${debt['status']}',
      debt['due_date'] == null
          ? 'Sin fecha'
          : shortStatementDate(debt['due_date']),
    ]);
    for (final i in installments.currentFor('${debt['id']}')) {
      final p = installments.progress(i);
      quotas.add([
        debt['description'] ?? '',
        i['number'],
        shortStatementDate(i['due_date']),
        c,
        MoneyCell(moneyCents(i['amount'])),
        MoneyCell(p.paid),
        p.remaining == null ? 'Por revisar' : MoneyCell(p.remaining!),
        p.settled ? 'Cubierta' : 'Pendiente',
      ]);
    }
  }
  for (final c in ['NIO', 'USD']) {
    if (currency == 'all' || currency == c) {
      totals.add(
        ReportTotal(c, 'Capital pendiente no cancelado', sums[c] ?? 0),
      );
    }
  }
  return ExportReport(
    title: 'Deudas y cuotas',
    period: 'Saldos actuales al ${reportDate(generatedAt)}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Prestamos', const [
        'Préstamo',
        'Acreedor',
        'Moneda',
        'Capital original',
        'Abonado a capital',
        'Capital pendiente',
        'Estado',
        'Vencimiento',
      ], rows),
      ReportTable('Cuotas', const [
        'Préstamo',
        'Cuota',
        'Vencimiento',
        'Moneda',
        'Programado',
        'Abonado',
        'Pendiente',
        'Estado',
      ], quotas),
    ],
    totals: totals,
    notes: const [
      'Los saldos son actuales, no una reconstrucción histórica. Las deudas canceladas se muestran pero no integran el total pendiente.',
      'Las cuotas son pagos programados y pueden incluir intereses/comisiones; no se suman de nuevo al capital pendiente. Si un préstamo figura pagado con capital restante, revisa su historial.',
    ],
  );
}

ExportReport budgetsReport({
  required List<Map<String, dynamic>> budgets,
  required List<Map<String, dynamic>> categories,
  required List<ExportMovement> movements,
  required DateTime month,
  required String currency,
  required DateTime generatedAt,
}) {
  final used = <String, int>{};
  for (final m in movements) {
    if (m.date.year == month.year &&
        m.date.month == month.month &&
        m.categoryId != null) {
      final key = '${m.categoryId}|${m.currency}';
      used[key] = (used[key] ?? 0) + m.expense;
    }
  }
  final rows = <List<Object?>>[], totals = <ReportTotal>[];
  final limits = <String, int>{}, expenses = <String, int>{};
  final counted = <String>{};
  for (final b in budgets) {
    final date = statementDate(b['month']);
    if (date == null ||
        date.year != month.year ||
        date.month != month.month ||
        (currency != 'all' && b['currency'] != currency)) {
      continue;
    }
    final c = '${b['currency']}',
        limit = moneyCents(b['budget_amount']),
        spent = used['${b['category_id']}|$c'] ?? 0;
    limits[c] = (limits[c] ?? 0) + limit;
    if (counted.add('${b['category_id']}|$c')) {
      expenses[c] = (expenses[c] ?? 0) + spent;
    }
    rows.add([
      _lookup(categories, b['category_id'], 'name', 'Categoría no disponible'),
      '${month.year}-${month.month.toString().padLeft(2, '0')}',
      c,
      MoneyCell(limit),
      MoneyCell(spent),
      MoneyCell(limit - spent),
      spent > limit ? 'Excedido' : 'Dentro del límite',
    ]);
  }
  for (final c in ['NIO', 'USD']) {
    if (currency == 'all' || currency == c) {
      totals.addAll([
        ReportTotal(c, 'Presupuestado', limits[c] ?? 0),
        ReportTotal(c, 'Gasto de categorías presupuestadas', expenses[c] ?? 0),
        ReportTotal(
          c,
          'Disponible neto',
          (limits[c] ?? 0) - (expenses[c] ?? 0),
        ),
      ]);
    }
  }
  return ExportReport(
    title: 'Presupuestos',
    period: '${month.month.toString().padLeft(2, '0')}/${month.year}',
    generatedAt: generatedAt,
    tables: [
      ReportTable('Presupuestos', const [
        'Categoría',
        'Mes',
        'Moneda',
        'Límite',
        'Gasto neto',
        'Disponible',
        'Estado',
      ], rows),
    ],
    totals: totals,
    notes: const [
      'Solo incluye categorías presupuestadas del mes. Descuenta devoluciones. Importes originales, sin conversión de monedas.',
    ],
  );
}
