import 'package:flutter/material.dart';
import 'credit_card_face.dart';
import 'credit_card_products.dart';
import 'credit_card_balances.dart';

class CreditCardFormDialog extends StatefulWidget {
  const CreditCardFormDialog({
    super.key,
    this.card,
    required this.institutions,
  });
  final Map<String, dynamic>? card;
  final List<Map<String, dynamic>> institutions;
  @override
  State<CreditCardFormDialog> createState() => _CreditCardFormDialogState();
}

class _CreditCardFormDialogState extends State<CreditCardFormDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), reference = TextEditingController();
  final limit = TextEditingController(text: '0.00');
  final nio = TextEditingController(text: '0.00'),
      usd = TextEditingController(text: '0.00');
  final rate = TextEditingController(),
      closing = TextEditingController(),
      payment = TextEditingController();
  String currency = 'USD', bankId = '', network = '', tier = 'unspecified';
  String product = 'standard';
  final limitsByCurrency = <String, String>{};

  void selectCurrency(String? value) {
    if (value == null || value == currency) return;
    setState(() {
      limitsByCurrency[currency] = limit.text;
      currency = value;
      limit.text = limitsByCurrency[value] ?? '';
    });
  }

  final networks = <String, String>{
    '': 'Sin especificar',
    'visa': 'Visa',
    'mastercard': 'Mastercard',
    'amex': 'American Express',
  };
  bool get editing => widget.card != null;
  @override
  void initState() {
    super.initState();
    final c = widget.card;
    if (c == null) {
      return;
    }
    name.text = c['name']?.toString() ?? '';
    reference.text = c['card_reference']?.toString() ?? '';
    bankId = c['institution_id']?.toString() ?? '';
    network = c['network']?.toString().toLowerCase() ?? '';
    if (!networks.containsKey(network)) {
      networks[network] = network;
    }
    tier = c['card_tier']?.toString() ?? 'unspecified';
    product = c['card_product']?.toString() ?? 'standard';
    if (creditCardProduct(product) == null) {
      product = 'standard';
    }
    if (!cardTierLabels.containsKey(tier)) {
      tier = 'unspecified';
    }
    currency = c['currency'].toString();
    limit.text = '${c['credit_limit'] ?? 0}';
    nio.text = (cardOpening(c, 'NIO') / 100).toStringAsFixed(2);
    usd.text = (cardOpening(c, 'USD') / 100).toStringAsFixed(2);
    rate.text = c['limit_exchange_rate']?.toString() ?? '';
    closing.text = c['closing_day']?.toString() ?? '';
    payment.text = c['payment_day']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      name,
      reference,
      limit,
      nio,
      usd,
      rate,
      closing,
      payment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get preview {
    final banks = widget.institutions.where(
      (b) => b['id'].toString() == bankId,
    );
    return {
      'name': name.text.trim().isEmpty ? 'Mi tarjeta' : name.text.trim(),
      'card_reference': reference.text.trim(),
      'network': network,
      'card_tier': tier,
      'card_product': product,
      'financial_institutions': banks.isEmpty ? null : banks.first,
    };
  }

  String get selectedBank {
    for (final b in widget.institutions) {
      if (b['id'].toString() == bankId) {
        return cardBankKey(b['name'].toString());
      }
    }
    return '';
  }

  void selectProduct(String value) {
    final design = creditCardProduct(value);
    setState(() {
      product = value;
      if (design != null) {
        network = design.network;
        tier = design.tier;
      }
    });
  }

  String? validateAmount(String? value) {
    final text = (value ?? '').trim();
    final amount = double.tryParse(text.replaceAll(',', '.'));
    if (amount == null || !amount.isFinite || amount < 0) {
      return 'Introduce un monto válido';
    }
    return RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)
        ? null
        : 'Usa máximo dos decimales, sin separadores de miles';
  }

  double number(TextEditingController c) =>
      double.parse(c.text.trim().replaceAll(',', '.'));
  Widget amountField(String label, TextEditingController controller) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: validateAmount,
      );
  Widget dayField(String label, TextEditingController controller) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) {
          if ((v ?? '').trim().isEmpty) {
            return null;
          }
          final day = int.tryParse(v!.trim());
          return day == null || day < 1 || day > 31
              ? 'Introduce un día del 1 al 31'
              : null;
        },
      );
  void save() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'name': name.text.trim(),
      'card_reference': reference.text.trim().isEmpty
          ? null
          : reference.text.trim(),
      'institution_id': bankId.isEmpty ? null : bankId,
      'network': network.isEmpty ? null : network,
      'card_tier': tier,
      'card_product': product,
      'currency': currency,
      'credit_limit': number(limit),
      'opening_balance_nio': number(nio),
      'opening_balance_usd': number(usd),
      'opening_balance': currency == 'USD' ? number(usd) : number(nio),
      'limit_exchange_rate': rate.text.trim().isEmpty ? null : number(rate),
      'closing_day': int.tryParse(closing.text.trim()),
      'payment_day': int.tryParse(payment.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Editar tarjeta' : 'Nueva tarjeta'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CreditCardFace(card: preview),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: bankId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Banco emisor'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Sin banco asignado'),
                  ),
                  ...widget.institutions.map(
                    (b) => DropdownMenuItem(
                      value: b['id'].toString(),
                      child: Text(
                        b['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      bankId = v;
                      product = 'standard';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              CreditCardProductField(
                bank: selectedBank,
                value: product,
                onChanged: selectProduct,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('network-$network'),
                initialValue: network,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Marca'),
                items: networks.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: product != 'standard'
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => network = v);
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('tier-$tier'),
                initialValue: tier,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría de tarjeta',
                ),
                items: cardTierLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: product != 'standard'
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => tier = v);
                        }
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reference,
                maxLength: 4,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Últimos 4 dígitos (opcional)',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ||
                        RegExp(r'^\d{4}$').hasMatch(v!.trim())
                    ? null
                    : 'Escribe los últimos 4 dígitos',
              ),
              const SizedBox(height: 12),
              const Text(
                'Un límite compartido · dos saldos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Las compras y pagos se registran en su moneda. El límite corresponde a toda la tarjeta.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(
                  labelText: 'Moneda del límite compartido',
                  helperText:
                      'Al cambiarla, ingresa el límite que informa el banco en esa moneda. Tus deudas conservan su moneda e importe.',
                  helperMaxLines: 4,
                ),
                items: const [
                  DropdownMenuItem(value: 'NIO', child: Text('Córdobas (C\$)')),
                  DropdownMenuItem(value: 'USD', child: Text('Dólares (US\$)')),
                ],
                onChanged: selectCurrency,
              ),
              const SizedBox(height: 12),
              amountField('Límite total ($currency)', limit),
              const SizedBox(height: 12),
              TextFormField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Córdobas por US\$ 1 (opcional)',
                  helperText:
                      'Usa la tasa de tu banco. Solo estima el disponible; no convierte tus deudas.',
                  helperMaxLines: 3,
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) {
                    return null;
                  }
                  final r = double.tryParse(text.replaceAll(',', '.'));
                  return r == null ||
                          !r.isFinite ||
                          r <= 0 ||
                          !RegExp(r'^\d+([.,]\d{1,6})?$').hasMatch(text)
                      ? 'Introduce una tasa positiva con máximo seis decimales'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              amountField('Deuda inicial en córdobas (C\$)', nio),
              const SizedBox(height: 12),
              amountField('Deuda inicial en dólares (US\$)', usd),
              const SizedBox(height: 8),
              const Text(
                'Ingresa lo que debías antes del historial registrado. Los movimientos existentes se suman a estos importes.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),
              dayField('Día de corte (opcional)', closing),
              const SizedBox(height: 12),
              dayField('Día de pago (opcional)', payment),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}
