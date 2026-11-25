import 'package:flutter/material.dart';

import '../../data/card_statement_pdf.dart';
import '../../data/card_statement_logic.dart';
import '../../data/period_logic.dart';
import '../../widgets/adaptive_layout.dart';
import '../person_accounts/receipt_draft_field.dart';

class CreditCardStatementForm extends StatefulWidget {
  const CreditCardStatementForm({
    super.key,
    this.statements = const [],
    this.bank = '',
  });

  final List<Map<String, dynamic>> statements;
  final String bank;

  @override
  State<CreditCardStatementForm> createState() =>
      _CreditCardStatementFormState();
}

class _CreditCardStatementFormState extends State<CreditCardStatementForm> {
  static const currencies = ['NIO', 'USD'];
  final formKey = GlobalKey<FormState>();
  final receipt = ReceiptDraft();
  final balances = {for (final c in currencies) c: TextEditingController()};
  final minimums = {for (final c in currencies) c: TextEditingController()};
  final overdues = {for (final c in currencies) c: TextEditingController()};
  final charges = {for (final c in currencies) c: TextEditingController()};
  final financing = {for (final c in currencies) c: TextEditingController()};
  final bonusInterest = {
    for (final c in currencies) c: TextEditingController(),
  };
  final bonusStates = {for (final c in currencies) c: 'pending'};
  final notes = TextEditingController();
  final existing = <String, Map<String, dynamic>>{};
  DateTime closing = DateTime.now();
  DateTime due = DateTime.now().add(const Duration(days: 20));
  DateTime? bonus;
  String? error;

  bool get usesPaymentFields => statementPdfBankName(widget.bank) != null;
  bool get showsOverdue => statementShowsOverdue(widget.bank);

  bool get editing => existing.isNotEmpty;
  Iterable<String> get shownCurrencies =>
      editing ? currencies.where(existing.containsKey) : currencies;

  @override
  void initState() {
    super.initState();
    for (final row in widget.statements) {
      final currency = '${row['currency']}';
      existing[currency] = row;
      bonusInterest[currency]!.text =
          row['bonifiable_interest_due']?.toString() ?? '';
      bonusStates[currency] =
          row['bonifiable_interest_status']?.toString() ?? 'pending';
      charges[currency]!.text = row['charges_interest_due']?.toString() ?? '';
      financing[currency]!.text = row['intra_financing_due']?.toString() ?? '';
      balances[currency]!.text = '${row['balance_due']}';
      minimums[currency]!.text = row['minimum_due']?.toString() ?? '';
      overdues[currency]!.text = row['overdue_due']?.toString() ?? '';
    }
    final statement = widget.statements.firstOrNull;
    if (statement != null) {
      closing = statementDate(statement['closing_date'])!;
      due = statementDate(statement['due_date'])!;
      bonus = statementDate(statement['bonus_payment_date']);
      notes.text = statement['notes']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      ...balances.values,
      ...minimums.values,
      ...overdues.values,
      ...charges.values,
      ...financing.values,
      ...bonusInterest.values,
      notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? amount(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  String? validateAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = amount(text);
    if (!RegExp(r'^\d+([.,]\d{1,6})?$').hasMatch(text) ||
        parsed == null ||
        !parsed.isFinite ||
        parsed > 999999999999.99) {
      return 'Ingresa un monto no negativo con hasta seis decimales.';
    }
    return null;
  }

  void save() {
    if (receipt.picking || !formKey.currentState!.validate()) return;
    final rows = <Map<String, dynamic>>[
      for (final currency in shownCurrencies)
        if (balances[currency]!.text.trim().isNotEmpty)
          {
            'currency': currency,
            'balance': amount(balances[currency]!.text),
            'minimum': amount(minimums[currency]!.text),
            'bonifiable_interest': amount(bonusInterest[currency]!.text) ?? 0,
            'bonifiable_status': bonusStates[currency],
            'charges_interest': amount(charges[currency]!.text),
            'intra_financing': amount(financing[currency]!.text),
            if (showsOverdue) 'overdue': amount(overdues[currency]!.text),
            if (existing[currency] case final row?) 'id': row['id'],
          },
    ];
    final bonusDate = bonus;
    if (rows.isEmpty) {
      setState(
        () => error =
            'Ingresa el ${balanceLabel.toLowerCase()} de al menos una moneda.',
      );
      return;
    }
    if (dayOnly(due).isBefore(dayOnly(closing))) {
      setState(
        () => error = 'La fecha máxima de pago no puede ser anterior al corte.',
      );
      return;
    }
    if (bonusDate != null && !includesDay(bonusDate, closing, due)) {
      setState(
        () => error =
            'La fecha para bonificar debe quedar entre el corte y la fecha máxima de pago.',
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'rows': rows,
      'closing_date': isoDay(closing),
      'bonus_payment_date': bonusDate == null ? null : isoDay(bonusDate),
      'due_date': isoDay(due),
      'notes': notes.text.trim(),
      ...receipt.fields,
    });
  }

  Widget dateField(
    String title,
    DateTime? date,
    ValueChanged<DateTime> change,
  ) => OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text(
      date == null ? title : '$title\n${shortStatementDate(isoDay(date))}',
      textAlign: TextAlign.center,
    ),
    onPressed: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: date ?? closing,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (selected != null && mounted)
        setState(() {
          change(selected);
          error = null;
        });
    },
  );

  String currencyLabel(String currency) =>
      currency == 'NIO' ? 'Córdobas (C\$)' : 'Dólares (\$)';

  String get balanceLabel =>
      usesPaymentFields ? 'Pago de contado' : 'Saldo al corte';

  Widget amountField(
    String currency,
    Map<String, TextEditingController> controllers,
    String label,
  ) => TextFormField(
    controller: controllers[currency],
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixText: currency == 'NIO' ? 'C\$ ' : '\$ ',
      errorMaxLines: 3,
    ),
    validator: (value) {
      final invalid = validateAmount(value);
      if (invalid != null) return invalid;
      final parsed = amount(value);
      if (controllers == balances) {
        return editing && parsed == null
            ? 'Ingresa el ${balanceLabel.toLowerCase()}.'
            : null;
      }
      if (parsed == null) return null;
      final balance = amount(balances[currency]!.text);
      if (balance == null) return 'Ingresa primero el saldo de esta moneda.';
      return controllers == minimums && parsed > balance
          ? 'El mínimo no puede superar el saldo.'
          : null;
    },
  );

  Widget amounts(String currency) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        currencyLabel(currency),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (!usesPaymentFields) ...[
        amountField(currency, balances, balanceLabel),
        const SizedBox(height: 8),
      ],
      amountField(currency, minimums, 'Pago mínimo (opcional)'),
      if (showsOverdue) ...[
        const SizedBox(height: 8),
        amountField(currency, overdues, 'Pago atrasado (opcional)'),
      ],
      const SizedBox(height: 8),
      amountField(currency, charges, 'Cargos e intereses (opcional)'),
      const SizedBox(height: 8),
      amountField(currency, financing, 'Intrafinanciamientos (opcional)'),
      const SizedBox(height: 8),
      amountField(currency, bonusInterest, 'Intereses bonificables'),
      if (usesPaymentFields) ...[
        const SizedBox(height: 8),
        amountField(currency, balances, balanceLabel),
      ],
    ],
  );

  Widget amountsLayout() => LayoutBuilder(
    builder: (context, constraints) {
      if (!usesPaymentFields ||
          shownCurrencies.length != 2 ||
          constraints.maxWidth < 680) {
        return AdaptiveColumns(
          minColumnWidth: 240,
          children: [for (final currency in shownCurrencies) amounts(currency)],
        );
      }
      return Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Concepto')),
              for (final currency in currencies) ...[
                const SizedBox(width: 8),
                Expanded(child: Text(currencyLabel(currency))),
              ],
            ],
          ),
          for (final (label, controllers) in [
            ('Pago mínimo', minimums),
            if (showsOverdue) ('Pago atrasado', overdues),
            ('Cargos e intereses', charges),
            ('Intrafinanciamientos', financing),
            ('Intereses bonificables', bonusInterest),
            (balanceLabel, balances),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(label),
                    ),
                  ),
                  for (final currency in currencies) ...[
                    const SizedBox(width: 8),
                    Expanded(child: amountField(currency, controllers, label)),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget attachment() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Documento del banco (opcional)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const Text('Adjunta un PDF o una foto para todo el corte. Hasta 10 MB.'),
      ReceiptDraftField(draft: receipt),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Text(
      editing ? 'Editar estado de cuenta' : 'Registrar estado de cuenta',
    ),
    content: SizedBox(
      width: 1040,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copia los importes y las fechas del banco. Los montos se guardan por moneda.',
              ),
              if (!editing)
                const Text(
                  'Si el banco solo indica una moneda, deja la otra en blanco. Usa 0 para registrar un saldo de cero.',
                ),
              const SizedBox(height: 16),
              if (!editing && usesPaymentFields) ...[
                attachment(),
                const SizedBox(height: 16),
              ],
              amountsLayout(),
              const SizedBox(height: 12),
              AdaptiveColumns(
                minColumnWidth: 240,
                children: [
                  for (final currency in shownCurrencies)
                    DropdownButtonFormField<String>(
                      initialValue: bonusStates[currency],
                      decoration: InputDecoration(
                        labelText: 'Bonificables · ${currencyLabel(currency)}',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pendientes de bonificar'),
                        ),
                        DropdownMenuItem(
                          value: 'bonified',
                          child: Text('Bonificados por el banco'),
                        ),
                        DropdownMenuItem(
                          value: 'recorded',
                          child: Text(
                            'Cobrados: ya registrados en movimientos',
                          ),
                        ),
                      ],
                      isExpanded: true,
                      onChanged: (value) =>
                          setState(() => bonusStates[currency] = value!),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Los bonificables pendientes se suman a la deuda y al uso del límite, separados del pago de contado. Cambia el estado cuando el banco confirme la bonificación o hayas registrado el cobro en movimientos.',
              ),

              const SizedBox(height: 8),
              const Text(
                'Cargos e intereses e intrafinanciamientos detallan el corte. Ingresa en el pago de contado el total informado por el banco.',
              ),

              const SizedBox(height: 8),
              Text(
                showsOverdue
                    ? 'Deja vacíos el mínimo y el atraso si el banco no los informa. El atraso se guarda como referencia.'
                    : 'Deja vacío el mínimo si el banco no lo informa.',
              ),
              const SizedBox(height: 16),
              AdaptiveColumns(
                minColumnWidth: 250,
                maxColumns: 3,
                children: [
                  dateField(
                    'Fecha de corte',
                    closing,
                    (value) => closing = value,
                  ),
                  dateField(
                    'Fecha máxima de pago',
                    due,
                    (value) => due = value,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: dateField(
                              'Fecha para bonificar',
                              bonus,
                              (value) => bonus = value,
                            ),
                          ),
                          if (bonus != null)
                            IconButton(
                              tooltip: 'Quitar fecha para bonificar',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                bonus = null;
                                error = null;
                              }),
                            ),
                        ],
                      ),
                      if (bonus == null)
                        const Text('Opcional, según lo que indique el banco.'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              if (!editing && !usesPaymentFields) ...[
                const SizedBox(height: 14),
                attachment(),
              ],
              if (editing) ...[
                const SizedBox(height: 12),
                const Text(
                  'Para gestionar el archivo, abre Documento del banco desde el corte.',
                ),
              ],
              if (error case final problem?)
                Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      FilledButton(onPressed: save, child: const Text('Guardar corte')),
    ],
  );
}
