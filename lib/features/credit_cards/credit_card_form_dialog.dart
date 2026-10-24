import 'package:flutter/material.dart';
import 'credit_card_face.dart';

class CreditCardFormDialog extends StatefulWidget {

  const CreditCardFormDialog({
    super.key, this.card, required this.institutions,
  });
  final Map<String, dynamic>? card;
  final List<Map<String, dynamic>> institutions;

  @override
  State<CreditCardFormDialog> createState() => _CreditCardFormDialogState();
}
class _CreditCardFormDialogState extends State<CreditCardFormDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), reference = TextEditingController();
  final limit = TextEditingController(), closing = TextEditingController();
  final payment = TextEditingController();
  final openingBalance = TextEditingController(text: '0.00');

  String currency = 'NIO';
  bool get editing => widget.card != null;

  String bankId = '', network = '', tier = 'unspecified';
  final networks = <String, String>{
    '': 'Sin especificar', 'visa': 'Visa',
    'mastercard': 'Mastercard', 'amex': 'American Express',
  };

  Map<String, dynamic> get preview {
    final banks = widget.institutions.where((b) => b['id'].toString() == bankId);
    return {
      'name': name.text.trim().isEmpty ? 'Mi tarjeta' : name.text.trim(),
      'card_reference': reference.text.trim(),
      'network': network,
      'card_tier': tier,
      'financial_institutions': banks.isEmpty ? null : banks.first,
    };
  }

  @override
  void initState() {
    super.initState();
    final card = widget.card;

    bankId = card?['institution_id']?.toString() ?? '';
    network = card?['network']?.toString().trim().toLowerCase() ?? '';
    tier = card?['card_tier']?.toString() ?? 'unspecified';
    if (!networks.containsKey(network)) networks[network] = network;
    if (!cardTierLabels.containsKey(tier)) tier = 'unspecified';

    if (card == null) return;
    name.text = card['name']?.toString() ?? '';
    reference.text = card['card_reference']?.toString() ?? '';
    limit.text = card['credit_limit'].toString();
    closing.text = card['closing_day']?.toString() ?? '';
    payment.text = card['payment_day']?.toString() ?? '';
    currency = card['currency'].toString();
    openingBalance.text = '${card['opening_balance'] ?? 0}';
  }


  @override
  void dispose() {
    name.dispose(); reference.dispose(); limit.dispose();
    closing.dispose(); payment.dispose();
    openingBalance.dispose();
    super.dispose();

  }
  Widget dayField(String label, TextEditingController controller) => TextFormField(
    controller: controller, keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return null;
      final day = int.tryParse(text);
      return day == null || day < 1 || day > 31 ? 'Introduce un día del 1 al 31' : null;
    },
  );
  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': name.text.trim(),
      'card_reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
      'currency': currency,
      'credit_limit': double.parse(limit.text.trim().replaceAll(',', '.')),
      if (!editing)
        'opening_balance': double.parse(openingBalance.text.trim().replaceAll(',', '.')),
      'closing_day': int.tryParse(closing.text.trim()),
      'payment_day': int.tryParse(payment.text.trim()),
      'institution_id': bankId.isEmpty ? null : bankId,
      'network': network.isEmpty ? null : network,
      'card_tier': tier,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar tarjeta' : 'Nueva tarjeta de crédito'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(
      key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [

      CreditCardFace(card: preview),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        initialValue: bankId, isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Banco emisor',
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Sin banco asignado')),
          ...widget.institutions.map((bank) => DropdownMenuItem(
              value: bank['id'].toString(),
              child: Text(bank['name'].toString(), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (value) {
          if (value != null) setState(() => bankId = value);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: network, isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Marca',
          prefixIcon: Icon(Icons.credit_card_outlined),
        ),
        items: networks.entries.map((entry) => DropdownMenuItem(
            value: entry.key, child: Text(entry.value))).toList(),
        onChanged: (value) {
          if (value != null) setState(() => network = value);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: tier, isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Categoría de tarjeta',
          prefixIcon: Icon(Icons.style_outlined),
        ),
        items: cardTierLabels.entries.map((entry) => DropdownMenuItem(
            value: entry.key, child: Text(entry.value))).toList(),
        onChanged: (value) {
          if (value != null) setState(() => tier = value);
        },
      ),
      const SizedBox(height: 8),
      const Text('La imagen cambia según el banco, la marca y la categoría seleccionados.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      const SizedBox(height: 20),

      TextFormField(controller: name, autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Mi tarjeta Visa'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null),
      const SizedBox(height: 12),
      TextFormField(controller: reference, keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          maxLength: 4, decoration: const InputDecoration(labelText: 'Últimos 4 dígitos (opcional)'),
          validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^\d{4}$').hasMatch(v!.trim())
              ? null : 'Escribe los últimos 4 dígitos'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: currency, decoration: const InputDecoration(labelText: 'Moneda'),
        items: const [
          DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
          DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
        ],
        onChanged: editing ? null : (v) {
          if (v != null) setState(() => currency = v);
        },
      ),
      const SizedBox(height: 12),
      TextFormField(controller: limit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Límite de crédito'),
          validator: (v) {
            final text = (v ?? '').trim();
            final amount = double.tryParse(text.replaceAll(',', '.'));
            if (amount == null || !amount.isFinite || amount < 0) return 'Introduce un límite válido';
            if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
            return null;
          }),
      const SizedBox(height: 12),
      TextFormField(
        controller: openingBalance, readOnly: editing,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Deuda inicial',
          helperText: editing
              ? 'Se conserva después de crear la tarjeta.'
              : 'Deuda anterior al historial que registrarás aquí.',
        ),
        validator: (value) {
          if (editing) return null;
          final text = (value ?? '').trim();
          final amount = double.tryParse(text.replaceAll(',', '.'));
          if (amount == null || !amount.isFinite || amount < 0) return 'Introduce un monto válido';
          if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) return 'Usa máximo dos decimales, sin separadores de miles';
          return null;
        },
      ),
      const SizedBox(height: 12),
      const SizedBox(height: 12),
      dayField('Día de corte (opcional)', closing),
      const SizedBox(height: 12),
      dayField('Día de pago (opcional)', payment),
    ]),
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}