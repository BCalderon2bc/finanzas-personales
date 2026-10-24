import 'package:flutter/material.dart';
import 'account_card.dart';

class AccountDesignFields extends StatelessWidget {
  const AccountDesignFields({
    super.key, required this.value, required this.onChanged,
  });
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void update(String key, dynamic data) => onChanged({...value, key: data});

  @override
  Widget build(BuildContext context) {
    final enabled = value['enabled'] == true;
    final network = value['network']?.toString() ?? '';
    final networks = <String, String>{
      '': 'Sin especificar', 'visa': 'Visa', 'mastercard': 'Mastercard',
    };
    if (!networks.containsKey(network)) networks[network] = network;
    final style = value['style']?.toString() ?? 'classic';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar tarjeta de débito'),
        subtitle: const Text('Asociada al saldo de esta cuenta.'),
        value: enabled,
        onChanged: (checked) => update('enabled', checked),
      ),
      if (enabled) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: network, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Marca de la tarjeta'),
          items: networks.entries.map((e) => DropdownMenuItem(
              value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) update('network', v); },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value['last_four']?.toString() ?? '',
          keyboardType: TextInputType.number, maxLength: 4,
          decoration: const InputDecoration(labelText: 'Últimos 4 dí  gitos (opcional)'),
          onChanged: (v) => update('last_four', v.trim()),
          validator: (v) => (v ?? '').trim().isEmpty ||
              RegExp(r'^\d{4}$').hasMatch(v!.trim())
              ? null : 'Escribe exactamente 4 dígitos',
        ),
      ],
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: debitDesignLabels.containsKey(style) ? style : 'classic',
        decoration: const InputDecoration(labelText: 'Diseño visual'),
        items: debitDesignLabels.entries.map((e) => DropdownMenuItem(
            value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) { if (v != null) update('style', v); },
      ),
    ]);
  }
}