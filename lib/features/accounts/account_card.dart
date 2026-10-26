import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../widgets/bank_brand.dart';

const debitDesignLabels = {
  'classic': 'Color del banco',
  'gold': 'Dorado',
  'platinum': 'Plateado',
  'black': 'Negro',
};
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key, required this.account, required this.balanceCents,
    this.balanceLabel = 'Saldo registrado', this.onEdit, this.onToggle,
  });
  final Map<String, dynamic> account;
  final int balanceCents;
  final String balanceLabel;
  final VoidCallback? onEdit, onToggle;

  Widget bankLogo(String bank, bool cash) => BankLogo(
    name: bank,
    fallbackIcon: cash ? Icons.payments_outlined : Icons.account_balance_outlined,
  );

  @override
  Widget build(BuildContext context) {
    final raw = account['card_design'];
    final design = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final type = account['account_type']?.toString() ?? '';
    final debit = design['enabled'] == true && ['savings', 'checking'].contains(type);
    final active = account['is_active'] != false;
    final institution = account['financial_institutions'];
    final bank = institution is Map ? institution['name']?.toString() ?? '' : '';
    final network = design['network']?.toString() ?? '';
    final digits = design['last_four']?.toString() ?? '';
    final ending = RegExp(r'^\d{4}$').hasMatch(digits) ? digits : '••••';
    final currency = account['currency']?.toString() ?? 'NIO';
    final reference = account['account_reference']?.toString().trim() ?? '';
    final notes = account['notes']?.toString().trim() ?? '';
    const types = {
      'savings': 'Cuenta de ahorro', 'checking': 'Cuenta corriente',
      'cash': 'Efectivo', 'wallet': 'Billetera digital',
      'investment': 'Inversión', 'other': 'Otra cuenta',
    };

    final bankColors = type == 'cash'
        ? const [Color(0xFF065F46), Color(0xFF0D9470)]
        : bankGradient(bank);

    final colors = switch (design['style']) {
      'gold' => const [Color(0xFF63451E), Color(0xFFB88A43)],
      'platinum' => const [Color(0xFF334155), Color(0xFF94A3B8)],
      'black' => const [Color(0xFF101319), Color(0xFF303B4C)],
      _ => bankColors,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colors.first.withAlpha(35),
              blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 112, height: 42,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(11)),
            child: bankLogo(bank, type == 'cash'),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(24),
                borderRadius: BorderRadius.circular(20)),
            child: Text(active ? 'Activa' : 'Inactiva',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(account['name']?.toString() ?? 'Mi cuenta',
            style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(bank.isEmpty ? types[type] ?? 'Cuenta' : '$bank · ${types[type] ?? 'Cuenta'}',
            style: TextStyle(color: Colors.white.withAlpha(205), fontSize: 13)),
        const SizedBox(height: 14),
        Text(balanceLabel, style: TextStyle(
            color: Colors.white.withAlpha(205), fontSize: 13)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(formatMoneyCents(balanceCents, currency),
              style: const TextStyle(color: Colors.white,
                  fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        ),
        if (debit) ...[
          const SizedBox(height: 14),
          Divider(color: Colors.white.withAlpha(40), height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DÉBITO', style: TextStyle(
                  color: Colors.white.withAlpha(190), fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 5),
              Text('••••  $ending', style: const TextStyle(
                  color: Colors.white, fontSize: 18, letterSpacing: 2)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(9)),
              child: network == 'visa' || network == 'mastercard'
                  ? Image.asset('assets/networks/$network.png',
                  width: 48, height: 25, fit: BoxFit.contain)
                  : const Icon(Icons.credit_card_outlined, color: Color(0xFF334155)),
            ),
          ]),
        ],
        if (reference.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Referencia: $reference',
              style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 13)),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style: TextStyle(
              color: Colors.white.withAlpha(190), fontSize: 13)),
        ],
        if (onEdit != null || onToggle != null) ...[
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
            if (onEdit != null) TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar')),
            if (onToggle != null) TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onToggle,
                icon: Icon(active ? Icons.pause_circle_outline
                    : Icons.play_circle_outline, size: 18),
                label: Text(active ? 'Desactivar' : 'Activar')),
          ]),
        ],
      ]),
    );
  }
}