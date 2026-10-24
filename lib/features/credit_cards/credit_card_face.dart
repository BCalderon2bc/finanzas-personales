import 'package:flutter/material.dart';
import '../../widgets/bank_brand.dart';

const cardTierLabels = {
  'unspecified': 'Sin especificar',
  'classic': 'Clásica',
  'gold': 'Oro',
  'platinum': 'Platinum',
  'signature': 'Signature',
  'infinite': 'Infinite',
  'black': 'Black',
};

String cardBankName(Map<String, dynamic> card) {
  final institution = card['financial_institutions'];
  return institution is Map ? institution['name']?.toString() ?? '' : '';
}

String cardBankKey(String name) => bankKey(name);

class CreditCardFace extends StatelessWidget {
  const CreditCardFace({super.key, required this.card});
  final Map<String, dynamic> card;

  Widget bankLogo(String bank) => BankLogo(name: bank);

  @override
  Widget build(BuildContext context) {
    final bank = cardBankName(card);
    final bankKey = cardBankKey(bank);
    final tier = card['card_tier']?.toString() ?? 'unspecified';
    final network = card['network']?.toString().trim().toLowerCase() ?? '';
    final reference = card['card_reference']?.toString() ?? '';
    final digits = reference.replaceAll(RegExp(r'\D'), '');
    final ending = digits.length >= 4 ? digits.substring(digits.length - 4) : '••••';
    final image = switch ('$bankKey/$network/$tier') {
      'bac/visa/platinum' => 'assets/cards/bac_visa_platinum.webp',
      'banpro/mastercard/platinum' => 'assets/cards/banpro_mastercard_platinum.webp',
      _ => null,
    };

    final colors = bankGradient(bank);

    Widget customFace() => Container(
      constraints: const BoxConstraints(minHeight: 208),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(
              tier == 'unspecified' ? 'CRÉDITO' : cardTierLabels[tier]?.toUpperCase() ?? 'CRÉDITO',
              style: const TextStyle(color: Colors.white,
                  fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w600))),
          Icon(Icons.contactless_outlined, color: Colors.white.withAlpha(190)),
        ]),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Container(
          width: 42, height: 31,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF1D598), Color(0xFFB88A43)]),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.grid_view_rounded,
              color: Color(0xFF806334), size: 24),
        )),
        const SizedBox(height: 20),
        Text('••••  ••••  ••••  $ending', style: const TextStyle(
            color: Colors.white, fontSize: 19, letterSpacing: 1.5)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(card['name']?.toString() ?? 'Mi tarjeta',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12))),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(7)),
            child: network == 'visa' || network == 'mastercard'
                ? Image.asset('assets/networks/$network.png',
                width: 48, height: 24, fit: BoxFit.contain)
                : Text(network.isEmpty ? 'CRÉDITO' : network.toUpperCase(),
                style: const TextStyle(color: Color(0xFF172033),
                    fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 125, height: 46,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: bankLogo(bank),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(bank.isEmpty ? 'Banco sin asignar' : bank,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
      ]),
      const SizedBox(height: 12),
      if (image == null) customFace()
      else ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Image.asset(image, fit: BoxFit.contain,
              semanticLabel: 'Imagen de referencia del producto bancario',
              errorBuilder: (_, __, ___) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: 340, child: customFace()))),
        ),
      ),
      const SizedBox(height: 10),
      Text(
          '${network.isEmpty ? 'Marca sin especificar' : network.toUpperCase()}'
              ' · ${cardTierLabels[tier] ?? tier} · Terminación $ending',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
    ]);
  }
}