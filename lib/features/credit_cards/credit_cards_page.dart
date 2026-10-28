import 'zero_plans_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/card_statement_repository.dart';
import 'credit_card_statements_page.dart';
import 'credit_card_period_summary.dart';
import 'credit_card_balances.dart';
import 'credit_card_form_dialog.dart';
import 'credit_card_movement_dialog.dart';
import 'credit_card_payment_dialog.dart';
import 'credit_card_movements_page.dart';
import 'credit_cards_summary.dart';
import 'credit_card_wallet.dart';
import 'credit_card_details.dart';

class CreditCardsPage extends StatefulWidget {
  const CreditCardsPage({super.key});
  @override
  State<CreditCardsPage> createState() => _CreditCardsPageState();
}

class _CreditCardsPageState extends State<CreditCardsPage> {
  List<Map<String, dynamic>> cards = [], transactions = [];
  bool loading = true, saving = false;
  CardStatementData? statementData;
  String? error, selectedCardId;
  int requestId = 0;
  Map<String, dynamic>? get selectedCard {
    for (final c in cards) {
      if (c['id'].toString() == selectedCardId) {
        return c;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void checkSession(String id) {
    if (supabase.auth.currentUser?.id != id) {
      throw StateError('La sesión cambió. Intenta nuevamente.');
    }
  }

  Future<List<Map<String, dynamic>>> readRows(
    String table,
    String columns,
    String userId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      final result = await supabase
          .from(table)
          .select(columns)
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + 499);
      final page = List<Map<String, dynamic>>.from(result);
      rows.addAll(page);
      if (page.length < 500) {
        break;
      }
    }
    return rows;
  }

  Future<void> loadData() async {
    if (!mounted) {
      return;
    }
    final request = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debes iniciar sesión nuevamente.');
      }
      final cardRows = await readRows(
        'credit_cards',
        'id, name, card_reference, currency, credit_limit, opening_balance, opening_balance_nio, '
            'opening_balance_usd, limit_exchange_rate, closing_day, payment_day, is_active, '
            'institution_id, network, card_tier, card_product, financial_institutions(name, code)',
        user.id,
      );
      final txRows = await readRows(
        'credit_card_transactions',
        'id, credit_card_id, transaction_type, amount, currency, is_voided',
        user.id,
      );
      final periods = await loadCardStatements(user.id);
      checkSession(user.id);
      if (!mounted || request != requestId) {
        return;
      }
      setState(() {
        cards = cardRows;
        transactions = txRows;
        statementData = periods;
        if (!cards.any((c) => c['id'].toString() == selectedCardId)) {
          selectedCardId = cards.isEmpty ? null : cards.first['id'].toString();
        }
        loading = false;
      });
    } catch (e) {
      if (mounted && request == requestId) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  int? balanceFor(Map<String, dynamic> card, String currency) =>
      cardBalance(card, transactions, currency);

  Future<String?> chooseCurrency(String title) => showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        for (final c in cardCurrencies)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(c == 'USD' ? 'Dólares · US\$' : 'Córdobas · C\$'),
            ),
          ),
      ],
    ),
  );

  Future<void> payCard(Map<String, dynamic> card) async {
    if (loading || saving) {
      return;
    }
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debes iniciar sesión nuevamente.');
      }
      final currency = await chooseCurrency('¿En qué moneda pagarás?');
      if (currency == null || !mounted) {
        return;
      }
      final rows = await readRows(
        'accounts',
        'id, name, currency, is_active',
        user.id,
      );
      final accounts = rows
          .where((a) => a['is_active'] == true && a['currency'] == currency)
          .toList();
      if (!mounted) {
        return;
      }
      if (accounts.isEmpty) {
        message('Necesitas una cuenta activa en $currency.');
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardPaymentDialog(
          accounts: accounts,
          currency: currency,
          statements:
              statementData?.payableFor('${card['id']}', currency) ?? [],
        ),
      );
      if (data == null || !mounted) {
        return;
      }
      checkSession(user.id);
      final statementId = data['statement_id'];
      await supabase.rpc(
        statementId == null
            ? 'register_credit_card_payment'
            : 'register_credit_card_payment_for_statement',
        params: {
          'p_card_id': card['id'],
          'p_account_id': data['account_id'],
          'p_amount': data['amount'],
          'p_reference': data['reference'],
          if (statementId != null) 'p_statement_id': statementId,
        },
      );
      if (!mounted) {
        return;
      }
      message('Pago registrado en $currency.');
      await loadData();
    } on PostgrestException catch (e) {
      message('No se pudo registrar: ${e.message}');
    } catch (e) {
      message('No se pudo registrar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> addMovement(Map<String, dynamic> card) async {
    if (loading || saving || card['is_active'] != true) {
      return;
    }
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debes iniciar sesión nuevamente.');
      }
      final categories = await readRows(
        'categories',
        'id, name, category_type, is_active',
        user.id,
      );
      final available =
          categories
              .where(
                (c) =>
                    c['category_type'] == 'expense' && c['is_active'] == true,
              )
              .toList()
            ..sort(
              (a, b) => a['name'].toString().compareTo(b['name'].toString()),
            );
      if (!mounted) {
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => CreditCardMovementDialog(
          currency: card['currency'].toString(),
          categories: available,
        ),
      );
      if (data == null || !mounted) {
        return;
      }
      checkSession(user.id);
      final current = await supabase
          .from('credit_cards')
          .select('is_active')
          .eq('id', card['id'])
          .eq('user_id', user.id)
          .single();
      if (current['is_active'] != true) {
        throw StateError('La tarjeta ya no está activa.');
      }
      await supabase.from('credit_card_transactions').insert({
        ...data,
        'credit_card_id': card['id'],
        'user_id': user.id,
      });
      if (!mounted) {
        return;
      }
      message('Movimiento registrado.');
      await loadData();
    } on PostgrestException catch (e) {
      message('No se pudo guardar: ${e.message}');
    } catch (e) {
      message('No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> addCard([Map<String, dynamic>? card]) async {
    if (loading || saving) {
      return;
    }
    setState(() => saving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Debes iniciar sesión nuevamente.');
      }
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase
            .from('financial_institutions')
            .select('id, name, is_active')
            .order('id')
            .range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) {
          break;
        }
      }
      final institutions =
          rows
              .where(
                (b) =>
                    b['is_active'] == true ||
                    b['id'] == card?['institution_id'],
              )
              .toList()
            ..sort(
              (a, b) => a['name'].toString().compareTo(b['name'].toString()),
            );
      if (!mounted) {
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            CreditCardFormDialog(card: card, institutions: institutions),
      );
      if (data == null || !mounted) {
        return;
      }
      checkSession(user.id);
      if (card == null) {
        await supabase.from('credit_cards').insert({
          ...data,
          'user_id': user.id,
        });
      } else {
        final changes = <String, dynamic>{
          for (final key in [
            'name',
            'card_reference',
            'credit_limit',
            'currency',
            'closing_day',
            'payment_day',
            'institution_id',
            'network',
            'card_tier',
            'card_product',
            'limit_exchange_rate',
          ])
            if (data.containsKey(key)) key: data[key],
        };
        // Los saldos sin cambios se conservan en la base de datos. El trigger
        // sincroniza opening_balance con la moneda del límite seleccionada.
        for (final c in cardCurrencies) {
          final key = 'opening_balance_${c.toLowerCase()}';
          if (data.containsKey(key) &&
              moneyCents(data[key]) != cardOpening(card, c)) {
            changes[key] = data[key];
          }
        }
        await supabase
            .from('credit_cards')
            .update(changes)
            .eq('id', card['id'])
            .eq('user_id', user.id)
            .select('id')
            .single();
      }
      if (!mounted) {
        return;
      }
      message(card == null ? 'Tarjeta registrada.' : 'Tarjeta actualizada.');
      await loadData();
    } on PostgrestException catch (e) {
      message('No se pudo guardar: ${e.message}');
    } catch (e) {
      message('No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> toggleCard(Map<String, dynamic> card) async {
    if (loading || saving) {
      return;
    }
    final active = card['is_active'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(active ? 'Activar tarjeta' : 'Desactivar tarjeta'),
        content: Text(
          active
              ? 'La tarjeta admitirá nuevos cargos.'
              : 'Se conservarán las dos deudas y el historial. Podrás seguir registrando pagos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || loading || saving) {
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      message('Debes iniciar sesión nuevamente.');
      return;
    }
    setState(() => saving = true);
    try {
      final updated = await supabase
          .from('credit_cards')
          .update({'is_active': active})
          .eq('id', card['id'])
          .eq('user_id', user.id)
          .eq('is_active', !active)
          .select('id');
      if (!mounted) {
        return;
      }
      message(
        updated.isEmpty
            ? 'El registro cambió o faltan permisos.'
            : active
            ? 'Tarjeta activada.'
            : 'Tarjeta desactivada.',
      );
      await loadData();
    } catch (e) {
      message('No se pudo actualizar: $e');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> history(Map<String, dynamic> card) async {
    if (loading || saving) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreditCardMovementsPage(cardId: card['id'].toString()),
      ),
    );
    if (mounted) {
      await loadData();
    }
  }

  String cardOrder = 'debt_desc';
  String orderCurrency = 'USD';

  List<Map<String, dynamic>> get orderedCards {
    final result = [...cards];

    int compareNames(Map<String, dynamic> a, Map<String, dynamic> b) {
      final comparison = a['name'].toString().toLowerCase().compareTo(
        b['name'].toString().toLowerCase(),
      );
      return comparison != 0
          ? comparison
          : a['id'].toString().compareTo(b['id'].toString());
    }

    result.sort((a, b) {
      if (cardOrder == 'name') {
        return compareNames(a, b);
      }

      final balanceA = balanceFor(a, orderCurrency);
      final balanceB = balanceFor(b, orderCurrency);

      // Los saldos pendientes de revisión quedan al final.
      if (balanceA == null || balanceB == null) {
        if (balanceA == null && balanceB == null) {
          return compareNames(a, b);
        }
        return balanceA == null ? 1 : -1;
      }

      final debtA = balanceA > 0 ? balanceA : 0;
      final debtB = balanceB > 0 ? balanceB : 0;

      final comparison = cardOrder == 'debt_asc'
          ? debtA.compareTo(debtB)
          : debtB.compareTo(debtA);

      return comparison != 0 ? comparison : compareNames(a, b);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedCard;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarjetas de crédito'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: loading || saving ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 650
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: loading || saving || error != null
                    ? null
                    : () => addCard(),
                icon: const Icon(Icons.add),
                label: Text(saving ? 'Guardando...' : 'Nueva tarjeta'),
              ),
            ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 650
          ? null
          : FloatingActionButton.extended(
              onPressed: loading || saving || error != null
                  ? null
                  : () => addCard(),
              icon: const Icon(Icons.add),
              label: Text(saving ? 'Guardando...' : 'Nueva tarjeta'),
            ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar las tarjetas.'),
                      SelectableText(error!),
                      TextButton(
                        onPressed: loadData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView(
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        12,
                        16,
                        12,
                        MediaQuery.sizeOf(context).width < 650 ? 24 : 110,
                      ),
                      children: [
                        if (cards.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(Icons.wallet_outlined, size: 60),
                                const SizedBox(height: 16),
                                const Text('Tu tarjetero está vacío'),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: saving ? null : () => addCard(),
                                  child: const Text('Agregar tarjeta'),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: MediaQuery.sizeOf(context).width < 650
                                    ? MediaQuery.sizeOf(context).width -
                                          MediaQuery.paddingOf(
                                            context,
                                          ).horizontal -
                                          24
                                    : 240,
                                child: DropdownButtonFormField<String>(
                                  initialValue: cardOrder,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Ordenar por',
                                    prefixIcon: Icon(Icons.sort_rounded),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'debt_desc',
                                      child: Text('Mayor deuda primero'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'debt_asc',
                                      child: Text('Menor deuda primero'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'name',
                                      child: Text('Nombre A–Z'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => cardOrder = value);
                                    }
                                  },
                                ),
                              ),
                              if (cardOrder != 'name')
                                SizedBox(
                                  width: MediaQuery.sizeOf(context).width < 650
                                      ? MediaQuery.sizeOf(context).width -
                                            MediaQuery.paddingOf(
                                              context,
                                            ).horizontal -
                                            24
                                      : 200,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: orderCurrency,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Comparar deuda en',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'USD',
                                        child: Text('Dólares · USD'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'NIO',
                                        child: Text('Córdobas · NIO'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => orderCurrency = value);
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CreditCardWallet(
                            cards: orderedCards,
                            selectedId: selectedCardId,
                            balanceFor: balanceFor,
                            onSelected: saving
                                ? null
                                : (id) => setState(() => selectedCardId = id),
                          ),
                          const SizedBox(height: 14),
                          if (selected != null)
                            CreditCardDetails(
                              card: selected,
                              balances: {
                                for (final c in cardCurrencies)
                                  c: balanceFor(selected, c),
                              },
                              onEdit: saving ? null : () => addCard(selected),
                              onPlans: saving
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ZeroPlansPage(card: selected),
                                        ),
                                      );
                                      if (mounted) await loadData();
                                    },
                              onToggle: saving
                                  ? null
                                  : () => toggleCard(selected),
                              onHistory: saving
                                  ? null
                                  : () => history(selected),
                              onMovement: saving
                                  ? null
                                  : () => addMovement(selected),
                              onPayment: saving
                                  ? null
                                  : () => payCard(selected),
                            ),
                          if (selected != null && statementData != null) ...[
                            const SizedBox(height: 12),
                            CreditCardPeriodSummary(
                              cardId: '${selected['id']}',
                              data: statementData!,
                              onManage: saving
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              CreditCardStatementsPage(
                                                card: selected,
                                              ),
                                        ),
                                      );
                                      if (mounted) {
                                        await loadData();
                                      }
                                    },
                            ),
                          ],
                          const SizedBox(height: 26),
                          const Text(
                            'Resumen de todas tus tarjetas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          CreditCardsSummary(
                            cards: cards,
                            balanceFor: balanceFor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
