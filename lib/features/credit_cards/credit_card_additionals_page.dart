import '../../data/payment_agenda_labels.dart' show additionalCardLabel;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../utils/money.dart';
import 'credit_card_movements_page.dart';

class CreditCardAdditionalsPage extends StatefulWidget {
  const CreditCardAdditionalsPage({super.key, required this.card});

  final Map<String, dynamic> card;

  @override
  State<CreditCardAdditionalsPage> createState() =>
      _CreditCardAdditionalsPageState();
}

class _CreditCardAdditionalsPageState extends State<CreditCardAdditionalsPage> {
  late final String? userId = supabase.auth.currentUser?.id;
  late Future<List<Map<String, dynamic>>> cards = load();
  bool saving = false;

  String get cardId => widget.card['id'].toString();
  String get currency => widget.card['currency'].toString();
  int get maxLimit => moneyCents(widget.card['credit_limit'] ?? 0);

  Future<List<Map<String, dynamic>>> load() async {
    final uid = userId;
    if (uid == null) throw StateError('Debes iniciar sesión.');
    return loadAdditionalCards(cardId, uid, includeControls: true);
  }

  void reload() {
    final next = load();
    setState(() {
      cards = next;
    });
  }

  Future<void> edit([Map<String, dynamic>? card]) async {
    if (saving) return;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AdditionalCardForm(
        card: card,
        currency: currency,
        maxLimit: maxLimit,
      ),
    );
    if (values == null || !mounted) return;
    final uid = userId;
    if (uid == null || supabase.auth.currentUser?.id != uid) return;
    setState(() => saving = true);
    try {
      final table = supabase.from('credit_card_additionals');
      if (card == null) {
        await table.insert({
          ...values,
          'credit_card_id': cardId,
          'user_id': uid,
        });
      } else {
        await table
            .update(values)
            .eq('id', card['id'])
            .eq('credit_card_id', cardId)
            .eq('user_id', uid)
            .select('id')
            .single();
      }
    } catch (error) {
      if (mounted) {
        final message = error is PostgrestException ? error.message : '$error';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar. $message')));
      }
      return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted) return;
    reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tarjeta adicional guardada.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tarjetas compartidas')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: cards,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudieron cargar las tarjetas adicionales.'),
                TextButton(onPressed: reload, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        final rows = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${widget.card['name']} · Tarjeta titular',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Límite titular: ${formatMoneyCents(maxLimit, currency)}'),
                const SizedBox(height: 8),
                const Text(
                  'Las adicionales usan el crédito de la titular. Los permisos y límites aquí registran la configuración de tu banco.',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: saving ? null : () => edit(),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Nueva adicional'),
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Text('Todavía no hay tarjetas adicionales.'),
                for (final card in rows)
                  Card(
                    child: ListTile(
                      title: Text(additionalCardLabel(card)),
                      subtitle: Text(
                        [
                          card['is_active'] == true ? 'Activa' : 'Archivada',
                          if (card['credit_limit'] == null)
                            'Sin límite registrado por corte'
                          else
                            '${formatMoneyCents(moneyCents(card['credit_limit']), currency)} por corte',
                        ].join(' · '),
                      ),
                      onTap: saving ? null : () => edit(card),
                      trailing: IconButton(
                        tooltip: 'Ver movimientos',
                        icon: const Icon(Icons.history),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CreditCardMovementsPage(
                              cardId: cardId,
                              initialAdditionalId: card['id'].toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _AdditionalCardForm extends StatefulWidget {
  const _AdditionalCardForm({
    required this.card,
    required this.currency,
    required this.maxLimit,
  });

  final Map<String, dynamic>? card;
  final String currency;
  final int maxLimit;

  @override
  State<_AdditionalCardForm> createState() => _AdditionalCardFormState();
}

class _AdditionalCardFormState extends State<_AdditionalCardForm> {
  final form = GlobalKey<FormState>();
  late final holder = TextEditingController(
    text: widget.card?['holder_name']?.toString(),
  );
  late final digits = TextEditingController(
    text: widget.card?['last_four']?.toString(),
  );
  late final limit = TextEditingController(
    text: widget.card?['credit_limit']?.toString(),
  );
  late final merchants = TextEditingController(
    text: widget.card?['merchant_restrictions']?.toString(),
  );
  late bool active = widget.card?['is_active'] != false;
  late bool allowsInternational = widget.card?['allows_international'] != false;
  late bool allowsOnline = widget.card?['allows_online'] != false;

  @override
  void dispose() {
    holder.dispose();
    digits.dispose();
    limit.dispose();
    merchants.dispose();
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final amount = limit.text.trim().replaceAll(',', '.');
    Navigator.pop(context, <String, dynamic>{
      'holder_name': holder.text.trim(),
      'last_four': digits.text.trim(),
      'credit_limit': amount.isEmpty ? null : amount,
      'limit_currency': amount.isEmpty ? null : widget.currency,
      'is_active': active,
      'allows_international': allowsInternational,
      'allows_online': allowsOnline,
      'merchant_restrictions': merchants.text.trim().isEmpty
          ? null
          : merchants.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.card == null ? 'Nueva tarjeta adicional' : 'Editar adicional',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: holder,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nombre en la tarjeta',
                ),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Escribe el nombre.' : null,
              ),
              TextFormField(
                controller: digits,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Últimos 4 dígitos',
                ),
                validator: (value) =>
                    RegExp(r'^[0-9]{4}$').hasMatch(value!.trim())
                    ? null
                    : 'Ingresa los cuatro dígitos.',
              ),
              const Divider(),
              const Text('Estado de la tarjeta'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarjeta activa'),
                value: active,
                onChanged: (value) => setState(() => active = value),
              ),
              const Divider(),
              const Text('Puede consumir en'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.language),
                title: const Text('Compras internacionales'),
                value: allowsInternational,
                onChanged: (value) =>
                    setState(() => allowsInternational = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.computer_outlined),
                title: const Text('Compras por internet'),
                value: allowsOnline,
                onChanged: (value) => setState(() => allowsOnline = value),
              ),
              const Divider(),
              const Text('Restricciones'),
              const SizedBox(height: 8),
              TextFormField(
                controller: limit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Consumo máximo por corte (${widget.currency})',
                  helperText:
                      'Opcional · Hasta ${formatMoneyCents(widget.maxLimit, widget.currency)}',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  final text = value!.trim().replaceAll(',', '.');
                  if (text.isEmpty) return null;
                  final amount = double.tryParse(text);
                  if (amount == null ||
                      !amount.isFinite ||
                      amount <= 0 ||
                      !RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(text)) {
                    return 'Ingresa un monto positivo con hasta dos decimales.';
                  }
                  return amount > widget.maxLimit / 100
                      ? 'El límite supera el de la tarjeta titular.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: merchants,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Restricciones por tipo de comercio',
                  hintText: 'Ej. Solo supermercados',
                ),
              ),
              const Text(
                'Los cambios en el banco se realizan desde su propia app.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: save, child: const Text('Guardar')),
    ],
  );
}
