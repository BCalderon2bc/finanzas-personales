import '../../core/supabase_client.dart';
import '../../utils/money.dart';

enum DashboardTarget { accounts, transactions, categories, budgets, debts, cards, reports }

class DashboardCurrency {
  int cash = 0, income = 0, expense = 0, previousIncome = 0, previousExpense = 0;
  int loans = 0, overdue = 0, dueToday = 0, overdueCount = 0, todayCount = 0;
  int cardDebt = 0, cardCredit = 0, cardAvailable = 0, activeAccounts = 0;
  int exceededBudgets = 0, movements = 0;
  bool cardKnown = true;
  final categories = <String, int>{};
  int get net => income - expense;
  int get previousNet => previousIncome - previousExpense;
  int? get liabilities => cardKnown ? loans + cardDebt : null;
  int? get position => cardKnown ? cash + cardCredit - loans - cardDebt : null;
}

class DashboardEvent {
  const DashboardEvent(this.id, this.date, this.title, this.detail,
      this.currency, this.cents, this.flow, this.target, [this.entityId]);
  final String id, title, detail, currency;
  final DateTime date;
  final int cents, flow;
  final DashboardTarget target;
  final String? entityId;
}

class DashboardOverview {
  DashboardOverview(this.month);
  final DateTime month;
  final loadedAt = DateTime.now();
  final currencies = {'NIO': DashboardCurrency(), 'USD': DashboardCurrency()};
  final categoryNames = <String, String>{};
  final accounts = <Map<String, dynamic>>[];
  final budgets = <Map<String, dynamic>>[];
  final events = <DashboardEvent>[];
}

String dashboardMoney(int? cents, String currency) => cents == null
    ? 'Por revisar'
    : '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

String dashboardMonth(DateTime date) {
  const names = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  return '${names[date.month - 1]} ${date.year}';
}

bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

DateTime _dashboardDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) throw const FormatException('Hay un movimiento con fecha inválida.');
  return date;
}

Future<List<Map<String, dynamic>>> _dashboardRows(
    String table, String columns, String userId) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += 500) {
    final result = await supabase.from(table).select(columns)
        .eq('user_id', userId).order('id').range(offset, offset + 499);
    final page = List<Map<String, dynamic>>.from(result);
    rows.addAll(page);
    if (page.length < 500) break;
  }
  return rows;
}

Future<DashboardOverview> loadDashboardOverview(DateTime month) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
  final rows = await Future.wait([
    _dashboardRows('accounts',
        'id, name, account_type, currency, opening_balance, is_active', user.id),
    _dashboardRows('transactions',
        'id, account_id, destination_account_id, category_id, transaction_type, amount, currency, transaction_date, description', user.id),
    _dashboardRows('categories', 'id, name', user.id),
    _dashboardRows('budgets', 'id, category_id, currency, budget_amount, month', user.id),
    _dashboardRows('debts', 'id, description, currency, original_amount, status, due_date', user.id),
    _dashboardRows('debt_payments',
        'id, debt_id, account_id, principal_amount, interest_amount, fee_amount, currency, payment_date, is_voided', user.id),
    _dashboardRows('credit_cards',
        'id, name, currency, credit_limit, opening_balance, is_active', user.id),
    _dashboardRows('credit_card_transactions',
        'id, credit_card_id, account_id, category_id, transaction_type, amount, currency, transaction_date, description, is_voided', user.id),
  ]);
  final accounts = rows[0], transactions = rows[1], debts = rows[4], cards = rows[6];
  final debtPayments = rows[5].where((p) => p['is_voided'] != true).toList();
  final cardTransactions = rows[7].where((p) => p['is_voided'] != true).toList();
  final cardPayments = cardTransactions.where((p) => p['transaction_type'] == 'payment').toList();
  final balances = calculateBalances(accounts, transactions,
      cardPayments: cardPayments, debtPayments: debtPayments);
  final data = DashboardOverview(DateTime(month.year, month.month));
  final previous = DateTime(month.year, month.month - 1);
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final accountMap = {for (final a in accounts) a['id'].toString(): a};
  final debtMap = {for (final d in debts) d['id'].toString(): d};
  final cardMap = {for (final c in cards) c['id'].toString(): c};

  DashboardCurrency metric(String currency) =>
      data.currencies[currency] ?? (throw StateError('Moneda no reconocida: $currency'));

  void expense(int cents, DateTime date, String currency, dynamic categoryId) {
    if (cents == 0) return;
    final total = metric(currency);
    if (_sameMonth(date, month)) {
      total.expense += cents;
      final key = categoryId?.toString() ?? 'none';
      total.categories[key] = (total.categories[key] ?? 0) + cents;
    } else if (_sameMonth(date, previous)) {
      total.previousExpense += cents;
    }
  }

  void event(DashboardEvent item) {
    if (_sameMonth(item.date, month)) {
      data.events.add(item);
      metric(item.currency).movements++;
    }
  }

  for (final category in rows[2]) {
    data.categoryNames[category['id'].toString()] = category['name'].toString();
  }
  for (final account in accounts) {
    if (account['is_active'] != true) continue;
    final balance = balances[account['id'].toString()]!;
    final total = metric(account['currency'].toString());
    total.cash += balance;
    total.activeAccounts++;
    data.accounts.add({...account, 'balance_cents': balance});
  }

  const nativeLabels = {'income': 'Ingreso', 'expense': 'Gasto', 'transfer': 'Transferencia',
    'deposit': 'Depósito', 'withdrawal': 'Retiro', 'adjustment': 'Ajuste'};
  for (final tx in transactions) {
    final currency = tx['currency'].toString(), type = tx['transaction_type'].toString();
    final account = accountMap[tx['account_id'].toString()];
    if (account == null || account['currency'] != currency) {
      throw StateError('Un movimiento no coincide con la moneda de su cuenta.');
    }
    final destination = accountMap[tx['destination_account_id']?.toString()];
    if (type == 'transfer' && (destination == null || destination['currency'] != currency)) {
      throw StateError('Una transferencia tiene cuentas de monedas diferentes.');
    }
    final date = _dashboardDate(tx['transaction_date']);
    final amount = moneyCents(tx['amount']);
    if (type == 'income') {
      if (_sameMonth(date, month)) metric(currency).income += amount;
      if (_sameMonth(date, previous)) metric(currency).previousIncome += amount;
    }
    if (type == 'expense') expense(amount, date, currency, tx['category_id']);
    final description = tx['description']?.toString().trim() ?? '';
    final label = nativeLabels[type] ?? type;
    final detail = type == 'transfer'
        ? '${account['name']} → ${destination?['name']}'
        : '$label · ${account['name']}';
    final flow = ['income', 'deposit'].contains(type) ? 1
        : ['expense', 'withdrawal'].contains(type) ? -1 : 0;
    event(DashboardEvent('account:${tx['id']}', date,
        description.isEmpty ? label : description, detail, currency,
        amount, flow, DashboardTarget.transactions));
  }

  final cardBalances = <String, int?>{
    for (final card in cards) card['id'].toString(): moneyCents(card['opening_balance'] ?? 0),
  };
  const cardEffects = {'purchase': 1, 'interest': 1, 'fee': 1, 'payment': -1, 'refund': -1};
  const cardLabels = {'purchase': 'Compra con tarjeta', 'interest': 'Intereses de tarjeta',
    'fee': 'Comisión de tarjeta', 'payment': 'Pago de tarjeta',
    'refund': 'Devolución de tarjeta', 'adjustment': 'Ajuste de tarjeta'};

  for (final tx in cardTransactions) {
    final id = tx['credit_card_id'].toString(), currency = tx['currency'].toString();
    final card = cardMap[id];
    if (card == null || card['currency'] != currency) {
      throw StateError('Un movimiento tiene moneda diferente a su tarjeta.');
    }
    final type = tx['transaction_type'].toString(), effect = cardEffects[type];
    final amount = moneyCents(tx['amount']);
    if (effect == null) {
      cardBalances[id] = null;
    } else if (cardBalances[id] != null) {
      cardBalances[id] = cardBalances[id]! + effect * amount;
    }
    final date = _dashboardDate(tx['transaction_date']);
    if (effect != null && type != 'payment') {
      expense(effect * amount, date, currency, tx['category_id']);
    }
    final description = tx['description']?.toString().trim() ?? '';
    final label = cardLabels[type] ?? type;
    event(DashboardEvent('card:${tx['id']}', date,
        description.isEmpty ? label : description, '$label · ${card['name']}',
        currency, amount, type == 'refund' ? 1 : effect == null ? 0 : -1,
        DashboardTarget.cards, id));
  }

  for (final card in cards) {
    final total = metric(card['currency'].toString());
    final balance = cardBalances[card['id'].toString()];
    if (balance == null) {
      total.cardKnown = false;
      continue;
    }
    if (balance > 0) total.cardDebt += balance;
    if (balance < 0) total.cardCredit -= balance;
    if (card['is_active'] == true) {
      final limit = moneyCents(card['credit_limit']);
      total.cardAvailable += (limit - (balance > 0 ? balance : 0)).clamp(0, limit).toInt();
    }
  }

  final principalPaid = <String, int>{};
  for (final payment in debtPayments) {
    final id = payment['debt_id'].toString(), currency = payment['currency'].toString();
    final debt = debtMap[id];
    if (debt == null || debt['currency'] != currency) {
      throw StateError('Un abono tiene moneda diferente a su deuda.');
    }
    principalPaid[id] = (principalPaid[id] ?? 0) + moneyCents(payment['principal_amount']);
    final date = _dashboardDate(payment['payment_date']);
    expense(moneyCents(payment['interest_amount']) + moneyCents(payment['fee_amount']),
        date, currency, null);
    event(DashboardEvent('debt:${payment['id']}', date, 'Abono de deuda',
        '${debt['description']}${payment['account_id'] == null ? ' · Registro manual' : ''}',
        currency, debtPaymentTotalCents(payment), payment['account_id'] == null ? 0 : -1,
        DashboardTarget.debts, id));
  }

  for (final debt in debts) {
    if (debt['status'] == 'cancelled') continue;
    final pending = moneyCents(debt['original_amount']) -
        (principalPaid[debt['id'].toString()] ?? 0);
    if (pending < 0) throw StateError('Hay una deuda con abonos superiores a su capital.');
    final total = metric(debt['currency'].toString());
    total.loans += pending;
    final due = DateTime.tryParse('${debt['due_date']}');
    if (pending == 0 || due == null || !['active', 'overdue'].contains(debt['status'])) continue;
    final day = DateTime(due.year, due.month, due.day);
    if (day.isBefore(today)) { total.overdue += pending; total.overdueCount++; }
    if (day == today) { total.dueToday += pending; total.todayCount++; }
  }

  for (final budget in rows[3]) {
    if (!_sameMonth(_dashboardDate(budget['month']), month)) continue;
    final currency = budget['currency'].toString();
    final total = metric(currency);
    final limit = moneyCents(budget['budget_amount']);
    final spent = total.categories[budget['category_id'].toString()] ?? 0;
    if (spent > limit) total.exceededBudgets++;
    data.budgets.add({...budget,
      'name': data.categoryNames[budget['category_id'].toString()] ?? 'Categoría no disponible',
      'limit_cents': limit, 'spent_cents': spent,
    });
  }
  data.accounts.sort((a, b) => (b['balance_cents'] as int).compareTo(a['balance_cents'] as int));
  data.events.sort((a, b) {
    final result = b.date.compareTo(a.date);
    return result != 0 ? result : a.id.compareTo(b.id);
  });
  return data;
}