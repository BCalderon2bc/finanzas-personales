import '../utils/money.dart';

class InstallmentProgress {
  const InstallmentProgress({
    required this.installment,
    required this.paid,
    required this.remaining,
  });
  final Map<String, dynamic> installment;
  final int paid;
  final int? remaining;
  bool get settled => remaining == 0;
}

InstallmentProgress installmentProgress(
  Map<String, dynamic> i,
  List<Map<String, dynamic>> links,
  List<Map<String, dynamic>> payments,
) {
  final byId = {for (final p in payments) '${p['id']}': p};
  final seen = <String>{};
  var paid = 0, known = true;
  for (final link in links) {
    if ('${link['installment_id']}' != '${i['id']}' ||
        !seen.add('${link['payment_id']}')) {
      continue;
    }
    final p = byId['${link['payment_id']}'];
    if (p == null) {
      known = false;
      continue;
    }
    if (p['is_voided'] == true) {
      continue;
    }
    if ('${p['debt_id']}' != '${i['debt_id']}' ||
        p['currency'] != i['currency']) {
      known = false;
      continue;
    }
    paid += debtPaymentTotalCents(p);
  }
  final amount = moneyCents(i['amount']);
  return InstallmentProgress(
    installment: i,
    paid: paid,
    remaining: known ? (amount - paid).clamp(0, amount).toInt() : null,
  );
}

class DebtInstallmentData {
  const DebtInstallmentData({
    required this.installments,
    required this.links,
    required this.payments,
  });
  final List<Map<String, dynamic>> installments, links, payments;
  InstallmentProgress progress(Map<String, dynamic> i) =>
      installmentProgress(i, links, payments);
  List<Map<String, dynamic>> currentFor(String debtId) =>
      installments
          .where(
            (i) =>
                '${i['debt_id']}' == debtId &&
                i['is_archived'] != true &&
                i['is_voided'] != true,
          )
          .toList()
        ..sort((a, b) {
          final d = '${a['due_date']}'.compareTo('${b['due_date']}');
          return d != 0 ? d : '${a['id']}'.compareTo('${b['id']}');
        });
  List<Map<String, dynamic>> payableFor(String debtId) =>
      currentFor(debtId).where((i) => !progress(i).settled).toList();
}
