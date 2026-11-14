import '../../data/debt_installment_logic.dart';
import '../../data/payment_agenda_labels.dart';
import '../../data/period_logic.dart' show isoDay;
import '../../data/exchange_rate.dart';
import '../../data/person_account_logic.dart';
import '../../data/receivable_loan_logic.dart';
import '../../features/credit_cards/credit_card_balances.dart';
import '../../utils/money.dart';

typedef Rows = List<Map<String, dynamic>>;
typedef Amount = MapEntry<String, int>;

class ObligationData {
  const ObligationData({
    required this.userId,
    required this.cards,
    required this.cardMovements,
    required this.debts,
    required this.debtPayments,
    this.installmentData,
    required this.loans,
    required this.loanPayments,
    required this.people,
    required this.personEntries,
  });

  final String userId;
  final DebtInstallmentData? installmentData;
  final Rows cards,
      cardMovements,
      debts,
      debtPayments,
      loans,
      loanPayments,
      people,
      personEntries;
}

class ObligationSection {
  const ObligationSection(
    this.title,
    this.snapshot,
    this.activity,
    this.ranking, {
    this.note,
  });
  final String title;
  final List<Amount> snapshot, activity, ranking;
  final String? note;
}

List<ObligationSection> obligationStatistics(
  ObligationData data,
  ExchangeRate rate,
  String currency,
  DateTime start,
  DateTime end,
  DateTime now,
) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  bool inRange(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date != null &&
        !day(date).isBefore(day(start)) &&
        !day(date).isAfter(day(end));
  }

  int convert(int cents, Object? source) =>
      rate.convert(cents, '$source', currency);
  int field(Map<String, dynamic> row, String key) => moneyCents(row[key] ?? 0);
  Iterable<Map<String, dynamic>> valid(Rows rows) =>
      rows.where((row) => row['is_voided'] != true);
  Amount amount(String label, int cents) => MapEntry(label, cents);
  int sum(List<Amount> rows) =>
      rows.fold<int>(0, (total, row) => total + row.value);

  final cardRanking = <Amount>[];
  var cardCredit = 0,
      cardCharges = 0,
      cardPayments = 0,
      cardRefunds = 0,
      unknownCards = 0;
  final cardIds = data.cards.map((card) => card['id']).toSet();
  for (final card in data.cards) {
    var debt = 0, credit = 0;
    var known = true;
    for (final source in cardCurrencies) {
      final balance = cardBalance(card, data.cardMovements, source);
      if (balance == null) {
        known = false;
      } else if (balance > 0) {
        debt += convert(balance, source);
      } else if (balance < 0) {
        credit += convert(-balance, source);
      }
    }
    if (!known) {
      unknownCards++;
      continue;
    }
    if (debt > 0)
      cardRanking.add(amount(agendaCardLabel(card, includeName: false), debt));
    cardCredit += credit;
  }
  for (final row in valid(data.cardMovements)) {
    if (!cardIds.contains(row['credit_card_id']) ||
        !inRange(row['transaction_date']))
      continue;
    final type = row['transaction_type'];
    if (!cardEffects.containsKey(type)) continue;
    final cents = convert(field(row, 'amount'), row['currency']);
    if (type == 'payment') {
      cardPayments += cents;
    } else if (type == 'refund') {
      cardRefunds += cents;
    } else {
      cardCharges += cents;
    }
  }

  final debtRanking = <Amount>[];
  var debtPrincipalPaid = 0, debtCosts = 0;
  for (final debt in data.debts.where((row) => row['status'] != 'cancelled')) {
    var paid = 0;
    for (final row in valid(
      data.debtPayments,
    ).where((row) => row['debt_id'] == debt['id'])) {
      if (row['currency'] != debt['currency']) {
        throw StateError('Un abono tiene una moneda distinta a su deuda.');
      }
      final principal = field(row, 'principal_amount');
      paid += principal;
      if (inRange(row['payment_date'])) {
        debtPrincipalPaid += convert(principal, row['currency']);
        debtCosts += convert(
          field(row, 'interest_amount') + field(row, 'fee_amount'),
          row['currency'],
        );
      }
    }
    final pending = field(debt, 'original_amount') - paid;
    if (pending > 0 && debt['status'] != 'paid')
      debtRanking.add(
        amount('${debt['description']}', convert(pending, debt['currency'])),
      );
  }

  final loanRanking = <Amount>[];
  var overdueLoans = 0, issued = 0, collected = 0, loanInterest = 0;
  for (final loan in valid(data.loans)) {
    final payments = valid(
      data.loanPayments,
    ).where((row) => row['loan_id'] == loan['id']);
    final pending = receivablePending(loan, payments);
    final converted = convert(pending, loan['currency']);
    if (pending > 0) {
      loanRanking.add(amount('${loan['borrower_name']}', converted));
      if (receivableOverdue(loan, pending, now)) overdueLoans += converted;
    }
    if (inRange(loan['loan_date']) && loan['is_historical'] != true) {
      issued += convert(field(loan, 'principal_amount'), loan['currency']);
    }
    for (final row in payments.where((row) => inRange(row['payment_date']))) {
      collected += convert(field(row, 'principal_amount'), row['currency']);
      loanInterest += convert(field(row, 'interest_amount'), row['currency']);
    }
  }

  final personRanking = <Amount>[];
  var owed = 0, receivable = 0, personIncrease = 0, personDecrease = 0;
  for (final person in data.people.where((row) => row['is_active'] == true)) {
    final own = person['user_id'] == data.userId;
    final direction = own ? 1 : -1;
    final entries = valid(
      data.personEntries,
    ).where((row) => row['person_account_id'] == person['id']);
    final balance = convert(personAccountBalance(entries) * direction, 'NIO');
    final name = own ? '${person['name']}' : '${person['name']} · Compartida';
    if (balance > 0) {
      owed += balance;
      personRanking.add(amount('$name · Le debes', balance));
    } else if (balance < 0) {
      receivable -= balance;
      personRanking.add(amount('$name · Te debe', -balance));
    }
    for (final row in entries.where((row) => inRange(row['entry_date']))) {
      final delta = convert(personAccountBalance([row]) * direction, 'NIO');
      if (delta > 0) personIncrease += delta;
      if (delta < 0) personDecrease -= delta;
    }
  }

  final overdueInstallments = <Amount>[];
  var unknownInstallments = 0;
  final schedule = data.installmentData;
  if (schedule != null) {
    for (final debt in data.debts.where(
      (debt) => ['active', 'overdue'].contains(debt['status']),
    )) {
      for (final row in schedule.currentFor('${debt['id']}')) {
        final due = DateTime.tryParse('${row['due_date']}');
        if (due == null || !day(due).isBefore(day(now))) continue;
        final pending = schedule.progress(row).remaining;
        if (pending == null) {
          unknownInstallments++;
        } else if (pending > 0) {
          overdueInstallments.add(
            amount(
              '${debt['description']} · Cuota ${row['number']} · ${isoDay(due)}',
              convert(pending, row['currency']),
            ),
          );
        }
      }
    }
  }

  return [
    ObligationSection(
      'Tarjetas de crédito',
      [
        amount('Deuda registrada', sum(cardRanking)),
        amount('Saldo a favor', cardCredit),
      ],
      [
        amount('Cargos', cardCharges),
        amount('Pagos', cardPayments),
        amount('Devoluciones y créditos', cardRefunds),
      ],
      cardRanking,
      note: unknownCards == 0
          ? null
          : '$unknownCards tarjetas con saldo por revisar. Los saldos mostrados incluyen las tarjetas con saldo calculable.',
    ),
    ObligationSection(
      'Deudas y préstamos recibidos',
      [amount('Capital pendiente', sum(debtRanking))],
      [
        amount('Capital abonado', debtPrincipalPaid),
        amount('Intereses y cargos pagados', debtCosts),
      ],
      debtRanking,
    ),
    ObligationSection(
      'Préstamos por cobrar',
      [
        amount('Capital por cobrar', sum(loanRanking)),
        amount('Capital vencido', overdueLoans),
      ],
      [
        amount('Capital prestado', issued),
        amount('Capital recuperado', collected),
        amount('Intereses cobrados', loanInterest),
      ],
      loanRanking,
    ),
    ObligationSection(
      'Cuentas con personas',
      [amount('Les debes', owed), amount('Te deben', receivable)],
      [
        amount('Aumentos del saldo a tu cargo', personIncrease),
        amount('Reducciones del saldo a tu cargo', personDecrease),
      ],
      personRanking,
      note:
          'Incluye cuentas activas propias y compartidas, vistas desde tu lado.',
    ),
    if (schedule != null)
      ObligationSection(
        'Cuotas vencidas',
        [amount('Monto pendiente vencido', sum(overdueInstallments))],
        const [],
        overdueInstallments,
        note:
            '${overdueInstallments.length} cuotas pendientes con fecha anterior a hoy.'
            '${unknownInstallments == 0 ? '' : ' $unknownInstallments cuotas con saldo por revisar.'}',
      ),
  ];
}
