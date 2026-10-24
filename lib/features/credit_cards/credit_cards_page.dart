import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import 'credit_card_form_dialog.dart';
import 'credit_card_movement_dialog.dart';
import 'credit_card_payment_dialog.dart';
import 'credit_card_movements_page.dart';
import 'credit_cards_summary.dart';
import 'credit_card_face.dart';
import 'credit_card_appearance_dialog.dart';

class CreditCardsPage extends StatefulWidget {
  const CreditCardsPage({super.key});
  @override
  State<CreditCardsPage> createState() => _CreditCardsPageState();
}
class _CreditCardsPageState extends State<CreditCardsPage> {
  List<Map<String, dynamic>> cards = [], transactions = [];
  bool loading = true, saving = false;
  String? error;
  int requestId = 0;

  @override
  void initState() { super.initState(); loadData(); }

  String money(int cents, String currency) =>
      '${currency == 'USD' ? 'US\$' : 'C\$'} ${(cents / 100).toStringAsFixed(2)}';
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> payCard(Map<String, dynamic> card) async {
    if (loading || saving ) return;
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final rows = await readRows('accounts', 'id, name, currency, is_active', user.id);
      final accounts = rows.where((a) =>
      a['is_active'] == true && a['currency'] == card['currency']).toList();
      if (!mounted) return;
      if (accounts.isEmpty) {
        message('Necesitas una cuenta activa en la misma moneda.');
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardPaymentDialog(
          accounts: accounts, currency: card['currency'].toString(),
        ),
      );
      if (data == null || !mounted) return;
      await supabase.rpc('register_credit_card_payment', params: {
        'p_card_id': card['id'],
        'p_account_id': data['account_id'],
        'p_amount': data['amount'],
        'p_reference': data['reference'],
      });
      if (!mounted) return;
      message('Pago registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo registrar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo registrar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> addMovement(Map<String, dynamic> card) async {
    if (loading || saving || card['is_active'] != true) return;
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final categories = await readRows('categories',
          'id, name, category_type, is_active', user.id);
      final available = categories.where((c) =>
      c['category_type'] == 'expense' && c['is_active'] == true).toList()
        ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      if (!mounted) return;
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardMovementDialog(
          currency: card['currency'].toString(), categories: available,
        ),
      );
      if (data == null || !mounted) return;
      final current = await supabase.from('credit_cards')
          .select('currency, is_active').eq('id', card['id'])
          .eq('user_id', user.id).single();
      if (current['is_active'] != true) throw StateError('La tarjeta ya no está activa.');
      if (current['currency'] != card['currency']) {
        throw StateError('La moneda de la tarjeta cambió. Actualiza la lista.');
      }
      await supabase.from('credit_card_transactions').insert({
        ...data,
        'credit_card_id': card['id'],
        'user_id': user.id,
        'currency': current['currency'],
      });
      if (!mounted) return;
      message('Movimiento registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo guardar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<List<Map<String, dynamic>>> readRows(String table, String columns, String userId) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      final result = await supabase.from(table).select(columns)
          .eq('user_id', userId).order('id').range(offset, offset + 499);
      final page = List<Map<String, dynamic>>.from(result);
      rows.addAll(page);
      if (page.length < 500) break;
    }
    return rows;
  }

  Future<void> loadData() async {
    final request = ++requestId;
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final cardRows = await readRows('credit_cards',
          'id, name, card_reference, currency, credit_limit, opening_balance, '
              'closing_day, payment_day, is_active, institution_id, network, card_tier, '
              'financial_institutions(name, code)', user.id);

      final transactionRows = await readRows('credit_card_transactions',
          'id, credit_card_id, transaction_type, amount, currency, is_voided', user.id);
      if (!mounted || request != requestId) return;
      setState(() { cards = cardRows; transactions = transactionRows; loading = false; });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  Future<void> toggleCard(Map<String, dynamic> card) async {
    if (loading || saving) return;
    final active = card['is_active'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'Activar tarjeta' : 'Desactivar tarjeta'),
        content: Text(active
            ? 'La tarjeta volverá a admitir nuevos cargos.'
            : 'Se conservará su deuda e historial. Podrás registrar pagos, pero no nuevos cargos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted || loading || saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final updated = await supabase.from('credit_cards').update({'is_active': active})
          .eq('id', card['id']).eq('user_id', user.id)
          .eq('is_active', !active).select('id');
      if (!mounted) return;
      message(updated.isEmpty ? 'El registro cambió o faltan permisos.'
          : active ? 'Tarjeta activada.' : 'Tarjeta desactivada.');
      await loadData();
    } catch (e) {
      if (mounted) message('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  int? balanceFor(Map<String, dynamic> card) {
    int balance = moneyCents(card['opening_balance'] ?? 0);
    for (final tx in transactions) {
      if (tx['credit_card_id'].toString() != card['id'].toString()) continue;
      if (tx['is_voided'] == true) continue;
      if (tx['currency'] != card['currency']) return null;
      final amount = moneyCents(tx['amount']);
      switch (tx['transaction_type']) {
        case 'purchase':
        case 'interest':
        case 'fee':
          balance += amount;
          break;
        case 'payment':
        case 'refund':
          balance -= amount;
          break;
        default:
          return null;
      }
    }
    return balance;
  }

  Future<void> addCard([Map<String, dynamic>? card]) async {
    if (loading || saving) return;
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Debes iniciar sesión nuevamente.');
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('financial_institutions')
            .select('id, name, is_active').order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      final institutions = rows.where((bank) =>
      bank['is_active'] == true || bank['id'] == card?['institution_id']).toList()
        ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      if (!mounted) return;
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardFormDialog(
            card: card, institutions: institutions),
      );
      if (data == null || !mounted) return;
      if (supabase.auth.currentUser?.id != user.id) {
        throw StateError('La sesión cambió. Abre nuevamente el formulario.');
      }
      if (card == null) {
        await supabase.from('credit_cards').insert({...data, 'user_id': user.id});
      } else {
        final changes = <String, dynamic>{
          for (final key in [
            'name', 'card_reference', 'credit_limit', 'closing_day',
            'payment_day', 'institution_id', 'network', 'card_tier',
          ]) key: data[key],
        };
        await supabase.from('credit_cards').update(changes)
            .eq('id', card['id']).eq('user_id', user.id).select('id').single();
      }
      if (!mounted) return;
      message(card == null ? 'Tarjeta registrada.' : 'Tarjeta actualizada.');
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo guardar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Widget cardTile(Map<String, dynamic> card) {
    final currency = card['currency'].toString();
    final limit = moneyCents(card['credit_limit']);
    final balance = balanceFor(card);
    final debt = balance == null ? null : balance > 0 ? balance : 0;
    final available = debt == null ? null : (limit - debt).clamp(0, limit).toInt();
    final ratio = debt == null || limit <= 0 ? null : debt / limit;
    final exceeded = debt != null && debt > limit;
    final color = exceeded ? const Color(0xFFB42318)
        : ratio != null && ratio >= 0.8 ? const Color(0xFFB45309)
        : const Color(0xFF2563EB);
    final active = card['is_active'] == true;

    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(balance != null && balance < 0 ? 'SALDO A FAVOR' : 'DEUDA REGISTRADA',
            style: const TextStyle(color: Color(0xFF64748B),
                fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(balance == null ? 'Por revisar'
              : money(balance < 0 ? -balance : balance, currency),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: balance != null && balance < 0
                      ? const Color(0xFF087F5B) : const Color(0xFF172033))),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            detail('Disponible según registros',
                available == null ? 'Por revisar' : money(available, currency)),
            detail('Límite de crédito', money(limit, currency)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: debt == null ? 0
                    : limit > 0 ? (debt / limit).clamp(0.0, 1.0).toDouble()
                    : debt > 0 ? 1 : 0,
                minHeight: 8, color: color,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 8),
            Text(balance == null ? 'Saldo pendiente de revisión'
                : ratio == null ? 'Sin límite asignado'
                : '${(ratio * 100).toStringAsFixed(0)}% del límite utilizado',
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            if (exceeded) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Exceso: ${money(debt - limit, currency)}',
                    style: const TextStyle(color: Color(0xFFB42318), fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 12),
        detail('Deuda inicial',
            money(moneyCents(card['opening_balance'] ?? 0), currency)),
        detail('Día de corte', card['closing_day']?.toString() ?? 'Sin definir'),
        detail('Día de pago', card['payment_day']?.toString() ?? 'Sin definir'),
        if (balance == null)
          const Text('Revisa las monedas o ajustes de los movimientos.',
              style: TextStyle(color: Color(0xFFB42318), fontSize: 12)),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(card['name'].toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(active ? 'Activa' : 'Inactiva',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? const Color(0xFF087F5B) : const Color(0xFF64748B))),
            ),
            PopupMenuButton<String>(
              enabled: !saving,
              tooltip: 'Opciones',
              onSelected: (value) {
                if (value == 'appearance') customizeCard(card);
                if (value == 'edit') addCard(card);
                if (value == 'toggle') toggleCard(card);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'appearance', child: Text('Banco y diseño')),
                const PopupMenuItem(value: 'edit', child: Text('Editar tarjeta')),
                PopupMenuItem(value: 'toggle',
                    child: Text(active ? 'Desactivar tarjeta' : 'Activar tarjeta')),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth < 740) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: CreditCardFace(card: card))),
                const SizedBox(height: 24),
                summary,
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 350, child: CreditCardFace(card: card)),
              const SizedBox(width: 28),
              Expanded(child: summary),
            ]);
          }),
          const Divider(height: 32),
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 10, children: [
            TextButton.icon(
              onPressed: saving ? null : () async {
                await Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => CreditCardMovementsPage(cardId: card['id'].toString())));
                if (mounted) await loadData();
              },
              icon: const Icon(Icons.history_rounded),
              label: const Text('Historial'),
            ),
            if (active) OutlinedButton.icon(
              onPressed: saving ? null : () => addMovement(card),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Movimiento'),
            ),
            FilledButton.icon(
              onPressed: saving ? null : () => payCard(card),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pagar tarjeta'),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> customizeCard(Map<String, dynamic> card) async {
    if (loading || saving) return;
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Debes iniciar sesión nuevamente.');
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('financial_institutions')
            .select('id, name, is_active').order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      final institutions = rows.where((b) =>
      b['is_active'] == true || b['id'] == card['institution_id']).toList()
        ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      if (!mounted) return;
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardAppearanceDialog(
            card: card, institutions: institutions),
      );
      if (data == null || !mounted) return;
      await supabase.from('credit_cards').update(data)
          .eq('id', card['id']).eq('user_id', user.id).select('id').single();
      if (!mounted) return;
      message('Diseño actualizado.');
      await loadData();
    } catch (e) {
      if (mounted) message('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tarjetas de crédito'), actions: [
      IconButton(tooltip: 'Actualizar', onPressed: loading || saving ? null : loadData,
          icon: const Icon(Icons.refresh)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading || saving || error != null ? null : () => addCard(),
      icon: const Icon(Icons.add), label: Text(saving ? 'Guardando...' : 'Nueva tarjeta'),
    ),
    body: loading ? const Center(child: CircularProgressIndicator())
        : error != null ? Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('No se pudieron cargar las tarjetas.'),
        SelectableText(error!),
        TextButton(onPressed: loadData, child: const Text('Reintentar')),
      ]),
    ))
        : RefreshIndicator(onRefresh: loadData, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
      const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Los saldos se basan en los movimientos registrados. No se calculan intereses automáticamente.')),
      if (cards.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Text('Todavía no tienes tarjetas registradas.', textAlign: TextAlign.center)),
      CreditCardsSummary(cards: cards, balanceFor: balanceFor),
      ...cards.map(cardTile),
    ],
    )),
  );
}