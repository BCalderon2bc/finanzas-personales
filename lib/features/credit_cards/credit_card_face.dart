import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/bank_brand.dart';
import 'credit_card_products.dart';

const cardTierLabels = {
  'unspecified': 'Sin especificar', 'classic': 'Clásica', 'gold': 'Oro',
  'platinum': 'Platinum', 'signature': 'Signature', 'infinite': 'Infinite', 'black': 'Black',
};

String cardBankName(Map<String, dynamic> card) {
  final institution = card['financial_institutions'];
  return institution is Map ? institution['name']?.toString() ?? '' : '';
}
String cardBankKey(String name) => bankKey(name);

class CreditCardFace extends StatelessWidget {
  const CreditCardFace({super.key, required this.card, this.compact = false});
  final Map<String, dynamic> card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bank = cardBankName(card);
    final key = cardBankKey(bank);
    final tier = card['card_tier']?.toString() ?? 'unspecified';
    final network = card['network']?.toString().trim().toLowerCase() ?? '';
    final digits = (card['card_reference']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
    final ending = digits.length >= 4 ? digits.substring(digits.length - 4) : '••••';
    final visual = creditCardVisual(card, key);

    Widget customFace() => LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      return Container(
        padding: EdgeInsets.all(width * 0.065),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bankGradient(bank),
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(tier == 'unspecified' ? 'CRÉDITO' : cardTierLabels[tier]?.toUpperCase() ?? 'CRÉDITO',
              style: TextStyle(color: Colors.white, fontSize: width * 0.038,
                letterSpacing: 1.4, fontWeight: FontWeight.w600))),
            Icon(Icons.contactless_outlined, color: Colors.white.withAlpha(200), size: width * 0.065),
          ]),
          const Spacer(),
          Align(alignment: Alignment.centerLeft, child: Container(
            width: width * 0.12, height: width * 0.085,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFF1D598), Color(0xFFB88A43)])),
            child: Icon(Icons.grid_view_rounded, color: const Color(0xFF806334), size: width * 0.065))),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text('••••  ••••  ••••  $ending', style: TextStyle(
              color: Colors.white, fontSize: width * 0.054, letterSpacing: 1.3))),
          SizedBox(height: width * 0.04),
          Row(children: [
            Expanded(child: Text(card['name']?.toString() ?? 'Mi tarjeta', maxLines: 1,
              overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: width * 0.033))),
            const SizedBox(width: 8),
            Text(network.isEmpty ? 'CRÉDITO' : network.toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: width * 0.034, fontWeight: FontWeight.w800)),
          ]),
        ]),
      );
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (compact)
        Row(children: [
          Tooltip(message: bank.isEmpty ? 'Banco sin asignar' : bank,
            child: BankLogo(name: bank, width: 94, height: 28)),
          const SizedBox(width: 8),
          Expanded(child: Text('•••• $ending', textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
        ])
      else Row(children: [
        Container(width: 112, height: 42, padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: BankLogo(name: bank)),
        const SizedBox(width: 10),
        Expanded(child: Text(bank.isEmpty ? 'Banco sin asignar' : bank, maxLines: 2,
          overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
      ]),
      SizedBox(height: compact ? 6 : 12),
      AspectRatio(aspectRatio: visual?.aspectRatio ?? 1.586,
        child: visual == null ? customFace()
          : visual.asset.toLowerCase().endsWith('.svg')
            ? SvgPicture.asset(visual.asset, fit: BoxFit.contain,
                semanticsLabel: 'Diseño oficial de referencia: ${visual.label}')
            : Image.asset(visual.asset, fit: BoxFit.contain,
              semanticLabel: 'Diseño oficial de referencia: ${visual.label}',
              errorBuilder: (_, error, stackTrace) => customFace())),
      SizedBox(height: compact ? 5 : 10),
      Text(visual?.label ?? '${network.isEmpty ? 'Marca sin especificar' : network.toUpperCase()} · ${cardTierLabels[tier] ?? tier}',
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
      if (!compact) const SizedBox(height: 4),
      if (!compact) Text('Terminación $ending${visual == null ? ' · Diseño general' : ''}',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
    ]);
  }
}
