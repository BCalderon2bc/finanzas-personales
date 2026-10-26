import 'package:flutter/material.dart';
import '../../utils/money.dart';

class TransactionBalances extends StatelessWidget {
  const TransactionBalances({
    super.key, required this.nioCents, required this.usdCents,
  });
  final int nioCents, usdCents;

  Widget balance(String currency, int cents) {
    final usd = currency == 'USD';
    final colors = usd
        ? const [Color(0xFF064E3B), Color(0xFF0D8262)]
        : const [Color(0xFF172554), Color(0xFF2563EB)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(usd ? 'Dólares' : 'Córdobas',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600))),
          Text(currency, style: TextStyle(
              color: Colors.white.withAlpha(200), fontSize: 11)),
        ]),
        const SizedBox(height: 18),
        FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(formatMoneyCents(cents, currency),
                style: const TextStyle(color: Colors.white,
                    fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
        const SizedBox(height: 8),
        Text('Saldo registrado · cuentas activas',
            style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 11)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    LayoutBuilder(builder: (context, box) {
      final nio = balance('NIO', nioCents);
      final usd = balance('USD', usdCents);
      if (box.maxWidth < 600) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          nio, const SizedBox(height: 12), usd,
        ]);
      }
      return Row(children: [
        Expanded(child: nio), const SizedBox(width: 14), Expanded(child: usd),
      ]);
    }),
    const SizedBox(height: 10),
    const Text('Los saldos incluyen todos los registros y no cambian con los filtros.',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
  ]);
}