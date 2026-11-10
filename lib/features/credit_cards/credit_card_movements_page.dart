import '../../utils/card_cash_advance.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../data/payment_agenda_labels.dart' show additionalCardLabel;
import '../../data/period_logic.dart' show includesDay;
import '../../widgets/adaptive_layout.dart';
import '../../widgets/date_period_field.dart';
import '../person_accounts/receipt_history.dart';
import '../help/app_help.dart';
import 'dart:convert';
import 'dart:math';
import 'credit_card_payment_edit_dialog.dart';
import '../../data/card_statement_repository.dart' show statementRows;
import 'package:flutter/material.dart';
import '../person_accounts/person_receipts_dialog.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import 'credit_card_balances.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'credit_card_movement_dialog.dart';
import '../../widgets/void_payment_dialog.dart';

class CreditCardMovementsPage extends StatefulWidget {
  const CreditCardMovementsPage({
    super.key,
    required this.cardId,
    this.initialAdditionalId,
  });
  final String cardId;
  final String? initialAdditionalId;
  @override
  State<CreditCardMovementsPage> createState() =>
      _CreditCardMovementsPageState();
}

class _CreditCardMovementsPageState extends State<CreditCardMovementsPage> {
  List<Map<String, dynamic>> movements = [];
  String name = '', currencyFilter = 'all', filter = 'all';
  Map<String, dynamic> cardData = {};
  Map<String, String> accountNames = {};
  Map<String, Map<String, dynamic>> additionalCards = {};
  late String? additionalFilter = widget.initialAdditionalId;
  bool loading = true;
  String? error;
  int requestId = 0;
  bool saving = false;
  final pendingPaymentEdits = <String, String>{};
  String editOperationId() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  void paymentMessage(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> editPayment(Map<String, dynamic> tx) async {
    if (loading ||
        saving ||
        tx['transaction_type'] != 'payment' ||
        tx['is_voided'] == true)
      return;
    setState(() => saving = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw StateError('Debes iniciar sesión nuevamente.');
      final preview = Map<String, dynamic>.from(
        await supabase.rpc(
              'card_payment_edit_preview',
              params: {'p_payment_id': tx['id']},
            )
            as Map,
      );
      final payment = Map<String, dynamic>.from(preview['payment'] as Map);
      if ('${payment['credit_card_id']}' != widget.cardId)
        throw StateError('El pago cambió de tarjeta. Actualiza.');
      final rows = await statementRows(
        'accounts',
        'id,name,currency,is_active',
        uid,
      );
      final accounts =
          rows
              .where(
                (a) =>
                    (a['currency'] == 'NIO' || a['currency'] == 'USD') &&
                    (a['is_active'] == true ||
                        a['id'] == payment['account_id']),
              )
              .toList()
            ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      if (!mounted) return;
      if (accounts.isEmpty) {
        paymentMessage(
          'Necesitas una cuenta en ${payment['currency']} para corregir este pago.',
        );
        return;
      }
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            CreditCardPaymentEditDialog(preview: preview, accounts: accounts),
      );
      if (values == null || !mounted) return;
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      final params = <String, dynamic>{
        'p_payment_id': tx['id'],
        'p_token': preview['token'],
        ...values,
      };
      final key = '$uid:${jsonEncode(params)}';
      final op = pendingPaymentEdits.putIfAbsent(key, editOperationId);
      await supabase.rpc(
        'edit_credit_card_payment_fx',
        params: {'p_id': op, ...params},
      );
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      pendingPaymentEdits.remove(key);
      if (!mounted) return;
      paymentMessage('Pago actualizado.');
      await loadData();
    } on PostgrestException catch (e) {
      paymentMessage('No se pudo editar el pago: ${e.message}');
    } catch (e) {
      paymentMessage('No se pudo editar el pago: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  static const types = {
    'purchase': 'Compra',
    cardCashAdvance: cardCashAdvanceLabel,
    'payment': 'Pago',
    'interest': 'Intereses',
    'fee': 'Comisión',
    'insurance': 'Seguro de tarjeta',
    'refund': 'Devolución',
    cardPointsRedemption: cardPointsRedemptionLabel,
    'adjustment': 'Ajuste',
  };

  String statusFilter = 'all';
  late DateTimeRange dateFilter;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    dateFilter = DateTimeRange(
      start: DateTime(today.year, today.month),
      end: DateTime(today.year, today.month + 1, 0),
    );
    loadData();
  }

  Future<void> deleteMovement(Map<String, dynamic> tx) async {
    if (loading ||
        saving ||
        tx['is_receivable_funding'] == true ||
        ![
          'purchase',
          'interest',
          'fee',
          'refund',
        ].contains(tx['transaction_type'])) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
          'Se actualizarán la deuda de la tarjeta y los reportes relacionados. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || loading || saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      final deleted = await supabase
          .from('credit_card_transactions')
          .delete()
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('credit_card_id', widget.cardId)
          .eq('transaction_type', tx['transaction_type'])
          .inFilter('transaction_type', [
            'purchase',
            'interest',
            'fee',
            'refund',
          ])
          .select('id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted.isEmpty
                ? 'No se eliminó. Revisa los permisos o si el registro cambió.'
                : 'Movimiento eliminado.',
          ),
        ),
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editMovement(Map<String, dynamic> tx) async {
    if (loading ||
        saving ||
        tx['is_receivable_funding'] == true ||
        ![
          'purchase',
          'interest',
          'fee',
          'refund',
        ].contains(tx['transaction_type'])) {
      return;
    }
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final categories = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('categories')
            .select('id, name, category_type, is_active')
            .eq('user_id', user.id)
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        categories.addAll(page);
        if (page.length < 500) break;
      }
      final available =
          categories
              .where(
                (c) =>
                    (c['category_type'] == 'expense' &&
                        c['is_active'] == true) ||
                    c['id'].toString() == tx['category_id']?.toString(),
              )
              .toList()
            ..sort(
              (a, b) => a['name'].toString().compareTo(b['name'].toString()),
            );
      final cashAccounts = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('accounts')
            .select('id,name,currency,is_active')
            .eq('user_id', user.id)
            .eq('account_type', 'cash')
            .order('id')
            .range(offset, offset + 499);
        cashAccounts.addAll(List<Map<String, dynamic>>.from(result));
        if (result.length < 500) break;
      }
      if (!mounted) return;
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardMovementDialog(
          cashAccounts: cashAccounts,
          currency: tx['currency'].toString(),
          categories: available,
          movement: tx,
          additionalCards: additionalCards.values.toList(),
        ),
      );
      if (data == null || !mounted) return;
      final changes = <String, dynamic>{
        for (final key in [
          'transaction_type',
          'charge_kind',
          'cash_advance_fee',
          'cash_advance_account_id',
          'additional_card_id',
          'currency',
          'amount',
          'category_id',
          'description',
          'reference',
        ])
          key: data[key],
      };
      final originalDate = DateTime.parse(
        tx['transaction_date'].toString(),
      ).toLocal();
      final selectedDate = DateTime.parse(
        data['transaction_date'].toString(),
      ).toLocal();
      if (originalDate.year != selectedDate.year ||
          originalDate.month != selectedDate.month ||
          originalDate.day != selectedDate.day) {
        changes['transaction_date'] = data['transaction_date'];
      }
      if (supabase.auth.currentUser?.id != user.id) return;
      final updated = await supabase
          .from('credit_card_transactions')
          .update(changes)
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('credit_card_id', widget.cardId)
          .eq('transaction_type', tx['transaction_type'])
          .select('id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isEmpty
                ? 'No se actualizó. Revisa los permisos o si el registro cambió.'
                : 'Movimiento actualizado.',
          ),
        ),
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  ReceiptFilter receiptFilter = ReceiptFilter.all;
  Map<String, int>? receiptCounts;
  int receiptRequest = 0;

  int countFor(Map<String, dynamic> row) =>
      receiptCounts?['credit_card_transactions/${row['id']}'] ?? 0;

  Future<void> refreshReceiptCounts() async {
    final request = ++receiptRequest;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final counts = await loadReceiptCounts(
        uid,
        'movement-receipts',
        movements.map((row) => 'credit_card_transactions/${row['id']}'),
      );
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = counts);
    } catch (_) {
      if (mounted && request == receiptRequest)
        setState(() => receiptCounts = null);
    }
  }

  Future<void> loadData() async {
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final card = await supabase
          .from('credit_cards')
          .select(
            'id, name, currency, opening_balance, opening_balance_nio, opening_balance_usd',
          )
          .eq('id', widget.cardId)
          .eq('user_id', user.id)
          .single();
      final additions = await loadAdditionalCards(widget.cardId, user.id);
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('credit_card_transactions')
            .select(
              'id, additional_card_id, transaction_type, charge_kind, amount, currency, transaction_date, created_at, '
              'cash_advance_fee, cash_advance_account_id, description, reference, account_id, account_debit_amount, account_debit_currency, payment_exchange_rate, category_id, is_voided, is_receivable_funding, void_reason, voided_at, categories(name)',
            )
            .eq('credit_card_id', widget.cardId)
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      final accountIds = rows
          .expand(
            (row) => [
              row['account_id']?.toString(),
              row['cash_advance_account_id']?.toString(),
            ],
          )
          .nonNulls
          .toSet()
          .toList();
      final names = <String, String>{};
      for (var offset = 0; offset < accountIds.length; offset += 100) {
        final accounts = await supabase
            .from('accounts')
            .select('id,name')
            .eq('user_id', user.id)
            .inFilter('id', accountIds.skip(offset).take(100).toList());
        for (final account in accounts) {
          names['${account['id']}'] = '${account['name']}';
        }
      }
      if (!mounted ||
          request != requestId ||
          supabase.auth.currentUser?.id != user.id)
        return;
      setState(() {
        accountNames = names;
        name = card['name'].toString();
        cardData = card;
        additionalCards = {for (final a in additions) a['id'].toString(): a};
        if (additionalFilter != '' &&
            !additionalCards.containsKey(additionalFilter)) {
          additionalFilter = null;
        }
        movements = rows;
        loading = false;
      });
      await refreshReceiptCounts();
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> voidPayment(Map<String, dynamic> tx) async {
    if (loading ||
        saving ||
        tx['transaction_type'] != 'payment' ||
        tx['is_voided'] == true)
      return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const VoidPaymentDialog(),
    );
    if (reason == null || !mounted || loading || saving) return;
    setState(() => saving = true);
    try {
      await supabase.rpc(
        'void_credit_card_payment',
        params: {
          'p_card_id': widget.cardId,
          'p_payment_id': tx['id'],
          'p_reason': reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pago anulado.')));
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo anular: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo anular: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String relatedName(dynamic value) =>
      value is Map ? value['name']?.toString() ?? '' : '';

  Widget movementCard(Map<String, dynamic> tx) {
    final type = tx['transaction_type'].toString();
    final displayType = cardMovementType(type, tx['charge_kind']);
    final increases = ['purchase', 'interest', 'fee'].contains(type);
    final decreases = ['payment', 'refund'].contains(type);
    final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
    final dateText = date == null
        ? 'Fecha no disponible'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final txCurrency = tx['currency'].toString();
    final amount = cardMoney(moneyCents(tx['amount']), txCurrency);
    final description = tx['description']?.toString().trim() ?? '';
    final reference = tx['reference']?.toString().trim() ?? '';
    final account = accountNames[tx['account_id']?.toString()] ?? '';
    final category = relatedName(tx['categories']);
    final additional = additionalCards[tx['additional_card_id']?.toString()];

    final voided = tx['is_voided'] == true;
    final voidedAt = DateTime.tryParse('${tx['voided_at']}')?.toLocal();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${types[displayType] ?? type}${voided ? ' · Anulado' : ''}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${voided
                        ? ''
                        : increases
                        ? '+'
                        : decreases
                        ? '−'
                        : ''}$amount',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: voided
                          ? theme.colorScheme.onSurfaceVariant
                          : increases
                          ? theme.colorScheme.error
                          : decreases
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(dateText, style: theme.textTheme.bodySmall),
            if (additional != null)
              Text('Adicional · ${additionalCardLabel(additional)}')
            else if (type != 'payment' && additionalCards.isNotEmpty)
              const Text('Tarjeta titular'),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description),
            ],
            if (displayType == cardCashAdvance) ...[
              Text(cardCashAdvanceBreakdown(tx)),
              if (tx['cash_advance_account_id'] != null)
                Text(
                  'Recibido en: ${accountNames[tx['cash_advance_account_id']?.toString()] ?? 'No disponible'}',
                ),
            ],
            if (type == 'payment')
              Text('Cuenta: ${account.isEmpty ? 'No disponible' : account}'),
            if (type == 'payment' && tx['account_debit_amount'] != null)
              Text(
                'Débito de cuenta: ${cardMoney(moneyCents(tx['account_debit_amount']), '${tx['account_debit_currency']}')}',
              ),
            if (type == 'payment' && tx['payment_exchange_rate'] != null)
              Text('Tasa: C\$ ${tx['payment_exchange_rate']} por US\$1'),
            if (category.isNotEmpty) Text('Categoría: $category'),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText('Referencia: $reference'),
            ],
            if (tx['is_receivable_funding'] == true)
              const Text(
                'Cargo vinculado a un prestamo. Administralo desde Prestamos por cobrar.',
              ),
            if (type == 'adjustment')
              const Text(
                'El efecto de este ajuste sobre la deuda está pendiente de definir.',
              ),
            if (voided)
              Text(
                'Sin efecto en saldos. Motivo: ${tx['void_reason'] ?? 'No especificado'}',
              ),
            if (voided && voidedAt != null)
              Text(
                'Anulado el ${voidedAt.day.toString().padLeft(2, '0')}/'
                '${voidedAt.month.toString().padLeft(2, '0')}/${voidedAt.year} '
                '${voidedAt.hour.toString().padLeft(2, '0')}:'
                '${voidedAt.minute.toString().padLeft(2, '0')}',
              ),
            MovementReceiptsButton(
              table: 'credit_card_transactions',
              record: tx,
              count: countFor(tx),
              onClosed: refreshReceiptCounts,
            ),
            if (tx['is_receivable_funding'] != true &&
                ['purchase', 'interest', 'fee', 'refund'].contains(type))
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: saving ? null : () => editMovement(tx),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: saving ? null : () => deleteMovement(tx),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            if (type == 'payment' && !voided)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: saving ? null : () => editPayment(tx),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar pago'),
                  ),
                  TextButton.icon(
                    onPressed: saving ? null : () => voidPayment(tx),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Anular pago'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget filtersPanel(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Filtrar movimientos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          DatePeriodField(
            start: dateFilter.start,
            end: dateFilter.end,
            onChanged: (range) {
              if (mounted) setState(() => dateFilter = range);
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AdaptiveColumns(
              minColumnWidth: 216,
              maxColumns: additionalCards.isEmpty ? 4 : 3,
              children: [
                if (additionalCards.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey(additionalFilter),
                    initialValue: additionalFilter ?? 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tarjeta del movimiento',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Todas'),
                      ),
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Titular / cuenta compartida'),
                      ),
                      for (final card in additionalCards.values)
                        DropdownMenuItem(
                          value: card['id'].toString(),
                          child: Text(
                            additionalCardLabel(card),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => additionalFilter = value == 'all' ? null : value,
                    ),
                  ),
                GuideAnchor(
                  id: 'currency',
                  child: DropdownButtonFormField<String>(
                    initialValue: currencyFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Ambas monedas'),
                      ),
                      DropdownMenuItem(value: 'NIO', child: Text('Córdobas')),
                      DropdownMenuItem(value: 'USD', child: Text('Dólares')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => currencyFilter = v);
                      }
                    },
                  ),
                ),
                GuideAnchor(
                  id: 'state',
                  child: DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Estado del registro',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'valid', child: Text('Vigentes')),
                      DropdownMenuItem(
                        value: 'voided',
                        child: Text('Anulados'),
                      ),
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => statusFilter = value);
                    },
                  ),
                ),
                GuideAnchor(
                  id: 'type',
                  child: DropdownButtonFormField<String>(
                    initialValue: filter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de movimiento',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Todos'),
                      ),
                      ...types.entries.map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => filter = value);
                    },
                  ),
                ),
                if (receiptCounts != null)
                  ReceiptFilterField(
                    value: receiptFilter,
                    onChanged: (value) => setState(() => receiptFilter = value),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget balanceCard(BuildContext context, String currency) {
    final balance = cardBalance(
      cardData,
      movements.map((tx) => {...tx, 'credit_card_id': widget.cardId}),
      currency,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currency == 'USD' ? 'Dólares' : 'Córdobas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${balance != null && balance < 0 ? 'A favor' : 'Deuda'}: ${cardMoney(balance?.abs(), currency)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Inicial: ${cardMoney(cardOpening(cardData, currency), currency)}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = movements.where((tx) {
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      if (date == null ||
          !includesDay(date, dateFilter.start, dateFilter.end)) {
        return false;
      }
      if (additionalFilter != null &&
          (tx['additional_card_id']?.toString() ?? '') != additionalFilter) {
        return false;
      }
      if (receiptCounts != null && !receiptFilter.matches(countFor(tx)))
        return false;
      if (currencyFilter != 'all' && tx['currency'] != currencyFilter) {
        return false;
      }
      final type = cardMovementType(tx['transaction_type'], tx['charge_kind']);
      if (filter != 'all' &&
          filter != type &&
          !(filter == 'fee' && type == 'insurance')) {
        return false;
      }
      final voided = tx['is_voided'] == true;
      if (statusFilter == 'valid' && voided) return false;
      if (statusFilter == 'voided' && !voided) return false;
      return true;
    }).toList();

    return GuideScope(
      topic: 'card_history',
      ready: !loading && error == null,
      child: Scaffold(
        appBar: AppBar(
          title: GuideAnchor(
            id: 'title',
            child: const Text('Movimientos de tarjeta'),
          ),
          actions: [
            const AppHelpButton(topic: 'cards'),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: loading || saving ? null : loadData,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: PageFrame(
          maxWidth: 1000,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No se pudo cargar el historial.'),
                        SelectableText(error!),
                        TextButton(
                          onPressed: loadData,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      pageGutter(context),
                      16,
                      pageGutter(context),
                      24,
                    ),
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        additionalCards.isEmpty
                            ? 'Saldo total de la tarjeta'
                            : 'Saldo compartido de la tarjeta titular',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      AdaptiveColumns(
                        minColumnWidth: 216,
                        children: [
                          for (final currency in cardCurrencies)
                            balanceCard(context, currency),
                        ],
                      ),
                      const SizedBox(height: 16),
                      filtersPanel(context),
                      const SizedBox(height: 20),
                      Text(
                        '${visible.length} de ${movements.length} movimientos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Últimos ingresados primero · + aumenta la deuda · − reduce la deuda',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No hay movimientos para este filtro.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...visible.map(movementCard),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
