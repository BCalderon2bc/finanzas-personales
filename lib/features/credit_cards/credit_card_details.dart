import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../data/payment_agenda_labels.dart';
import '../../utils/money.dart';
import '../../widgets/bank_brand.dart';
import 'credit_card_face.dart';
import 'credit_card_balances.dart';

class CreditCardDetails extends StatefulWidget {
  const CreditCardDetails({
    super.key,
    required this.card,
    required this.balances,
    this.onEdit,
    this.onToggle,
    this.onHistory,
    this.onMovement,
    this.onPayment,
    this.onPlans,
    this.onAdditionals,
  });
  final Map<String, dynamic> card;
  final Map<String, int?> balances;
  final VoidCallback? onEdit,
      onToggle,
      onHistory,
      onMovement,
      onPayment,
      onPlans;
  final Future<void> Function()? onAdditionals;

  @override
  State<CreditCardDetails> createState() => _CreditCardDetailsState();
}

class _CreditCardDetailsState extends State<CreditCardDetails> {
  late Future<List<Map<String, dynamic>>> additionals;

  @override
  void initState() {
    super.initState();
    additionals = fetchAdditionals();
  }

  @override
  void didUpdateWidget(covariant CreditCardDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card['id'] != widget.card['id']) {
      additionals = fetchAdditionals();
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdditionals() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Debes iniciar sesión.');
    return loadAdditionalCards('${widget.card['id']}', userId);
  }

  void refreshAdditionals() {
    final result = fetchAdditionals();
    setState(() {
      additionals = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final balances = widget.balances;
    const blue = Color(0xFF3C70AA),
        green = Color(0xFF35745C),
        muted = Color(0xFF596B7D);
    final active = card['is_active'] == true;
    final base = card['currency'].toString();
    final limit = moneyCents(card['credit_limit']);
    final used = cardLimitUsed(card, balances['NIO'], balances['USD']);
    final available = cardAvailable(card, balances['NIO'], balances['USD']);
    final rate = card['limit_exchange_rate'];
    final exceeded = used != null && used > limit;
    final color = exceeded ? Theme.of(context).colorScheme.error : blue;
    Widget balanceBox(String currency) {
      final amount = balances[currency];
      final credit = amount != null && amount < 0;
      final accent = credit ? green : blue;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withAlpha(12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currency == 'USD' ? 'DÓLARES' : 'CÓRDOBAS',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              credit ? 'Saldo a favor' : 'Deuda registrada',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                cardMoney(amount?.abs(), currency),
                style: TextStyle(
                  color: accent,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARJETA TITULAR',
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        agendaCardLabel(card),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: widget.onEdit != null || widget.onToggle != null,
                  onSelected: (v) {
                    if (v == 'edit') {
                      widget.onEdit?.call();
                    } else {
                      widget.onToggle?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      enabled: widget.onEdit != null,
                      child: const Text('Editar tarjeta'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      enabled: widget.onToggle != null,
                      child: Text(active ? 'Desactivar' : 'Activar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BankLogo(name: cardBankName(card), width: 110, height: 30),
                Chip(label: Text(active ? 'Activa' : 'Inactiva')),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) =>
                  box.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(14) > 17.5
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        balanceBox('NIO'),
                        const SizedBox(height: 12),
                        balanceBox('USD'),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: balanceBox('NIO')),
                        const SizedBox(width: 12),
                        Expanded(child: balanceBox('USD')),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              'Uso del límite compartido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Límite total: ${cardMoney(limit, base)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Disponible estimado: ${available == null ? 'Pendiente de tasa o revisión' : cardMoney(available, base)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (used != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: limit > 0
                      ? (used / limit).clamp(0.0, 1.0).toDouble()
                      : used > 0
                      ? 1
                      : 0,
                  color: color,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFDCE3EB),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Uso estimado: ${cardMoney(used, base)}${limit > 0 ? ' · ${(used * 100 / limit).toStringAsFixed(0)}%' : ''}',
                style: TextStyle(color: color, fontSize: 12),
              ),
              if (exceeded)
                Text(
                  'Exceso estimado: ${cardMoney(used - limit, base)}',
                  style: TextStyle(color: color),
                ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Datos iniciales, tasa y condiciones',
                style: TextStyle(fontSize: 14),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'Deuda inicial en córdobas: ${cardMoney(cardOpening(card, 'NIO'), 'NIO')}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Deuda inicial en dólares: ${cardMoney(cardOpening(card, 'USD'), 'USD')}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rate == null
                            ? 'Edita la tarjeta para indicar la tasa de tu banco si necesitas estimar el disponible entre ambas monedas.'
                            : 'Tasa registrada: C\$ $rate por US\$ 1. El banco puede aplicar otra tasa al procesar los movimientos.',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Las deudas permanecen en su moneda. El saldo a favor de una moneda no reduce la deuda de la otra.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                Text('Día de corte: ${card['closing_day'] ?? 'Sin definir'}'),
                Text('Día de pago: ${card['payment_day'] ?? 'Sin definir'}'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Los intereses no se generan automáticamente.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Divider(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: widget.onPlans,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Planes tasa cero · cuotas y pagos'),
            ),
            const SizedBox(height: 8),
            Text(
              'Tarjetas adicionales',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: additionals,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: refreshAdditionals,
                    child: const Text('Reintentar carga de adicionales'),
                  );
                }
                final cards = snapshot.data!;
                if (cards.isEmpty) {
                  return const Text('Todavía no hay tarjetas adicionales.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final additional in cards)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.credit_card_outlined),
                        title: Text(additionalCardLabel(additional)),
                        subtitle: Text(
                          [
                            additional['is_active'] == true
                                ? 'Activa'
                                : 'Archivada',
                            if (additional['credit_limit'] != null)
                              'Tope por corte: ${cardMoney(moneyCents(additional['credit_limit']), base)}',
                          ].join(' · '),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onAdditionals == null
                  ? null
                  : () async {
                      await widget.onAdditionals!();
                      if (mounted) refreshAdditionals();
                    },
              icon: const Icon(Icons.group_outlined),
              label: const Text('Administrar adicionales'),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: widget.onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Historial'),
                ),
                if (active)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: widget.onMovement,
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Movimiento'),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: widget.onPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Pagar tarjeta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
