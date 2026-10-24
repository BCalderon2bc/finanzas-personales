import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/void_payment_dialog.dart';

class DebtPaymentsPage extends StatefulWidget {
  const DebtPaymentsPage({super.key, required this.debtId});
  final String debtId;
  @override
  State<DebtPaymentsPage> createState() => _DebtPaymentsPageState();
}
class _DebtPaymentsPageState extends State<DebtPaymentsPage> {
  List<Map<String, dynamic>> payments = [];
  String description = '', currency = 'NIO';
  int original = 0, principal = 0, interest = 0, fees = 0;
  bool loading = true;
  String? error;
  int requestId = 0;
  bool saving = false;

  @override
  void initState() { super.initState(); loadData(); }

  String money(int cents) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';

  Future<void> loadData() async {
    final request = ++requestId;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final debt = await supabase.from('debts')
          .select('description, currency, original_amount')
          .eq('id', widget.debtId).eq('user_id', user.id).single();
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('debt_payments')
            .select('id, principal_amount, interest_amount, fee_amount, currency, payment_date, reference, is_voided, void_reason, voided_at')
            .eq('debt_id', widget.debtId).eq('user_id', user.id)
            .order('payment_date', ascending: false).order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      int capital = 0, interests = 0, commissions = 0;
      for (final payment in rows) {
        if (payment['is_voided'] == true) continue;
        if (payment['currency'] != debt['currency']) {
          throw StateError('Hay un abono con moneda diferente a la deuda.');
        }
        capital += moneyCents(payment['principal_amount']);
        interests += moneyCents(payment['interest_amount']);
        commissions += moneyCents(payment['fee_amount']);
      }
      final originalAmount = moneyCents(debt['original_amount']);
      if (!mounted || request != requestId) return;
      setState(() {
        description = debt['description'].toString();
        currency = debt['currency'].toString();
        original = originalAmount;
        payments = rows;
        principal = capital; interest = interests; fees = commissions;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  Future<void> voidPayment(Map<String, dynamic> payment) async {
    if (loading || saving || payment['is_voided'] == true) return;
    final reason = await showDialog<String>(
      context: context, builder: (_) => const VoidPaymentDialog(),
    );
    if (reason == null || !mounted || loading || saving) return;
    setState(() => saving = true);
    try {
      await supabase.rpc('void_debt_payment', params: {
        'p_debt_id': widget.debtId,
        'p_payment_id': payment['id'],
        'p_reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abono anulado.')),
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget amountRow(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 8),
      Flexible(child: Text(money(amount), textAlign: TextAlign.right,
          style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]),
  );

  Widget paymentCard(Map<String, dynamic> payment) {
    final date = DateTime.tryParse('${payment['payment_date']}')?.toLocal();
    final dateText = date == null ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final capital = moneyCents(payment['principal_amount']);
    final interests = moneyCents(payment['interest_amount']);
    final commissions = moneyCents(payment['fee_amount']);
    final reference = payment['reference']?.toString().trim() ?? '';
    final voided = payment['is_voided'] == true;

    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(dateText, style: Theme.of(context).textTheme.titleMedium),
      if (voided) ...[
        Text('Abono anulado',
            style: TextStyle(color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold)),
        Text('Motivo: ${payment['void_reason'] ?? 'No especificado'}'),
        const Text('Sin efecto en los saldos ni en los totales.'),
      ],
      const SizedBox(height: 8),
      amountRow('Capital', capital),
      amountRow('Intereses', interests),
      amountRow('Comisiones', commissions),
      const Divider(),
      amountRow('Total del abono', capital + interests + commissions, bold: true),
      if (reference.isNotEmpty) ...[
        const SizedBox(height: 8),
        SelectableText('Referencia: $reference'),
      ],

      if (!voided)
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: saving ? null : () => voidPayment(payment),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Anular abono'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        )),
    ],
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de abonos'), actions: [
      IconButton(tooltip: 'Actualizar', onPressed: loading || saving ? null : loadData,
          icon: const Icon(Icons.refresh)),
    ]),
    body: loading ? const Center(child: CircularProgressIndicator())
        : error != null ? Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('No se pudo cargar el historial.'),
        SelectableText(error!),
        TextButton(onPressed: loadData, child: const Text('Reintentar')),
      ]),
    ))
        : RefreshIndicator(onRefresh: loadData, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16), children: [
      Text(description, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        amountRow('Capital original', original),
        amountRow('Capital abonado', principal),
        amountRow('Capital pendiente', original - principal, bold: true),
        const Divider(),
        amountRow('Intereses pagados', interest),
        amountRow('Comisiones pagadas', fees),
        amountRow('Total pagado', principal + interest + fees, bold: true),
      ],
      ))),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('El capital pendiente no incluye intereses ni comisiones por pagar.')),
      Text('${payments.length} abonos registrados'),
      const SizedBox(height: 8),
      if (payments.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Text('Esta deuda todavía no tiene abonos.', textAlign: TextAlign.center)),
      ...payments.map(paymentCard),
    ],
    )),
  );
}