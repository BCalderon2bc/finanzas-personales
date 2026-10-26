import '../../utils/money.dart';
import '../credit_cards/credit_card_balances.dart';
import 'dashboard_models.dart';

DateTime _dashboardDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();

  if (date == null) {
    throw const FormatException('Hay un movimiento con fecha inválida.');
  }

  return date;
}

DashboardOverview buildDashboardOverview(
  DashboardPeriod period, {
  required List<List<Map<String, dynamic>>> rows,
  required DateTime today,
}) {
  final accounts = rows[0];
  final transactions = rows[1];
  final debts = rows[4];
  final cards = rows[6];

  final debtPayments = rows[5].where((p) => p['is_voided'] != true).toList();

  final cardTransactions = rows[7]
      .where((p) => p['is_voided'] != true)
      .toList();

  final cardPayments = cardTransactions
      .where((p) => p['transaction_type'] == 'payment')
      .toList();

  final balances = calculateBalances(
    accounts,
    transactions,
    cardPayments: cardPayments,
    debtPayments: debtPayments,
  );

  final data = DashboardOverview(
    DateTime(period.start.year, period.start.month),
    period: period,
  );
  final previous = period.previous;
  today = DateTime(today.year, today.month, today.day);
  final monthlyExpenses = <String, int>{};
  String expenseKey(DateTime date, String currency, dynamic categoryId) =>
      '${date.year}-${date.month}|$currency|${categoryId ?? 'none'}';

  final accountMap = {
    for (final account in accounts) account['id'].toString(): account,
  };

  final debtMap = {for (final debt in debts) debt['id'].toString(): debt};

  final cardMap = {for (final card in cards) card['id'].toString(): card};

  DashboardCurrency metric(String currency) {
    final result = data.currencies[currency];

    if (result == null) {
      throw StateError('Moneda no reconocida: $currency');
    }

    return result;
  }

  void expense(int cents, DateTime date, String currency, dynamic categoryId) {
    if (cents == 0) {
      return;
    }

    final total = metric(currency);

    if (period.contains(date)) {
      total.expense += cents;
      final key = categoryId?.toString() ?? 'none';
      total.categories[key] = (total.categories[key] ?? 0) + cents;
      final monthKey = expenseKey(date, currency, categoryId);
      monthlyExpenses[monthKey] = (monthlyExpenses[monthKey] ?? 0) + cents;
    } else if (previous.contains(date)) {
      total.previousExpense += cents;
    }
  }

  void event(DashboardEvent item) {
    if (period.contains(item.date)) {
      data.events.add(item);
      metric(item.currency).movements++;
    }
  }

  for (final category in rows[2]) {
    final id = category['id'].toString();
    data.categoryNames[id] = category['name'].toString();
    data.categoryStyles[id] = category;
  }

  for (final account in accounts) {
    if (account['is_active'] != true) {
      continue;
    }

    final balance = balances[account['id'].toString()]!;
    final total = metric(account['currency'].toString());

    total.cash += balance;
    total.activeAccounts++;

    data.accounts.add({...account, 'balance_cents': balance});
  }

  const nativeLabels = {
    'income': 'Ingreso',
    'expense': 'Gasto',
    'transfer': 'Transferencia',
    'deposit': 'Depósito',
    'withdrawal': 'Retiro',
    'adjustment': 'Ajuste',
  };

  for (final tx in transactions) {
    final currency = tx['currency'].toString();
    final type = tx['transaction_type'].toString();
    final account = accountMap[tx['account_id'].toString()];

    if (account == null || account['currency'] != currency) {
      throw StateError('Un movimiento no coincide con la moneda de su cuenta.');
    }

    final destination = accountMap[tx['destination_account_id']?.toString()];

    if (type == 'transfer' &&
        (destination == null || destination['currency'] != currency)) {
      throw StateError(
        'Una transferencia tiene cuentas de monedas diferentes.',
      );
    }

    final date = _dashboardDate(tx['transaction_date']);
    final amount = moneyCents(tx['amount']);

    if (type == 'income') {
      if (period.contains(date)) {
        metric(currency).income += amount;
      }

      if (previous.contains(date)) {
        metric(currency).previousIncome += amount;
      }
    }

    if (type == 'expense') {
      expense(amount, date, currency, tx['category_id']);
    }

    final description = tx['description']?.toString().trim() ?? '';
    final label = nativeLabels[type] ?? type;

    final detail = type == 'transfer'
        ? '${account['name']} → ${destination?['name']}'
        : '$label · ${account['name']}';

    final flow = ['income', 'deposit'].contains(type)
        ? 1
        : ['expense', 'withdrawal'].contains(type)
        ? -1
        : 0;

    event(
      DashboardEvent(
        'account:${tx['id']}',
        date,
        description.isEmpty ? label : description,
        detail,
        currency,
        amount,
        flow,
        DashboardTarget.transactions,
        null,
        tx['category_id']?.toString(),
      ),
    );
  }

  final cardBalances = <String, Map<String, int?>>{
    for (final card in cards)
      card['id'].toString(): {
        for (final currency in cardCurrencies)
          currency: cardOpening(card, currency),
      },
  };

  const cardLabels = {
    'purchase': 'Compra con tarjeta',
    'interest': 'Intereses de tarjeta',
    'fee': 'Comisión de tarjeta',
    'payment': 'Pago de tarjeta',
    'refund': 'Devolución de tarjeta',
    'adjustment': 'Ajuste de tarjeta',
  };

  for (final tx in cardTransactions) {
    final id = tx['credit_card_id'].toString();
    final currency = tx['currency'].toString();
    final card = cardMap[id];

    if (card == null || !cardCurrencies.contains(currency)) {
      throw StateError('Movimiento de tarjeta no válido.');
    }

    final type = tx['transaction_type'].toString();
    final effect = cardEffects[type];
    final amount = moneyCents(tx['amount']);
    final current = cardBalances[id]![currency];

    cardBalances[id]![currency] = effect == null || current == null
        ? null
        : current + effect * amount;

    final date = _dashboardDate(tx['transaction_date']);

    if (effect != null &&
        type != 'payment' &&
        tx['is_receivable_funding'] != true) {
      expense(effect * amount, date, currency, tx['category_id']);
    }

    final description = tx['description']?.toString().trim() ?? '';
    final label = cardLabels[type] ?? type;

    event(
      DashboardEvent(
        'card:${tx['id']}',
        date,
        description.isEmpty ? label : description,
        '$label · ${card['name']}',
        currency,
        amount,
        type == 'refund'
            ? 1
            : effect == null
            ? 0
            : -1,
        DashboardTarget.cards,
        id,
        tx['category_id']?.toString(),
      ),
    );
  }

  for (final card in cards) {
    final values = cardBalances[card['id'].toString()]!;

    for (final currency in cardCurrencies) {
      final total = metric(currency);
      final balance = values[currency];

      if (balance == null) {
        total.cardKnown = false;
        continue;
      }

      if (balance > 0) {
        total.cardDebt += balance;
      }

      if (balance < 0) {
        total.cardCredit -= balance;
      }
    }

    if (card['is_active'] == true) {
      final total = metric(card['currency'].toString());
      final available = cardAvailable(card, values['NIO'], values['USD']);
      final previousAvailable = total.cardAvailable;

      total.cardAvailable = previousAvailable == null || available == null
          ? null
          : previousAvailable + available;
    }
  }

  final principalPaid = <String, int>{};

  for (final payment in debtPayments) {
    final id = payment['debt_id'].toString();
    final currency = payment['currency'].toString();
    final debt = debtMap[id];

    if (debt == null || debt['currency'] != currency) {
      throw StateError('Un abono tiene moneda diferente a su deuda.');
    }

    principalPaid[id] =
        (principalPaid[id] ?? 0) + moneyCents(payment['principal_amount']);

    final date = _dashboardDate(payment['payment_date']);

    expense(
      moneyCents(payment['interest_amount']) +
          moneyCents(payment['fee_amount']),
      date,
      currency,
      null,
    );

    event(
      DashboardEvent(
        'debt:${payment['id']}',
        date,
        'Abono de deuda',
        '${debt['description']}'
            '${payment['account_id'] == null ? ' · Registro manual' : ''}',
        currency,
        debtPaymentTotalCents(payment),
        payment['account_id'] == null ? 0 : -1,
        DashboardTarget.debts,
        id,
      ),
    );
  }

  for (final debt in debts) {
    if (debt['status'] == 'cancelled') {
      continue;
    }

    final pending =
        moneyCents(debt['original_amount']) -
        (principalPaid[debt['id'].toString()] ?? 0);

    if (pending < 0) {
      throw StateError('Hay una deuda con abonos superiores a su capital.');
    }

    final total = metric(debt['currency'].toString());
    total.loans += pending;

    final due = DateTime.tryParse('${debt['due_date']}');

    if (pending == 0 ||
        due == null ||
        !['active', 'overdue'].contains(debt['status'])) {
      continue;
    }

    final day = DateTime(due.year, due.month, due.day);

    if (day.isBefore(today)) {
      total.overdue += pending;
      total.overdueCount++;
    }

    if (day == today) {
      total.dueToday += pending;
      total.todayCount++;
    }
  }

  for (final budget in rows[3]) {
    final budgetMonth = _dashboardDate(budget['month']);
    if (!period.overlapsMonth(budgetMonth)) {
      continue;
    }

    final total = metric(budget['currency'].toString());
    final limit = moneyCents(budget['budget_amount']);
    final spent =
        monthlyExpenses[expenseKey(
          budgetMonth,
          budget['currency'].toString(),
          budget['category_id'],
        )] ??
        0;

    if (spent > limit) {
      total.exceededBudgets++;
    }

    data.budgets.add({
      ...budget,
      'name':
          '${data.categoryNames[budget['category_id'].toString()] ?? 'Categoría no disponible'} · ${dashboardMonth(budgetMonth)}',
      'limit_cents': limit,
      'spent_cents': spent,
    });
  }

  data.accounts.sort(
    (a, b) => (b['balance_cents'] as int).compareTo(a['balance_cents'] as int),
  );

  data.events.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });

  return data;
}
