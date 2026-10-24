import 'package:flutter/material.dart';
import 'credit_card_face.dart';

class CreditCardAppearanceDialog extends StatefulWidget {
  const CreditCardAppearanceDialog({
    super.key, required this.card, required this.institutions,
  });
  final Map<String, dynamic> card;
  final List<Map<String, dynamic>> institutions;
  @override
  State<CreditCardAppearanceDialog> createState() => _CreditCardAppearanceDialogState();
}

class _CreditCardAppearanceDialogState extends State<CreditCardAppearanceDialog> {
  late String bankId, network, tier;
  final networks = <String, String>{
    '': 'Sin especificar', 'visa': 'Visa',
    'mastercard': 'Mastercard', 'amex': 'American Express',
  };

  @override
  void initState() {
    super.initState();
    bankId = widget.card['institution_id']?.toString() ?? '';
    network = widget.card['network']?.toString().trim().toLowerCase() ?? '';
    tier = widget.card['card_tier']?.toString() ?? 'unspecified';
    if (!networks.containsKey(network)) networks[network] = network;
  }

  Map<String, dynamic> get preview {
    final banks = widget.institutions.where((b) => b['id'].toString() == bankId);
    return {
      ...widget.card, 'network': network, 'card_tier': tier,
      'financial_institutions': banks.isEmpty ? null : banks.first,
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Personalizar tarjeta'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreditCardFace(card: preview),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: bankId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Banco emisor'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sin banco')),
              ...widget.institutions.map((b) => DropdownMenuItem(
                  value: b['id'].toString(),
                  child: Text(b['name'].toString(), overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => bankId = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: network, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Marca'),
            items: networks.entries.map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => network = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: tier, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: cardTierLabels.entries.map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => tier = value);
            },
          ),
          const SizedBox(height: 12),
          const Text('Selecciona los datos de tu tarjeta. La imagen es una referencia visual.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ],
      )),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar')),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'institution_id': bankId.isEmpty ? null : bankId,
          'network': network.isEmpty ? null : network,
          'card_tier': tier,
        }),
        child: const Text('Guardar'),
      ),
    ],
  );
}