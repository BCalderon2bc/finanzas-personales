import 'dart:math' as math;

class LoanInstallment {
  const LoanInstallment(this.number, this.date, this.principal, this.interest, this.balance);
  final int number, principal, interest, balance;
  final DateTime date;
  int get total => principal + interest;
}

List<LoanInstallment> buildLoanSchedule({
  required int principalCents,
  required int months,
  required double annualRate,
  required String method,
  required DateTime firstDue,
}) {
  if (principalCents <= 0 || months < 1 || months > 600) {
    throw const FormatException('Introduce capital positivo y un plazo de 1 a 600 meses.');
  }
  if (months > principalCents) {
    throw const FormatException('Reduce el plazo para distribuir el capital en centavos.');
  }
  if (!annualRate.isFinite || annualRate < 0 ||
      !['none', 'flat', 'reducing_balance'].contains(method)) {
    throw const FormatException('La tasa o el método no son válidos.');
  }
  final rate = method == 'none' ? 0.0 : annualRate / 1200;
  final flatInterest = principalCents * rate;
  if (!flatInterest.isFinite) throw const FormatException('La tasa es demasiado grande.');
  final rawPayment = method != 'reducing_balance' ? 0.0
      : rate == 0 ? principalCents / months
      : principalCents * rate / (1 - math.pow(1 + rate, -months));
  if (!rawPayment.isFinite) throw const FormatException('No se pudo calcular la cuota.');
  final fixedPayment = rawPayment.round();
  final rows = <LoanInstallment>[];
  int balance = principalCents;

  for (var i = 0; i < months && balance > 0; i++) {
    final interest = method == 'none' ? 0
        : method == 'flat' ? flatInterest.round() : (balance * rate).round();
    final capital = method == 'reducing_balance'
        ? i == months - 1 ? balance
        : (fixedPayment - interest).clamp(0, balance).toInt()
        : principalCents ~/ months + (i < principalCents % months ? 1 : 0);
    if (capital <= 0) {
      throw const FormatException('La cuota redondeada no amortiza capital. Reduce el plazo o revisa la tasa.');
    }
    balance -= capital;
    final month = DateTime(firstDue.year, firstDue.month + i);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final due = DateTime(month.year, month.month, math.min(firstDue.day, lastDay));
    rows.add(LoanInstallment(i + 1, due, capital, interest, balance));
  }
  return rows;
}