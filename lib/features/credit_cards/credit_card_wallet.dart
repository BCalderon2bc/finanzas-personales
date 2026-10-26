import 'package:flutter/material.dart';
import '../../widgets/responsive_wallet.dart';
import 'credit_card_face.dart';
import 'credit_card_balances.dart';

class CreditCardWallet extends StatelessWidget {
  const CreditCardWallet({super.key, required this.cards, required this.selectedId,
    required this.balanceFor, this.onSelected});
  final List<Map<String, dynamic>> cards;
  final String? selectedId;
  final int? Function(Map<String, dynamic>, String) balanceFor;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) => ResponsiveWallet(
    items: cards, selectedId: selectedId, onSelected: onSelected,
    title: 'Mi tarjetero', icon: Icons.wallet_outlined,
    desktopItemWidth: 320,
    labelFor: (card) {
      final ref = card['card_reference']?.toString().trim() ?? '';
      return '${card['name']}${ref.isEmpty ? '' : ' · $ref'}';
    },
    itemBuilder: (card, selected) {
      final id = '${card['id']}';
      String amount(String currency) {
        final balance = balanceFor(card, currency);
        return balance == null ? '$currency: por revisar'
          : '${balance < 0 ? 'A favor' : 'Deuda'}: ${cardMoney(balance.abs(), currency)}';
      }
      return Semantics(selected: selected, button: true,
        child: Material(color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onSelected == null ? null : () => onSelected!(id),
            child: Padding(padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${card['name']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  CreditCardFace(card: card, compact: true),
                  const Divider(height: 18),
                  Text(amount('NIO'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(amount('USD'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(card['is_active'] == true ? 'Activa' : 'Inactiva',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ]),
            ),
          ),
        ),
      );
    },
  );
}
