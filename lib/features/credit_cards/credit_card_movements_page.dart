import 'zero_plan_form.dart';
import '../person_accounts/receipt_draft_field.dart';
import '../../data/zero_installment_charges.dart';
import '../../data/card_spending.dart';
import '../../utils/entry_order.dart';
import '../../widgets/collapsible_filters.dart';
import '../../utils/card_cash_advance.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../data/payment_agenda_labels.dart'
    show additionalCardLabel, agendaCardLabel;
import '../../data/period_logic.dart' show dayOnly, includesDay;
import '../../widgets/adaptive_layout.dart';
import '../person_accounts/receipt_history.dart';
import '../help/app_help.dart';
import 'dart:convert';
import 'dart:math';
import 'credit_card_payment_edit_dialog.dart';
import '../../data/card_statement_repository.dart'
    show statementDate, statementRows;
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
    required String this.cardId,
    this.initialAdditionalId,
    this.embedded = false,
  });
  const CreditCardMovementsPage.all({super.key, this.embedded = false})
    : cardId = null,
      initialAdditionalId = null;

  final bool embedded;
  final String? cardId;
  final String? initialAdditionalId;
  @override
  State<CreditCardMovementsPage> createState() =>
      _CreditCardMovementsPageState();
}

class _CreditCardMovementsPageState extends State<CreditCardMovementsPage> {
  List<Map<String, dynamic>> movements = [];
  bool get allCards => widget.cardId == null;
  Map<String, String> cardLabels = {};
  String? cardFilter, categoryFilter;
  DateTimeRange? customDates;
  bool useLatestCut = true;
  Map<String, DateTime> latestCuts = {};
  Map<String, int> closingDays = {};

  DateTimeRange cutRange(String? cardId, DateTime today) {
    if (cardId == null && allCards && cardLabels.isNotEmpty) {
      final starts =
          cardLabels.keys.map((id) => cutRange(id, today).start).toList()
            ..sort();
      return DateTimeRange(
        start: starts.first,
        end: starts.first.isAfter(today) ? starts.first : today,
      );
    }
    var cut = latestCuts[cardId];
    final closingDay = closingDays[cardId];
    if (closingDay != null && closingDay >= 1 && closingDay <= 31) {
      DateTime inMonth(int year, int month) {
        final last = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, closingDay > last ? last : closingDay);
      }

      var scheduled = inMonth(today.year, today.month);
      if (scheduled.isAfter(today)) {
        scheduled = inMonth(today.year, today.month - 1);
      }
      if (cut == null || scheduled.isAfter(cut)) cut = scheduled;
    }
    final start = cut == null
        ? DateTime(today.year, today.month)
        : DateTime(cut.year, cut.month, cut.day + 1);
    return DateTimeRange(
      start: start,
      end: start.isAfter(today) ? start : today,
    );
  }

  String search = '';
  String name = '', currencyFilter = 'all', filter = 'all';
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
      if ('${payment['credit_card_id']}' != tx['credit_card_id'].toString())
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
    zeroInstallmentChargeType: 'Cargo de cuota del plan',
    'purchase': 'Compra',
    'payment': 'Pago',
    'interest': 'Intereses',
    'fee': 'Comisión',
    'insurance': 'Seguro de tarjeta',
    'refund': 'Devolución',
    cardPointsRedemption: cardPointsRedemptionLabel,
    cardRebate: cardRebateLabel,
    'adjustment': 'Ajuste',
  };

  String statusFilter = 'valid';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> deleteMovement(Map<String, dynamic> tx) async {
    final isPayment = tx['transaction_type'] == 'payment';
    final canDelete = isPayment
        ? tx['is_voided'] == true
        : [
            'purchase',
            'interest',
            'fee',
            'refund',
          ].contains(tx['transaction_type']);
    if (loading ||
        saving ||
        tx['is_receivable_funding'] == true ||
        !canDelete) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPayment ? 'Eliminar pago definitivamente' : 'Eliminar movimiento',
        ),
        content: Text(
          isPayment
              ? 'Se borrará el pago anulado del historial. Esta acción es irreversible.'
              : 'Se actualizarán la deuda de la tarjeta y los reportes relacionados. Esta acción no se puede deshacer.',
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
      final query = supabase
          .from('credit_card_transactions')
          .delete()
          .eq('id', tx['id'])
          .eq('user_id', user.id)
          .eq('credit_card_id', tx['credit_card_id'])
          .eq('transaction_type', tx['transaction_type']);
      final deleted = await (isPayment ? query.eq('is_voided', true) : query)
          .select('id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted.isEmpty
                ? 'No se eliminó. Revisa los permisos o si el registro cambió.'
                : isPayment
                ? 'Pago eliminado definitivamente.'
                : 'Movimiento eliminado.',
          ),
        ),
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPayment && e.code == '23503'
                  ? 'Este pago anulado sigue vinculado a otros registros y no se pudo borrar.'
                  : 'No se pudo eliminar: ${e.message}',
            ),
          ),
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
        (!isCardCashAdvance(tx) &&
            ![
              'purchase',
              'interest',
              'fee',
              'refund',
            ].contains(tx['transaction_type']))) {
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
      final advance = isCardCashAdvance(tx);
      final cashAccounts = <Map<String, dynamic>>[];
      if (advance) {
        for (var offset = 0; ; offset += 500) {
          final page = await supabase
              .from('accounts')
              .select('id,name,currency,is_active')
              .eq('user_id', user.id)
              .eq('account_type', 'cash')
              .order('id')
              .range(offset, offset + 499);
          cashAccounts.addAll(page);
          if (page.length < 500) break;
        }
        final accountId = tx['cash_advance_account_id'];
        if (accountId != null &&
            !cashAccounts.any((a) => a['id'] == accountId)) {
          final account = await supabase
              .from('accounts')
              .select('id,name,currency')
              .eq('user_id', user.id)
              .eq('id', accountId)
              .maybeSingle();
          if (account == null) {
            throw StateError(
              'La cuenta vinculada al retiro no está disponible.',
            );
          }
          cashAccounts.add(account);
        }
      }
      if (!mounted) return;
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardMovementDialog(
          currency: tx['currency'].toString(),
          categories: available,
          movement: tx,
          cashAccounts: cashAccounts,
          additionalCards: additionalCards.values
              .where(
                (card) =>
                    !allCards || card['credit_card_id'] == tx['credit_card_id'],
              )
              .toList(),
        ),
      );
      if (data == null || !mounted) return;
      final changes = <String, dynamic>{
        for (final key in [
          'excludes_from_limit',
          if (advance) ...['cash_advance_fee', 'cash_advance_account_id'],
          'transaction_type',
          'charge_kind',
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
          .eq('credit_card_id', tx['credit_card_id'])
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
      receiptCounts?['${row['transaction_type'] == zeroInstallmentChargeType ? 'card_zero_installment_charges' : 'credit_card_transactions'}/${row['charge_id'] ?? row['id']}'] ??
      0;

  Future<void> refreshReceiptCounts() async {
    final request = ++receiptRequest;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final counts = await loadReceiptCounts(
        uid,
        'movement-receipts',
        movements
            .where(
              (row) => row['transaction_type'] != zeroInstallmentChargeType,
            )
            .map((row) => 'credit_card_transactions/${row['id']}'),
      );
      for (final row in movements.where(
        (row) => row['transaction_type'] == zeroInstallmentChargeType,
      )) {
        final folder = 'card_zero_installment_charges/${row['charge_id']}';
        var total = 0;
        for (var offset = 0; ; offset += 100) {
          final files = await supabase.storage
              .from('movement-receipts')
              .list(
                path: folder,
                searchOptions: SearchOptions(limit: 100, offset: offset),
              );
          if (supabase.auth.currentUser?.id != uid)
            throw StateError('La sesión cambió.');
          total += files.length;
          if (files.length < 100) break;
        }
        counts[folder] = total;
      }
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
      final cardId = widget.cardId;
      final cards = cardId == null
          ? await statementRows(
              'credit_cards',
              'id, name, card_reference, closing_day, financial_institutions(name)',
              user.id,
            )
          : [
              await supabase
                  .from('credit_cards')
                  .select('id,name,closing_day')
                  .eq('id', cardId)
                  .eq('user_id', user.id)
                  .single(),
            ];
      final cuts = await statementRows(
        'credit_card_statements',
        'id,credit_card_id,closing_date,is_voided',
        user.id,
      );
      final today = dayOnly(DateTime.now());
      final lastCutByCard = <String, DateTime>{};
      for (final cut in cuts) {
        if (cut['is_voided'] == true) continue;
        final date = statementDate(cut['closing_date']);
        if (date == null || date.isAfter(today)) continue;
        final id = cut['credit_card_id'].toString();
        final previous = lastCutByCard[id];
        if (previous == null || date.isAfter(previous))
          lastCutByCard[id] = date;
      }
      final additions = cardId == null
          ? await statementRows(
              'credit_card_additionals',
              'id, credit_card_id, holder_name, last_four, is_active',
              user.id,
            )
          : await loadAdditionalCards(cardId, user.id);
      final labels = {
        if (allCards)
          for (final card in cards)
            card['id'].toString(): agendaCardLabel(card, includeName: false),
      };
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final query = supabase
            .from('credit_card_transactions')
            .select(
              'id, credit_card_id, additional_card_id, transaction_type, charge_kind, amount, currency, transaction_date, created_at, '
              'description, reference, account_id, account_debit_amount, account_debit_currency, payment_exchange_rate, '
              'category_id, is_voided, is_receivable_funding, void_reason, voided_at, '
              'cash_advance_fee, cash_advance_account_id, excludes_from_limit, '
              'accounts!credit_card_transactions_account_id_user_id_fkey(name), categories(name)',
            )
            .eq('user_id', user.id);
        final result =
            await (cardId == null ? query : query.eq('credit_card_id', cardId))
                .order(
                  allCards ? 'transaction_date' : 'created_at',
                  ascending: false,
                )
                .order('id', ascending: false)
                .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      final charges = await loadZeroInstallmentCharges(user.id);
      rows.addAll(
        charges
            .where(
              (c) => cardId == null || c['credit_card_id'].toString() == cardId,
            )
            .map(zeroInstallmentHistoryRow),
      );
      if (!mounted || request != requestId) return;
      if (supabase.auth.currentUser?.id != user.id) {
        throw StateError('La sesión cambió. Actualiza la pantalla.');
      }
      rows.sort(
        allCards || widget.embedded
            ? compareNewestMovement
            : compareNewestEntry,
      );
      setState(() {
        name = cardId == null ? '' : cards.single['name'].toString();
        cardLabels = labels;
        latestCuts = lastCutByCard;
        closingDays = {
          for (final card in cards)
            if (card['closing_day'] != null)
              card['id'].toString():
                  int.tryParse('${card['closing_day']}') ?? 0,
        };
        if (!labels.containsKey(cardFilter)) cardFilter = null;
        if (!rows.any(
          (row) =>
              row['category_id']?.toString() == categoryFilter &&
              relatedName(row['categories']).isNotEmpty,
        )) {
          categoryFilter = null;
        }
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
      builder: (_) => const VoidPaymentDialog(deleteFromMovements: true),
    );
    if (reason == null || !mounted || loading || saving) return;
    setState(() => saving = true);
    try {
      await supabase.rpc(
        'void_credit_card_payment',
        params: {
          'p_card_id': tx['credit_card_id'],
          'p_payment_id': tx['id'],
          'p_reason': reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago eliminado de los movimientos vigentes.'),
        ),
      );
      await loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el pago: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el pago: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String relatedName(dynamic value) =>
      value is Map ? value['name']?.toString() ?? '' : '';

  Future<void> editInstallmentCharge(Map<String, dynamic> tx) async {
    if (saving || loading || tx['is_voided'] == true) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final values = await zeroForm(
      context,
      'Editar cargo de cuota',
      const [
        ZeroField('description', 'Descripción'),
        ZeroField('amount', 'Monto cobrado por el banco', type: 'money'),
        ZeroField('date', 'Fecha publicada por el banco', type: 'date'),
        ZeroField('reference', 'Referencia (opcional)', required: false),
      ],
      initial: {
        'description': tx['description'] ?? '',
        'amount': tx['amount'],
        'date': tx['charge_date'],
        'reference': tx['reference'] ?? '',
      },
      attachReceipt: true,
      info:
          '${tx['description']}\nSolo modifica el cargo informativo. No cambia la cuota programada, la deuda, el gasto ni el disponible.',
    );
    if (values == null || !mounted || saving) return;
    setState(() => saving = true);
    try {
      if (supabase.auth.currentUser?.id != uid)
        throw StateError('La sesión cambió.');
      final saved = await supabase.rpc(
        'register_zero_installment_charge',
        params: {
          'p_installment_id': tx['installment_id'],
          'p_date': values['date'],
          'p_description': '${values['description']}'.trim(),
          'p_reference': values['reference'] ?? '',
          'p_amount': moneyCents(values['amount']) / 100,
        },
      );
      if (!mounted) return;
      await attachFinancialReceipt(
        context,
        values[receiptDraftKey] as PendingReceipt?,
        uid,
        'card_zero_installment_charges',
        saved,
      );
      if (mounted) await loadData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo editar el cargo: $e')),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget movementCard(Map<String, dynamic> tx) {
    final type = tx['transaction_type'].toString();
    final advance = isCardCashAdvance(tx);
    final displayType = advance
        ? cardCashAdvanceLabel
        : cardMovementType(type, tx['charge_kind']);
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
    final account = relatedName(tx['accounts']);
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
                Text(
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
              ],
            ),
            const SizedBox(height: 4),
            Text(dateText, style: theme.textTheme.bodySmall),
            if (allCards)
              Text(
                cardLabels[tx['credit_card_id'].toString()] ??
                    'Tarjeta no disponible',
              ),
            if (additional != null)
              Text(
                'Adicional · ${allCards ? '••${additional['last_four']}' : additionalCardLabel(additional)}',
              )
            else if (!allCards &&
                type != 'payment' &&
                additionalCards.isNotEmpty)
              const Text('Tarjeta titular'),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description),
            ],
            if (type == 'payment')
              Text('Cuenta: ${account.isEmpty ? 'No disponible' : account}'),
            if (type == 'payment' && tx['account_debit_amount'] != null)
              Text(
                'Débito de cuenta: ${cardMoney(moneyCents(tx['account_debit_amount']), '${tx['account_debit_currency']}')}',
              ),
            if (type == 'payment' && tx['payment_exchange_rate'] != null)
              Text('Tasa: C\$ ${tx['payment_exchange_rate']} por \$1'),
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
            if (type == zeroInstallmentChargeType)
              const Text(
                'Cargo informativo de una compra ya registrada. No suma deuda ni gasto ni consume límite otra vez. Adminístralo desde Planes tasa cero.',
              ),
            if (tx['excludes_from_limit'] == true)
              Text(
                advance ? 'La comisión no consume límite' : 'No consume límite',
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                MovementReceiptsButton(
                  table: type == zeroInstallmentChargeType
                      ? 'card_zero_installment_charges'
                      : 'credit_card_transactions',
                  record: type == zeroInstallmentChargeType
                      ? {...tx, 'id': tx['charge_id']}
                      : tx,
                  count: countFor(tx),
                  onClosed: refreshReceiptCounts,
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (type == zeroInstallmentChargeType && !voided)
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => editInstallmentCharge(tx),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar cargo'),
                      ),
                    if (advance && !voided)
                      Align(
                        widthFactor: 1,
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: saving ? null : () => editMovement(tx),
                          child: const Text('Editar retiro'),
                        ),
                      ),
                    if (!advance &&
                        tx['is_receivable_funding'] != true &&
                        [
                          'purchase',
                          'interest',
                          'fee',
                          'refund',
                        ].contains(type))
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
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    if (type == 'payment' && voided)
                      Align(
                        widthFactor: 1,
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: saving ? null : () => deleteMovement(tx),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Eliminar definitivamente'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
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
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar pago'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String movementDateLabel(DateTime date) {
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final year = date.year == DateTime.now().year ? '' : ' de ${date.year}';
    return '${weekdays[date.weekday - 1]} ${date.day} de ${months[date.month - 1]}$year';
  }

  Widget compactMovement(Map<String, dynamic> tx) {
    final type = tx['transaction_type']?.toString() ?? '';
    final decreases = type == 'payment' || type == 'refund';
    final increases = ['purchase', 'interest', 'fee'].contains(type);
    final voided = tx['is_voided'] == true;
    final theme = Theme.of(context);
    final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
    final dateText = date == null ? '' : movementDateLabel(date);
    final amount = cardMoney(moneyCents(tx['amount']), '${tx['currency']}');
    final description = tx['description']?.toString().trim() ?? '';
    return ExpansionTile(
      key: PageStorageKey('cut-movement/${tx['id']}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      title: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            description.isEmpty ? types[type] ?? 'Movimiento' : description,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${increases
                ? '+'
                : decreases
                ? '−'
                : ''}$amount',
            style: theme.textTheme.titleSmall?.copyWith(
              color: voided
                  ? theme.disabledColor
                  : decreases
                  ? theme.colorScheme.primary
                  : increases
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
              decoration: voided ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
      subtitle: Text(
        [
          dateText,
          if (type == zeroInstallmentChargeType) 'Cuota informativa',
          if (voided) 'Anulado',
        ].where((text) => text.isNotEmpty).join(' · '),
      ),
      children: [movementCard(tx)],
    );
  }

  Widget dateSelector(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final range = useLatestCut
        ? cutRange(widget.cardId ?? cardFilter, today)
        : customDates;
    final loc = MaterialLocalizations.of(context);
    final dateLabel = range == null
        ? 'Todas las fechas'
        : useLatestCut && range.start.isAfter(today)
        ? 'Desde ${loc.formatShortDate(range.start)}'
        : '${loc.formatShortDate(range.start)} – ${loc.formatShortDate(range.end)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final existing = useLatestCut
                  ? cutRange(widget.cardId ?? cardFilter, today)
                  : customDates;
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
                initialDateRange: existing,
              );
              if (mounted && range != null) {
                setState(() {
                  useLatestCut = false;
                  customDates = range;
                });
              }
            },
            icon: const Icon(Icons.date_range_outlined),
            label: Text(dateLabel),
          ),
          if (!useLatestCut)
            TextButton(
              onPressed: () => setState(() => useLatestCut = true),
              child: const Text('Corte actual'),
            ),
          if (dateLabel != 'Todas las fechas')
            TextButton(
              onPressed: () => setState(() {
                useLatestCut = false;
                customDates = null;
              }),
              child: const Text('Todas las fechas'),
            ),
        ],
      ),
    );
  }

  Widget filtersPanel(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final selectedId = widget.cardId ?? cardFilter;
    final range = useLatestCut ? cutRange(selectedId, today) : customDates;
    final localizations = MaterialLocalizations.of(context);
    final dateLabel = range != null
        ? '${localizations.formatShortDate(range.start)} – ${localizations.formatShortDate(range.end)}'
        : useLatestCut && selectedId == null && latestCuts.isNotEmpty
        ? 'Último corte por tarjeta'
        : 'Todas las fechas';
    final categories = {
      for (final tx in movements)
        if (tx['category_id'] != null &&
            relatedName(tx['categories']).isNotEmpty)
          tx['category_id'].toString(): relatedName(tx['categories']),
    };
    return CollapsibleFilters(
      summary: dateLabel,
      children: [
        if (allCards) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextFormField(
              initialValue: search,
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                labelText: 'Buscar descripción o referencia',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GuideAnchor(
            id: 'type',
            child: DropdownButtonFormField<String>(
              initialValue: filter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de movimiento',
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Todos')),
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AdaptiveColumns(
            minColumnWidth: allCards ? 320 : 216,
            maxColumns: allCards || additionalCards.isNotEmpty ? 3 : 4,
            children: [
              if (allCards) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(('card', cardFilter)),
                  initialValue: cardFilter ?? '',
                  isExpanded: true,
                  itemHeight: null,
                  selectedItemBuilder: (_) => [
                    const Text('Todas las tarjetas'),
                    for (final label in cardLabels.values)
                      Text(
                        label.contains(' · ••')
                            ? label.split(' · ').reversed.join(' · ')
                            : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                  decoration: const InputDecoration(labelText: 'Tarjeta'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todas las tarjetas'),
                    ),
                    for (final entry in cardLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(entry.value),
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => cardFilter = value == '' ? null : value),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(('category', categoryFilter)),
                  initialValue: categories.containsKey(categoryFilter)
                      ? categoryFilter
                      : '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Todas las categorías'),
                    ),
                    for (final entry in categories.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => categoryFilter = value == '' ? null : value,
                  ),
                ),
              ] else if (additionalCards.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(additionalFilter),
                  initialValue: additionalFilter ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tarjeta del movimiento',
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Todas')),
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
                    DropdownMenuItem(value: 'voided', child: Text('Anulados')),
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => statusFilter = value);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final term = search.trim().toLowerCase();
    final visible = movements.where((tx) {
      final dateRange = useLatestCut
          ? cutRange(tx['credit_card_id']?.toString(), today)
          : customDates;
      final date = DateTime.tryParse('${tx['transaction_date']}')?.toLocal();
      if (useLatestCut && date != null && dayOnly(date).isAfter(today))
        return false;
      if (dateRange != null &&
          (date == null ||
              !includesDay(date, dateRange.start, dateRange.end))) {
        return false;
      }
      if (cardFilter != null && tx['credit_card_id'].toString() != cardFilter)
        return false;
      if (categoryFilter != null &&
          tx['category_id'].toString() != categoryFilter)
        return false;
      if (term.isNotEmpty &&
          ![tx['description'], tx['reference']].any(
            (value) => (value?.toString() ?? '').toLowerCase().contains(term),
          ))
        return false;
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

    final spending = <String, int>{'USD': 0, 'NIO': 0};
    for (final tx in visible) {
      final currency = tx['currency'].toString();
      if (spending.containsKey(currency)) {
        final installmentCharge =
            widget.embedded &&
            tx['transaction_type'] == zeroInstallmentChargeType &&
            tx['is_voided'] != true;
        spending[currency] =
            spending[currency]! +
            (installmentCharge
                ? moneyCents(tx['amount'])
                : cardSpendingCents(tx));
      }
    }

    final content = PageFrame(
      maxWidth: 1440,
      child: loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
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
              child: CustomScrollView(
                shrinkWrap: widget.embedded,
                primary: !widget.embedded,
                physics: widget.embedded
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      pageGutter(context),
                      16,
                      pageGutter(context),
                      0,
                    ),
                    sliver: SliverList.list(
                      children: [
                        if (!allCards && !widget.embedded) ...[
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                        ],
                        ...[
                          Text(
                            widget.embedded
                                ? 'Cargos del período'
                                : 'Gasto neto en tarjetas',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          AdaptiveColumns(
                            minColumnWidth: 140,
                            spacing: 8,
                            children: [
                              for (final entry in spending.entries)
                                Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          entry.key == 'USD'
                                              ? 'Dólares'
                                              : 'Córdobas',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cardMoney(entry.value, entry.key),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.embedded
                                ? 'Incluye cuotas publicadas y cargos, menos devoluciones. Los pagos se muestran en la lista.'
                                : 'Cargos menos devoluciones según los filtros.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                        dateSelector(context),
                        if (!widget.embedded) filtersPanel(context),
                        const SizedBox(height: 8),
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No hay movimientos para este filtro.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      pageGutter(context),
                      0,
                      pageGutter(context),
                      24,
                    ),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, index) => widget.embedded
                          ? compactMovement(visible[index])
                          : movementCard(visible[index]),
                    ),
                  ),
                ],
              ),
            ),
    );
    return GuideScope(
      topic: 'card_history',
      ready: !loading && error == null,
      child: widget.embedded
          ? Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            useLatestCut
                                ? 'Movimientos del corte actual'
                                : 'Movimientos de tarjetas',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualizar movimientos',
                          onPressed: loading || saving ? null : loadData,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  content,
                ],
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: GuideAnchor(
                  id: 'title',
                  child: Text(
                    compactLayout(context)
                        ? (allCards
                              ? 'Historial de tarjetas'
                              : 'Historial de tarjeta')
                        : (allCards
                              ? 'Movimientos de tarjetas'
                              : 'Movimientos de tarjeta'),
                    style: compactLayout(context)
                        ? const TextStyle(fontSize: 17)
                        : null,
                  ),
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
              body: content,
            ),
    );
  }
}
