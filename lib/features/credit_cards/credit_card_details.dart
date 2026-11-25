import '../../core/app_theme.dart' show appBorder, appMuted, primaryColor;
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../data/payment_agenda_labels.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/bank_brand.dart';
import 'credit_card_face.dart';
import 'credit_card_balances.dart';

class CreditCardDetails extends StatefulWidget {
  const CreditCardDetails({
    super.key,
    required this.card,
    required this.balances,
    required this.usedLimit,
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
  final int? usedLimit;
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
    final blue = primaryColor, green = Color(0xFF397455), muted = appMuted;
    final active = card['is_active'] == true;
    final base = card['currency'].toString();
    final limit = moneyCents(card['credit_limit']);
    final used = widget.usedLimit;
    final available = cardAvailable(card, used);
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              credit ? 'Saldo a favor' : 'Deuda registrada',
              style: TextStyle(color: muted, fontSize: 14),
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

    final compact = compactLayout(context);
    final bankStatus = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BankLogo(name: cardBankName(card), width: 110, height: 30),
        Chip(label: Text(active ? 'Activa' : 'Inactiva')),
      ],
    );

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
                  child: compact
                      ? bankStatus
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARJETA TITULAR',
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
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
            if (!compact) ...[const SizedBox(height: 16), bankStatus],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) => box.maxWidth < 560
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
                  backgroundColor: appBorder,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Uso estimado: ${cardMoney(used, base)}${limit > 0 ? ' · ${(used * 100 / limit).toStringAsFixed(0)}%' : ''}',
                style: TextStyle(color: color, fontSize: 14),
              ),
              if (exceeded)
                Text(
                  'Exceso estimado: ${cardMoney(used - limit, base)}',
                  style: TextStyle(color: color),
                ),
            ],
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
            Text(
              'Los intereses no se generan automáticamente.',
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const Divider(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Tarjetas adicionales',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              children: [
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
                            dense: true,
                            visualDensity: VisualDensity.compact,
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
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 600;
                final singleColumn =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final width = mobile
                    ? (singleColumn
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2)
                    : null;
                final style = OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                );
                Widget slot(Widget child, {bool full = false}) => SizedBox(
                  width: mobile ? (full ? constraints.maxWidth : width) : null,
                  child: child,
                );
                return Wrap(
                  alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (active)
                      slot(
                        OutlinedButton.icon(
                          style: style,
                          onPressed: widget.onMovement,
                          icon: const Icon(Icons.add_card_outlined, size: 18),
                          label: const Text(
                            'Movimiento',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    slot(
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        onPressed: widget.onPayment,
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text(
                          'Pagar tarjeta',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      full: !active,
                    ),
                    slot(
                      OutlinedButton.icon(
                        style: style,
                        onPressed: widget.onPlans,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Planes tasa cero',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    slot(
                      OutlinedButton.icon(
                        style: style,
                        onPressed: widget.onHistory,
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text(
                          'Historial',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    slot(
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: widget.onAdditionals == null
                            ? null
                            : () async {
                                await widget.onAdditionals!();
                                if (mounted) refreshAdditionals();
                              },
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: const Text(
                          'Administrar adicionales',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      full: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
