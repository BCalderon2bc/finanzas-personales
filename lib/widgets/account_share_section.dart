import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/account_share_logic.dart';

class AccountShareSection extends StatelessWidget {
  const AccountShareSection({super.key, required this.account});
  final Map<String, dynamic> account;
  Future<void> copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted)
        messenger.showSnackBar(
          const SnackBar(content: Text('Datos copiados.')),
        );
    } catch (_) {
      if (context.mounted)
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo copiar. Inténtalo de nuevo.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = '${account['account_number'] ?? ''}',
        holder = '${account['account_holder'] ?? ''}',
        iban = normalizeAccountIban('${account['account_iban'] ?? ''}');
    final missing = missingAccountShareFields(account),
        text = buildAccountShareText(account);
    Widget datum(String title, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? 'Sin registrar' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos de la cuenta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          datum('Titular de la cuenta', holder),
          datum('Número de cuenta', number),
          if (iban.isNotEmpty) datum('Cuenta IBAN', iban),
          datum('Moneda', shareCurrency('${account['currency'] ?? ''}')),
          FilledButton.icon(
            onPressed: missing.isEmpty ? () => copy(context, text) : null,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar'),
          ),
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Completa ${missing.join(', ')} en Editar cuenta para copiar la ficha completa.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
