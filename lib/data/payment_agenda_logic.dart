import '../utils/money.dart';
import 'card_statement_logic.dart';
import 'debt_installment_logic.dart';

enum AgendaKind { cardPayment, cardCut, loanMaturity, loanInstallment }

class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    required this.entity,
    this.currency,
    this.amount,
    this.minimumRemaining,
    this.needsStatement = false,
  });
  final String id, title;
  final AgendaKind kind;
  final DateTime date;
  final Map<String, dynamic> entity;
  final String? currency;
  final int? amount, minimumRemaining;
  final bool needsStatement;
}

List<AgendaItem> buildPaymentAgenda({
  required DateTime today,
  required List<Map<String, dynamic>> cards,
  required CardStatementData statements,
  required List<Map<String, dynamic>> debts,
  required List<Map<String, dynamic>> debtPayments,
  int horizon = 7,
  DebtInstallmentData? installments,
}) {
  final result = <AgendaItem>[];
  bool visible(DateTime d) => daysUntil(d, today) <= horizon;
  for (final card in cards) {
    final current = statements.currentFor('${card['id']}');
    for (final s in current) {
      final p = statements.progress(s), date = statementDate(s['due_date']);
      if (p.settled || date == null || !visible(date)) {
        continue;
      }
      result.add(
        AgendaItem(
          id: 'statement:${s['id']}',
          kind: AgendaKind.cardPayment,
          date: date,
          title: card['name']?.toString() ?? 'Tarjeta',
          entity: card,
          currency: '${s['currency']}',
          amount: p.remaining,
          minimumRemaining: p.minimumRemaining,
        ),
      );
    }
    final paymentDay = int.tryParse('${card['payment_day']}');
    if (current.isEmpty &&
        card['is_active'] == true &&
        paymentDay != null &&
        paymentDay >= 1 &&
        paymentDay <= 31) {
      final date = nextCalendarDay(paymentDay, today);
      if (visible(date)) {
        result.add(
          AgendaItem(
            id: 'payment-date:${card['id']}',
            kind: AgendaKind.cardPayment,
            date: date,
            title: card['name']?.toString() ?? 'Tarjeta',
            entity: card,
            needsStatement: true,
          ),
        );
      }
    }
    final closingDay = int.tryParse('${card['closing_day']}');
    if (card['is_active'] == true &&
        closingDay != null &&
        closingDay >= 1 &&
        closingDay <= 31) {
      final date = nextCalendarDay(closingDay, today);
      if (visible(date)) {
        result.add(
          AgendaItem(
            id: 'closing:${card['id']}',
            kind: AgendaKind.cardCut,
            date: date,
            title: card['name']?.toString() ?? 'Tarjeta',
            entity: card,
          ),
        );
      }
    }
  }
  for (final debt in debts) {
    if (!['active', 'overdue'].contains(debt['status'])) {
      continue;
    }
    final current = installments?.payableFor('${debt['id']}') ?? [];
    if (current.isNotEmpty) {
      for (final i in current) {
        final date = statementDate(i['due_date']);
        if (date == null || !visible(date)) {
          continue;
        }
        result.add(
          AgendaItem(
            id: 'installment:${i['id']}',
            kind: AgendaKind.loanInstallment,
            date: date,
            title: debt['description']?.toString() ?? 'Préstamo',
            entity: debt,
            currency: '${i['currency']}',
            amount: installments!.progress(i).remaining,
          ),
        );
      }
      continue;
    }
    final date = statementDate(debt['due_date']);
    if (date == null || !visible(date)) {
      continue;
    }
    var paid = 0;
    for (final p in debtPayments) {
      if ('${p['debt_id']}' != '${debt['id']}' || p['is_voided'] == true) {
        continue;
      }
      if (p['currency'] != debt['currency']) {
        throw StateError('Un abono no coincide con la moneda de su deuda.');
      }
      paid += moneyCents(p['principal_amount']);
    }
    final pending = moneyCents(debt['original_amount']) - paid;
    if (pending < 0) {
      throw StateError('Una deuda tiene abonos superiores a su capital.');
    }
    if (pending == 0) {
      continue;
    }
    result.add(
      AgendaItem(
        id: 'debt:${debt['id']}',
        kind: AgendaKind.loanMaturity,
        date: date,
        title: debt['description']?.toString() ?? 'Préstamo',
        entity: debt,
        currency: '${debt['currency']}',
        amount: pending,
      ),
    );
  }
  result.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  return result;
}
