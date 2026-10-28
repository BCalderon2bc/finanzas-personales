import '../../widgets/account_share_section.dart';
import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../../widgets/bank_brand.dart';

class AccountDetails extends StatelessWidget {
  const AccountDetails({
    super.key,
    required this.account,
    required this.balanceCents,
    this.onEdit,
    this.onToggle,
  });
  final Map<String, dynamic> account;
  final int balanceCents;
  final VoidCallback? onEdit, onToggle;

  String money(int cents) =>
      formatMoneyCents(cents, account['currency']?.toString() ?? 'NIO');

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF64748B);
    const border = Color(0xFFE2E8F0);
    final active = account['is_active'] != false;
    final type = account['account_type']?.toString() ?? '';
    final institution = account['financial_institutions'];
    final bank = institution is Map
        ? institution['name']?.toString() ?? ''
        : '';
    final rawDesign = account['card_design'];
    final design = rawDesign is Map ? rawDesign : <String, dynamic>{};
    final debit =
        design['enabled'] == true && ['savings', 'checking'].contains(type);
    final network = design['network']?.toString().trim() ?? '';
    final digits = design['last_four']?.toString() ?? '';
    final reference = account['account_reference']?.toString().trim() ?? '';
    final notes = account['notes']?.toString().trim() ?? '';
    final opening = moneyCents(account['opening_balance'] ?? 0);
    final difference = balanceCents - opening;
    final color = balanceCents < 0
        ? const Color(0xFFB42318)
        : type == 'cash'
        ? const Color(0xFF087F5B)
        : bankGradient(bank).first;
    const types = {
      'savings': 'Cuenta de ahorro',
      'checking': 'Cuenta corriente',
      'cash': 'Efectivo',
      'wallet': 'Billetera digital',
      'investment': 'Inversión',
      'other': 'Otra cuenta',
    };

    Widget detail(String label, String value, IconData icon) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: muted, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CUENTA SELECCIONADA',
              style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.3),
            ),
            const SizedBox(height: 7),
            Text(
              account['name']?.toString() ?? 'Mi cuenta',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (bank.isNotEmpty)
                  BankLogo(name: bank, width: 105, height: 30),
                if (bank.isNotEmpty)
                  Text(
                    bank,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    active ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      color: active ? const Color(0xFF087F5B) : muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Saldo registrado',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(balanceCents),
                      style: TextStyle(
                        color: color,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Incluye los movimientos y pagos vinculados a esta cuenta.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final columns =
                    box.maxWidth >= 340 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 17.5
                    ? 2
                    : 1;
                final width = (box.maxWidth - 12 * (columns - 1)) / columns;
                final items = [
                  detail(
                    'Tipo de cuenta',
                    types[type] ?? 'Cuenta',
                    Icons.account_balance_wallet_outlined,
                  ),
                  detail(
                    'Moneda',
                    account['currency']?.toString() ?? 'NIO',
                    Icons.payments_outlined,
                  ),
                  detail(
                    'Saldo inicial',
                    money(opening),
                    Icons.account_balance_outlined,
                  ),
                  detail(
                    'Variación por movimientos',
                    '${difference > 0 ? '+' : ''}${money(difference)}',
                    Icons.swap_horiz_rounded,
                  ),
                  if (debit) ...[
                    detail(
                      'Tarjeta de débito',
                      network.isEmpty
                          ? 'Marca sin especificar'
                          : network.toUpperCase(),
                      Icons.credit_card_outlined,
                    ),
                    detail(
                      'Terminación',
                      RegExp(r'^\d{4}$').hasMatch(digits)
                          ? '•••• $digits'
                          : 'Sin registrar',
                      Icons.pin_outlined,
                    ),
                  ],
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map((item) => SizedBox(width: width, child: item))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            AccountShareSection(account: account),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Referencia',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              SelectableText(reference),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Notas', style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 5),
              Text(notes),
            ],
            if (!active)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Esta cuenta conserva su historial y no se ofrece para nuevos movimientos.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                ),
              ),
            const Divider(height: 22, color: border),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: onToggle,
                  icon: Icon(
                    active
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  label: Text(active ? 'Desactivar' : 'Activar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar cuenta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
