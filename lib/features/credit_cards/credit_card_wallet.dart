import '../../core/app_theme.dart' show appBorder, appMuted, primaryColor;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/responsive_wallet.dart';
import 'credit_card_products.dart';
import 'credit_card_face.dart';

class CreditCardWallet extends StatelessWidget {
  const CreditCardWallet({
    super.key,
    required this.cards,
    required this.selectedId,
    this.onSelected,
  });
  final List<Map<String, dynamic>> cards;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) => ResponsiveWallet(
    items: cards,
    selectedId: selectedId,
    onSelected: onSelected,
    title: 'Mi tarjetero',
    icon: Icons.wallet_outlined,
    desktopItemWidth: 320,
    showNextOnMobile: true,
    revealSelectionOnDesktop: true,
    labelFor: (card) {
      final ref = card['card_reference']?.toString().trim() ?? '';
      return '${card['name']}${ref.isEmpty ? '' : ' · $ref'}';
    },
    itemBuilder: (card, selected) {
      final id = '${card['id']}';
      return Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: selected ? primaryColor : appBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelected == null ? null : () => onSelected!(id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (compactLayout(context))
                    _MobileCardSummary(card: card)
                  else ...[
                    Text(
                      '${card['name']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CreditCardFace(card: card, compact: true),
                    const Divider(height: 18),
                    Text(
                      card['is_active'] == true ? 'Activa' : 'Inactiva',
                      style: TextStyle(color: appMuted, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MobileCardSummary extends StatelessWidget {
  const _MobileCardSummary({required this.card});

  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bank = cardBankName(card);
    final visual = creditCardVisual(card, cardBankKey(bank));
    final digits = (card['card_reference']?.toString() ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    final ending = digits.length >= 4
        ? '••${digits.substring(digits.length - 4)}'
        : '';
    final icon = Icon(
      Icons.credit_card_outlined,
      color: theme.colorScheme.primary,
    );
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          bank.isEmpty ? '${card['name']}' : bank,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (visual != null ||
            ending.isNotEmpty ||
            card['is_active'] != true) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (visual != null) visual.label,
              if (ending.isNotEmpty) ending,
              if (card['is_active'] != true) 'Inactiva',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
    final artwork = SizedBox(
      height: 112,
      child: visual == null
          ? Center(child: icon)
          : visual.asset.toLowerCase().endsWith('.svg')
          ? SvgPicture.asset(visual.asset, fit: BoxFit.contain)
          : Image.asset(
              visual.asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Center(child: icon),
            ),
    );
    return AdaptiveColumns(
      minColumnWidth: 110,
      spacing: 10,
      children: [
        artwork,
        Center(child: identity),
      ],
    );
  }
}
