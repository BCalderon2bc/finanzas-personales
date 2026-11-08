import 'package:flutter/material.dart';

import '../../data/card_statement_pdf.dart';
import '../../data/card_statement_logic.dart';
import '../../data/period_logic.dart';
import '../../utils/money.dart';
import '../../widgets/adaptive_layout.dart';
import '../person_accounts/receipt_draft_field.dart';

class CreditCardStatementForm extends StatefulWidget {
  const CreditCardStatementForm({
    super.key,
    this.statements = const [],
    this.bank = '',
    this.cardReference,
  });

  final List<Map<String, dynamic>> statements;
  final String bank;
  final String? cardReference;

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
  final notes = TextEditingController();
  final existing = <String, Map<String, dynamic>>{};
  DateTime closing = DateTime.now();
  DateTime due = DateTime.now().add(const Duration(days: 20));
  DateTime? bonus;
  String? error, pdfMessage;
  bool readingPdf = false;

  String? get pdfBank => statementPdfBankName(widget.bank);
  bool get supportsPdf => pdfBank != null;
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
    if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text) ||
        parsed == null ||
        !parsed.isFinite ||
        parsed > 999999999999.99) {
      return 'Ingresa un monto no negativo con hasta dos decimales.';
    }
    return null;
  }

  void save() {
    if (receipt.picking || readingPdf || !formKey.currentState!.validate())
      return;
    final rows = <Map<String, dynamic>>[
      for (final currency in shownCurrencies)
        if (balances[currency]!.text.trim().isNotEmpty)
          {
            'currency': currency,
            'balance': amount(balances[currency]!.text),
            'minimum': amount(minimums[currency]!.text),
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
      currency == 'NIO' ? 'Córdobas (C\$)' : 'Dólares (US\$)';

  String get balanceLabel => supportsPdf ? 'Pago de contado' : 'Saldo al corte';

  Widget amountField(
    String currency,
    Map<String, TextEditingController> controllers,
    String label, {
    bool table = false,
  }) => TextFormField(
    controller: controllers[currency],
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: table ? '$label · $currency' : label,
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
      if (!supportsPdf) ...[
        amountField(currency, balances, balanceLabel),
        const SizedBox(height: 8),
      ],
      amountField(currency, minimums, 'Pago mínimo (opcional)'),
      if (showsOverdue) ...[
        const SizedBox(height: 8),
        amountField(currency, overdues, 'Pago atrasado (opcional)'),
      ],
      if (supportsPdf) ...[
        const SizedBox(height: 8),
        amountField(currency, balances, balanceLabel),
      ],
    ],
  );

  Widget amountsLayout() => LayoutBuilder(
    builder: (context, constraints) {
      if (!supportsPdf ||
          shownCurrencies.length != 2 ||
          constraints.maxWidth < 490) {
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
                    Expanded(
                      child: amountField(
                        currency,
                        controllers,
                        label,
                        table: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );

  Future<void> readPdf() async {
    if (receipt.picking || readingPdf) return;
    final file = receipt.file;
    if (file == null) {
      setState(
        () => pdfMessage = 'Adjunta primero el PDF del estado de cuenta.',
      );
      return;
    }
    setState(() {
      readingPdf = true;
      pdfMessage = null;
    });
    try {
      final source = await file.readFirstPdfPage();
      if (!mounted) return;
      final parsed = source == null
          ? null
          : parseCardStatementPdf(widget.bank, source);
      if (parsed == null) {
        setState(
          () => pdfMessage =
              'No se reconoció el formato de $pdfBank. Puedes ingresar los montos y fechas manualmente.',
        );
        return;
      }
      final cardEnding = RegExp(
        r'\d{4}$',
      ).stringMatch(widget.cardReference?.trim() ?? '');
      if (cardEnding != null &&
          parsed.cardEnding != null &&
          cardEnding != parsed.cardEnding) {
        setState(
          () => pdfMessage =
              'La terminación del PDF no coincide con la tarjeta seleccionada.',
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Revisa los datos del PDF'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Corte · ${shortStatementDate(isoDay(parsed.closing))}'),
                  if (parsed.bonus case final bonusDate?)
                    Text(
                      'Para bonificar · ${shortStatementDate(isoDay(bonusDate))}',
                    ),
                  Text(
                    'Fecha máxima de pago · ${shortStatementDate(isoDay(parsed.due))}',
                  ),
                  for (final currency in shownCurrencies) ...[
                    const SizedBox(height: 12),
                    Text(
                      currencyLabel(currency),
                      style: Theme.of(dialog).textTheme.titleSmall,
                    ),
                    Text(
                      'Pago mínimo · ${formatMoneyCents(parsed.amounts[currency]!.minimum, currency)}',
                    ),
                    if (parsed.amounts[currency]!.overdue case final overdue?)
                      Text(
                        'Pago atrasado · ${formatMoneyCents(overdue, currency)}',
                      ),
                    Text(
                      'Pago de contado · ${formatMoneyCents(parsed.amounts[currency]!.balance, currency)}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (widget.bank == 'bac')
                    const Text(
                      'Se usa la fila «Pago de contado» del resumen. El PDF puede mostrar un saldo al corte distinto en el detalle.',
                    ),
                  if (widget.bank == 'ficohsa')
                    const Text(
                      'Se usa la fecha «Hasta» del período como fecha de corte.',
                    ),
                  const Text(
                    'Al usar estos datos puedes revisarlos o editarlos antes de guardar el corte.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Usar datos'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        for (final currency in shownCurrencies) {
          final values = parsed.amounts[currency]!;
          balances[currency]!.text = (values.balance / 100).toStringAsFixed(2);
          minimums[currency]!.text = (values.minimum / 100).toStringAsFixed(2);
          if (values.overdue case final overdue?) {
            overdues[currency]!.text = (overdue / 100).toStringAsFixed(2);
          }
        }
        closing = parsed.closing;
        bonus = parsed.bonus;
        due = parsed.due;
        error = null;
        pdfMessage =
            'Datos copiados al formulario. Revísalos antes de guardar.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => pdfMessage =
              'No se pudo leer el PDF. Puedes ingresar los datos manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => readingPdf = false);
    }
  }

  Widget attachment() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Documento del banco (opcional)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const Text('Adjunta un PDF o una foto para todo el corte. Hasta 10 MB.'),
      IgnorePointer(
        ignoring: readingPdf,
        child: ReceiptDraftField(draft: receipt),
      ),
      if (pdfBank case final bank?)
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: readingPdf ? null : readPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              readingPdf ? 'Leyendo PDF…' : 'Leer datos del PDF de $bank',
            ),
          ),
        ),
      if (pdfMessage case final message?) Text(message),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Text(
      editing ? 'Editar estado de cuenta' : 'Registrar estado de cuenta',
    ),
    content: SizedBox(
      width: 620,
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
              if (!editing && supportsPdf) ...[
                attachment(),
                const SizedBox(height: 16),
              ],
              amountsLayout(),
              const SizedBox(height: 8),
              Text(
                showsOverdue
                    ? 'Deja vacíos el mínimo y el atraso si el banco no los informa. El atraso se guarda como referencia.'
                    : 'Deja vacío el mínimo si el banco no lo informa.',
              ),
              const SizedBox(height: 16),
              dateField('Fecha de corte', closing, (value) => closing = value),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: dateField(
                      'Fecha de pago para bonificar',
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
              const SizedBox(height: 6),
              dateField('Fecha máxima de pago', due, (value) => due = value),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              if (!editing && !supportsPdf) ...[
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
      FilledButton(
        onPressed: readingPdf ? null : save,
        child: const Text('Guardar corte'),
      ),
    ],
  );
}
