import 'package:flutter/material.dart';
import '../../data/exchange_rate.dart';
import '../../utils/money.dart';
import '../../data/receivable_loan_logic.dart';

class ReceivableLoansSummary extends StatelessWidget {
  const ReceivableLoansSummary({super.key, required this.loans, required this.payments, this.displayCurrency, this.exchangeRate});
  final List<Map<String, dynamic>> loans, payments;
  final String? displayCurrency;
  final ExchangeRate? exchangeRate;
  bool get consolidated => displayCurrency != null && exchangeRate != null;
  Widget currencyCard(String currency) {
    int present(int amount, dynamic from) => consolidated
      ? exchangeRate!.convert(amount, from.toString(), currency) : amount;
    var pending = 0, overdue = 0, count = 0, interests = 0;
    final active = loans.where((l) => l['is_voided'] != true && (consolidated || l['currency'] == currency)).toList();
    final ids = active.map((l) => l['id'].toString()).toSet();
    for (final loan in active) {
      final amount = receivablePending(loan, payments);
      pending += present(amount, loan['currency']);
      if (amount > 0) { count++; }
      if (receivableOverdue(loan, amount, DateTime.now())) { overdue += present(amount, loan['currency']); }
    }
    for (final p in payments) {
      if (p['is_voided'] != true && (consolidated || p['currency'] == currency) && ids.contains(p['loan_id'].toString())) {
        interests += present(moneyCents(p['interest_amount']), p['currency']);
      }
    }
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)]),
      borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(currency == 'USD' ? 'POR COBRAR · DÓLARES' : 'POR COBRAR · CÓRDOBAS',
          style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(receivableMoney(pending, currency),
            style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800))),
    const SizedBox(height: 10), Text('$count préstamos pendientes', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6), Text('Capital vencido: ${receivableMoney(overdue, currency)}',
          style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 12)),
        const SizedBox(height: 6), Text('Intereses cobrados · historial: ${receivableMoney(interests, currency)}',
          style: const TextStyle(color: Color(0xFFEDE9FE), fontSize: 12)),
      ]));
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (consolidated) currencyCard(displayCurrency!)
    else LayoutBuilder(builder: (context, box) => box.maxWidth < 650
      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        currencyCard('NIO'), const SizedBox(height: 12), currencyCard('USD')])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: currencyCard('NIO')),
        const SizedBox(width: 14), Expanded(child: currencyCard('USD'))])),
    if (consolidated) const Padding(padding: EdgeInsets.only(top: 10),
      child: Text('Total equivalente calculado con la tasa de Configuraciones.',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
    const SizedBox(height: 10),
    const Text('Es dinero que te deben. No forma parte del efectivo ni del ahorro disponible hasta que lo recibas.',
      style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
  ]);
}
