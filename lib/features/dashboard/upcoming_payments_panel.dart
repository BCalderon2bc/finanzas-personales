import 'zero_plans_agenda.dart';
import '../../data/payment_agenda_labels.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/card_statement_repository.dart';
import '../../data/payment_agenda_logic.dart';
import '../../data/debt_installment_repository.dart';
import '../../utils/money.dart';

class UpcomingPaymentsPanel extends StatefulWidget {
  const UpcomingPaymentsPanel({
    super.key,
    required this.refreshToken,
    required this.onCard,
    required this.onDebt,
    this.onInstallments,
  });
  final Object refreshToken;
  final ValueChanged<Map<String, dynamic>> onCard, onDebt;
  final ValueChanged<Map<String, dynamic>>? onInstallments;
  @override
  State<UpcomingPaymentsPanel> createState() => _UpcomingPaymentsPanelState();
}

class _UpcomingPaymentsPanelState extends State<UpcomingPaymentsPanel> {
  bool loading = true, expanded = false;
  String? error;
  int requestId = 0;
  List<AgendaItem> items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant UpcomingPaymentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      load();
    }
  }

  Future<void> load() async {
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw StateError('Debes iniciar sesión.');
      }
      final values = await Future.wait<Object>([
        loadCardStatements(userId),
        statementRows(
          'credit_cards',
          'id,name,currency,closing_day,payment_day,is_active,card_reference,financial_institutions(name)',
          userId,
        ),
        statementRows(
          'debts',
          'id,description,creditor_name,currency,original_amount,status,due_date',
          userId,
        ),
        statementRows(
          'debt_payments',
          'id,debt_id,currency,principal_amount,is_voided',
          userId,
        ),
        loadDebtInstallments(userId),
      ]);
      if (supabase.auth.currentUser?.id != userId) {
        throw StateError('La sesión cambió.');
      }
      final agenda = buildPaymentAgenda(
        today: DateTime.now(),
        statements: values[0] as CardStatementData,
        cards: values[1] as List<Map<String, dynamic>>,
        debts: values[2] as List<Map<String, dynamic>>,
        debtPayments: values[3] as List<Map<String, dynamic>>,
        installments: values[4] as DebtInstallmentData,
      );
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        items = agenda;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Widget agendaRow(AgendaItem item) {
    final days = daysUntil(item.date, DateTime.now());
    final isCut = item.kind == AgendaKind.cardCut;
    final loan =
        item.kind == AgendaKind.loanMaturity ||
        item.kind == AgendaKind.loanInstallment;
    final coveredMinimum =
        item.kind == AgendaKind.cardPayment && item.minimumRemaining == 0;
    final color = isCut
        ? const Color(0xFF2563EB)
        : days < 0 &&
              (loan || (!coveredMinimum && item.minimumRemaining != null))
        ? const Color(0xFFB42318)
        : days <= 0
        ? const Color(0xFFB45309)
        : const Color(0xFF2563EB);
    final when = days < 0
        ? 'Fecha pasada · hace ${-days} días'
        : days == 0
        ? 'Hoy'
        : days == 1
        ? 'Mañana'
        : 'En $days días';
    final label = isCut
        ? 'Corte de tarjeta'
        : item.kind == AgendaKind.loanInstallment
        ? 'Cuota de préstamo'
        : loan
        ? 'Vencimiento de capital'
        : 'Pago de tarjeta';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: color.withAlpha(9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (item.kind == AgendaKind.loanInstallment) {
              (widget.onInstallments ?? widget.onDebt)(item.entity);
            } else if (loan) {
              widget.onDebt(item.entity);
            } else {
              widget.onCard(item.entity);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCut
                      ? Icons.event_note_outlined
                      : loan
                      ? Icons.handshake_outlined
                      : Icons.credit_card_outlined,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        loan
                            ? (item.title.trim().isEmpty
                                  ? 'Préstamo sin descripción'
                                  : item.title)
                            : agendaCardLabel(item.entity),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (loan) ...[
                        const SizedBox(height: 4),
                        Text(
                          agendaDebtCreditor(item.entity),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$label${item.currency == null ? '' : ' · ${item.currency}'} · ${shortStatementDate(item.date.toIso8601String())}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.amount != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${item.kind == AgendaKind.loanInstallment
                              ? 'Cuota pendiente'
                              : loan
                              ? 'Capital pendiente'
                              : 'Pendiente del período'}: '
                          '${formatMoneyCents(item.amount!, item.currency!)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (item.kind == AgendaKind.cardPayment)
                          Text(
                            item.minimumRemaining == null
                                ? 'Mínimo: sin registrar'
                                : item.minimumRemaining == 0
                                ? 'Mínimo cubierto'
                                : 'Mínimo pendiente: ${formatMoneyCents(item.minimumRemaining!, item.currency!)}',
                          ),
                      ] else if (!isCut)
                        Text(
                          item.needsStatement
                              ? 'Registra el corte para conocer el monto.'
                              : 'Monto por revisar.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Próximos pagos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar próximos pagos',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const Text(
            'Fechas pasadas, hoy y próximos 7 días. Importes en la moneda del pago.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            )
          else if (error != null) ...[
            const SizedBox(height: 12),
            const Text('No se pudo cargar la agenda.'),
            SelectableText(error!, style: const TextStyle(fontSize: 12)),
            TextButton(onPressed: load, child: const Text('Reintentar')),
          ] else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay otros vencimientos pendientes ni cortes previstos para los próximos 7 días.',
              ),
            )
          else ...[
            ...items.take(expanded ? items.length : 5).map(agendaRow),
            if (items.length > 5)
              TextButton(
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(
                  expanded ? 'Mostrar menos' : 'Ver todos (${items.length})',
                ),
              ),
          ],
          ZeroPlansAgenda(
            refreshToken: (widget.refreshToken, requestId),
            onChanged: load,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Qué incluye esta agenda',
              style: TextStyle(fontSize: 13),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Las tarjetas usan el estado de cuenta vigente de cada moneda. Si aún no hay corte, la fecha habitual '
                  'solo aparece como recordatorio sin monto. Los préstamos muestran su fecha registrada de vencimiento y '
                  'el capital pendiente si no hay cuotas configuradas. Con un calendario vigente, muestra sus cuotas pendientes, sin sumarlas otra vez al capital. Los pagos cubiertos no aparecen como pendientes. '
                  'La agenda se calcula al actualizar el inicio y es independiente del mes del reporte.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
