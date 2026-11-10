import '../../widgets/page_intro.dart';
import '../../widgets/adaptive_layout.dart';
import '../../data/exchange_rate.dart';
import '../../data/financial_settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import '../../services/report_share.dart';
import '../help/app_help.dart';
import '../person_accounts/person_receipts_dialog.dart' show showFilePreview;
import '../../data/export_report_models.dart';
import '../../data/export_report_repository.dart';
import '../../data/credit_card_additional_repository.dart';
import '../../data/card_statement_repository.dart' show statementRows;
import '../../data/payment_agenda_labels.dart'
    show additionalCardLabel, agendaCardLabel, reportDebitCardLabel;
import '../../data/export_report_writer.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/person_account_repository.dart';
import '../../data/person_account_report_repository.dart';
import '../../data/person_account_export_report.dart';

class ExportReportsPage extends StatefulWidget {
  const ExportReportsPage({super.key, this.initialPersonId});
  final String? initialPersonId;
  @override
  State<ExportReportsPage> createState() => _ExportReportsPageState();
}

class _ExportReportsPageState extends State<ExportReportsPage> {
  String kind = 'movements', currency = 'all';
  bool busy = false, loadingPeople = true, allHistory = true;
  String? personId, peopleError, cardId, accountId, additionalCardFilter;
  Future<List<Map<String, dynamic>>>? additionalCards;
  List<Map<String, dynamic>> creditCards = [],
      debitCards = [],
      bankAccounts = [];
  final reportOwner = TextEditingController();
  final settlementRate = TextEditingController();

  @override
  void dispose() {
    reportOwner.dispose();
    settlementRate.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> people = [];
  @override
  void initState() {
    super.initState();
    personId = widget.initialPersonId;
    if (personId != null) kind = 'person';
    loadPeople();
  }

  String accountBankLabel(Map account) {
    final institution = account['financial_institutions'];
    final bank = institution is Map
        ? institution['name']?.toString().trim() ?? ''
        : '';
    if (bank.isNotEmpty) return bank;
    return account['account_type'] == 'cash' ? 'Efectivo' : 'Banco sin asignar';
  }

  Future<List<Map<String, dynamic>>> loadReportAdditionals(
    String cardId,
  ) async {
    return loadAdditionalCards(cardId, personUserId());
  }

  Widget additionalCardSelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(cardId),
      future: additionalCards,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(
            semanticsLabel: 'Cargando tarjetas adicionales',
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'No se pudieron cargar las tarjetas adicionales.',
            ),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      additionalCards = loadReportAdditionals(cardId!);
                    }),
              child: const Text('Reintentar'),
            ),
          );
        }
        final cards = snapshot.data ?? const [];
        return DropdownButtonFormField<String>(
          initialValue: additionalCardFilter ?? 'all',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tarjeta del movimiento',
          ),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('Titular y adicionales'),
            ),
            const DropdownMenuItem(value: '', child: Text('Solo titular')),
            for (final card in cards)
              DropdownMenuItem(
                value: '${card['id']}',
                child: Text(
                  'Adicional · ${additionalCardLabel(card)}'
                  '${card['is_active'] == true ? '' : ' · Inactiva'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() {
                  additionalCardFilter = value == 'all' ? null : value;
                  clear();
                }),
        );
      },
    );
  }

  Future<void> loadPeople() async {
    setState(() {
      loadingPeople = true;
      peopleError = null;
    });
    try {
      final uid = personUserId();
      final rows = await personRows('person_accounts', uid);
      final accountRows = await statementRows(
        'accounts',
        'id,name,currency,account_type,financial_institutions(name)',
        uid,
      );
      final cardRows = await supabase
          .from('credit_cards')
          .select('id,name,card_reference,financial_institutions(name)')
          .eq('user_id', uid)
          .order('name');
      final debitRows = await supabase
          .from('debit_cards')
          .select(
            'id,name,network,card_reference,financial_institutions(name),accounts(name,financial_institutions(name))',
          )
          .eq('user_id', uid)
          .order('id');
      String? profileName;
      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', uid)
            .maybeSingle();
        profileName = profile?['full_name']?.toString();
      } catch (_) {
        /* El nombre puede indicarse manualmente para este reporte. */
      }

      String? suggestedPaymentRate;
      try {
        suggestedPaymentRate = (await loadFinancialSettings())?.rate.decimal;
      } catch (_) {
        /* Se puede indicar la tasa manualmente. */
      }
      rows.sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );
      checkPersonSession(uid);
      if (!mounted) return;
      setState(() {
        if (reportOwner.text.trim().isEmpty)
          reportOwner.text = profileName?.trim() ?? '';
        if (settlementRate.text.trim().isEmpty && suggestedPaymentRate != null)
          settlementRate.text = suggestedPaymentRate;
        people = rows;
        bankAccounts = accountRows;
        creditCards = List<Map<String, dynamic>>.from(cardRows);
        debitCards = List<Map<String, dynamic>>.from(debitRows);
        loadingPeople = false;
        if (!rows.any((p) => '${p['id']}' == personId)) personId = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          peopleError = '$e';
          loadingPeople = false;
        });
    }
  }

  DateTime start = DateTime(DateTime.now().year, DateTime.now().month),
      end = DateTime.now(),
      month = DateTime(DateTime.now().year, DateTime.now().month);
  ExportReport? report;
  Uint8List? excel, pdf;
  String? error, pdfNotice, preparedUser;
  void clear() {
    report = null;
    excel = null;
    pdf = null;
    error = null;
    pdfNotice = null;
    preparedUser = null;
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> prepare() async {
    if (busy) {
      return;
    }
    setState(() {
      clear();
      busy = true;
    });
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        throw StateError('Debes iniciar sesión.');
      }
      if (kind == 'person' && reportOwner.text.trim().isEmpty)
        throw StateError(
          'Escribe tu nombre para identificar quién debe a quién.',
        );
      if (kind == 'person' && personId == null)
        throw StateError('Selecciona una persona.');
      final paymentRate = kind == 'person'
          ? ExchangeRate.tryParse(settlementRate.text)
          : null;
      if (kind == 'person' && paymentRate == null)
        throw StateError(
          'Indica una tasa de pago positiva en córdobas por dólar, con máximo seis decimales.',
        );
      final result = kind == 'person'
          ? await loadPersonAccountReport(
              personId!,
              ownerName: reportOwner.text.trim(),
              settlementRate: paymentRate,
              start: allHistory ? null : start,
              end: allHistory ? null : end,
            )
          : await loadExportReport(
              kind: kind,
              cardId: cardId,
              additionalCardFilter: additionalCardFilter,
              accountId: accountId,
              currency: currency,
              start: start,
              end: end,
              month: month,
            );
      final xlsx = reportExcel(result);
      Uint8List? pdfData;
      String? note;
      try {
        final regularFont = await rootBundle.load(
          'assets/fonts/DejaVuSans.ttf',
        );
        final boldFont = await rootBundle.load(
          'assets/fonts/DejaVuSans-Bold.ttf',
        );
        Uint8List? logo;
        try {
          logo = (await rootBundle.load(
            'assets/branding/mi_billete_logo.png',
          )).buffer.asUint8List();
        } catch (_) {
          /* El título de texto funciona sin logo. */
        }
        pdfData = await reportPdf(
          result,
          regularFont: regularFont,
          boldFont: boldFont,
          logo: logo,
        );
      } catch (e) {
        note = 'Excel disponible. No se pudo preparar el PDF: $e';
      }
      if (supabase.auth.currentUser?.id != uid) {
        throw StateError('La sesión cambió.');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        report = result;
        excel = xlsx;
        pdf = pdfData;
        pdfNotice = note;
        preparedUser = uid;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  String exportName() {
    final date = report!.generatedAt;
    final selectedName =
        people
            .where((p) => '${p['id']}' == personId)
            .map((p) => '${p['name']}')
            .firstOrNull ??
        'Persona';
    final suffix = kind == 'person'
        ? '_${selectedName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}'
        : '';
    return 'MiBillete_${kind}${suffix}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> preview(bool asPdf) async {
    final bytes = asPdf ? pdf : excel;
    if (bytes == null || busy || report == null) return;
    if (supabase.auth.currentUser?.id != preparedUser) {
      setState(clear);
      message('La sesión cambió. Prepara el reporte nuevamente.');
      return;
    }
    final extension = asPdf ? 'pdf' : 'xlsx';
    final filename = '${exportName()}.$extension';
    await showFilePreview(
      context,
      label: filename,
      sourceName: filename,
      load: () async => bytes,
      expanded: true,
    );
  }

  Future<void> save(bool asPdf) async {
    final bytes = asPdf ? pdf : excel;
    if (bytes == null || busy) {
      return;
    }
    if (supabase.auth.currentUser?.id != preparedUser) {
      setState(clear);
      message('La sesión cambió. Prepara el reporte nuevamente.');
      return;
    }
    setState(() => busy = true);
    try {
      final name = exportName();
      final mime = asPdf ? MimeType.pdf : MimeType.microsoftExcel;
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
        final path = await FileSaver.instance.saveFile(
          name: name,
          bytes: bytes,
          fileExtension: asPdf ? 'pdf' : 'xlsx',
          mimeType: mime,
        );
        if (path.isEmpty || path.startsWith('Something went wrong')) {
          throw StateError('El sistema no pudo guardar el archivo.');
        }
        message(
          kIsWeb
              ? 'Archivo preparado para descargar.'
              : 'Archivo guardado en: $path',
        );
      } else {
        final path = await FileSaver.instance.saveAs(
          name: name,
          bytes: bytes,
          fileExtension: asPdf ? 'pdf' : 'xlsx',
          mimeType: mime,
        );
        if (path != null && path.isNotEmpty) {
          if (path.startsWith('Something went wrong')) {
            throw StateError('El sistema no pudo guardar el archivo.');
          }
          message('Archivo guardado.');
        }
      }
    } catch (e) {
      message('No se pudo descargar o guardar: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> shareFile(bool asPdf, BuildContext buttonContext) async {
    final bytes = asPdf ? pdf : excel;
    if (bytes == null || busy || report == null) return;
    if (supabase.auth.currentUser?.id != preparedUser) {
      setState(clear);
      message('La sesión cambió. Prepara el reporte nuevamente.');
      return;
    }
    final box = buttonContext.findRenderObject();
    final size = MediaQuery.sizeOf(context);
    final origin = box is RenderBox && box.hasSize && !box.size.isEmpty
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
    final extension = asPdf ? 'pdf' : 'xlsx';
    final filename = '${exportName()}.$extension';
    final mime = asPdf
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    setState(() => busy = true);
    try {
      // Los bytes ya se prepararon al generar el reporte. La llamada nace del
      // botón de compartir, sin otra consulta ni diálogo que pierda el gesto web.
      final available = await shareReportFile(
        bytes,
        filename,
        mime,
        report!.title,
        origin,
      );
      if (!available) {
        message(
          'Este navegador no permite compartir este archivo. Abre la app en Safari con HTTPS o usa Descargar.',
        );
      }
      // Cerrar el menú sin elegir destino no descarga ni envía el archivo.
    } catch (_) {
      message(
        'No se pudo abrir Compartir. Usa Descargar y comparte el archivo desde Archivos o Descargas.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget fileActions(bool asPdf) {
    final available = (asPdf ? pdf : excel) != null;
    final label = asPdf ? 'PDF' : 'Excel (.xlsx)';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  asPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.table_chart_outlined,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || !available ? null : () => preview(asPdf),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Vista previa'),
                ),
                FilledButton.icon(
                  onPressed: busy || !available ? null : () => save(asPdf),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descargar'),
                ),
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    onPressed: busy || !available
                        ? null
                        : () => shareFile(asPdf, buttonContext),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
            if (!available)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Este formato no está disponible. Revisa el aviso o vuelve a preparar el reporte.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GuideScope(
    topic: 'reports',
    ready: !busy && !loadingPeople,
    excludedTargets: {
      if (kind == 'person') 'currency' else ...['person', 'rate'],
      if (report == null) 'files',
    },
    child: Scaffold(
      appBar: AppBar(
        title: GuideAnchor(id: 'title', child: const Text('Exportar reportes')),
        actions: const [AppHelpButton(topic: 'reports')],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: EdgeInsets.all(pageGutter(context)),
              children: [
                const PageIntro(
                  icon: Icons.file_download_outlined,
                  title: 'Prepara tu reporte',
                  description:
                      'Elige los datos que quieres descargar o compartir en PDF o Excel. Los importes conservan su moneda original.',
                ),
                GuideAnchor(
                  id: 'kind',
                  child: DropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Reporte'),
                    items: const [
                      DropdownMenuItem(
                        value: 'person',
                        child: Text('Cuenta con una persona'),
                      ),
                      DropdownMenuItem(
                        value: 'movements',
                        child: Text(
                          'Movimientos · ingresos y gastos',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'accounts',
                        child: Text('Cuentas y efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'credit_card_expenses',
                        child: Text('Gastos de tarjetas de crédito'),
                      ),
                      DropdownMenuItem(
                        value: 'credit_cards',
                        child: Text(
                          'Tarjetas de crédito · movimientos y totales',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'debit_cards',
                        child: Text(
                          'Tarjetas de débito · cuenta vinculada',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'debts',
                        child: Text('Deudas y cuotas actuales'),
                      ),
                      DropdownMenuItem(
                        value: 'budgets',
                        child: Text('Presupuestos del mes'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() {
                                kind = v;
                                cardId = null;
                                additionalCardFilter = null;
                                additionalCards = null;
                                accountId = null;
                                if (v == 'movements') {
                                  final today = DateUtils.dateOnly(
                                    DateTime.now(),
                                  );
                                  if (end.isAfter(today)) end = today;
                                  if (start.isAfter(end))
                                    start = DateTime(end.year, end.month);
                                }
                                clear();
                              });
                            }
                          },
                  ),
                ),
                const SizedBox(height: 14),
                if (kind != 'person')
                  GuideAnchor(
                    id: 'currency',
                    child: DropdownButtonFormField<String>(
                      initialValue: currency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Ambas, con totales separados'),
                        ),
                        DropdownMenuItem(
                          value: 'NIO',
                          child: Text('Córdobas · NIO'),
                        ),
                        DropdownMenuItem(
                          value: 'USD',
                          child: Text('Dólares · USD'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() {
                                  currency = v;
                                  clear();
                                });
                              }
                            },
                    ),
                  ),
                const SizedBox(height: 14),
                if (kind == 'credit_cards' ||
                    kind == 'credit_card_expenses' ||
                    kind == 'debit_cards') ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('report-card-$kind-$cardId'),
                    initialValue: cardId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tarjeta'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todas')),
                      ...((kind == 'credit_cards' ||
                                  kind == 'credit_card_expenses')
                              ? creditCards
                              : debitCards)
                          .map(
                            (card) => DropdownMenuItem(
                              value: '${card['id']}',
                              child: Text(
                                (kind == 'credit_cards' ||
                                        kind == 'credit_card_expenses')
                                    ? agendaCardLabel(card)
                                    : reportDebitCardLabel(
                                        card,
                                        account: card['accounts'] as Map?,
                                      ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            cardId = v == '' ? null : v;
                            additionalCardFilter = null;
                            additionalCards =
                                kind == 'credit_card_expenses' && cardId != null
                                ? loadReportAdditionals(cardId!)
                                : null;
                            clear();
                          }),
                  ),
                  const SizedBox(height: 12),
                  if (kind == 'credit_card_expenses' && cardId != null) ...[
                    additionalCardSelector(),
                    const SizedBox(height: 12),
                  ],
                  if (kind == 'debit_cards')
                    const Text(
                      'Se muestran todos los movimientos de la cuenta vinculada; una cuenta con varias tarjetas se suma una sola vez.',
                    ),
                ],
                if (kind == 'accounts') ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('report-account-$accountId'),
                    initialValue: accountId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Cuenta'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todas las cuentas'),
                      ),
                      ...bankAccounts.map(
                        (a) => DropdownMenuItem(
                          value: '${a['id']}',
                          child: Text(
                            '${accountBankLabel(a)} · ${a['name']} · ${a['currency']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            accountId = value == '' ? null : value;
                            clear();
                          }),
                  ),
                  const SizedBox(height: 12),
                ],
                if (kind == 'person') ...[
                  GuideAnchor(
                    id: 'rate',
                    child: TextField(
                      controller: settlementRate,
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tasa para pagar: C\$ por US\$ 1',
                        helperText:
                            'Revisa la tasa acordada. Se usa para mostrar cómo pagar el saldo completo en dólares. No cambia las tasas del historial.',
                        helperMaxLines: 3,
                      ),
                      onChanged: (_) => setState(clear),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: reportOwner,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre en el reporte',
                      helperText:
                          'Se usa para indicar quién debe pagar y quién debe recibir. No modifica tu perfil.',
                      helperMaxLines: 3,
                    ),
                    onChanged: (_) => setState(clear),
                  ),
                  const SizedBox(height: 10),

                  if (loadingPeople)
                    const LinearProgressIndicator()
                  else if (peopleError != null) ...[
                    Text('No se pudieron cargar las personas: $peopleError'),
                    TextButton(
                      onPressed: busy ? null : loadPeople,
                      child: const Text('Reintentar'),
                    ),
                  ] else if (people.isEmpty)
                    const Text(
                      'Primero agrega una persona en Cuentas con personas.',
                    )
                  else
                    GuideAnchor(
                      id: 'person',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('person-$personId'),
                        initialValue: personId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Persona'),
                        items: people
                            .map(
                              (p) => DropdownMenuItem(
                                value: '${p['id']}',
                                child: Text(
                                  '${p['name']}${p['is_active'] == true ? '' : ' · Archivada'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                personId = v;
                                clear();
                              }),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Todo el historial'),
                    value: allHistory,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            allHistory = v;
                            clear();
                          }),
                  ),
                  const Text(
                    'Incluye ambas monedas con su tasa registrada. El saldo se presenta en córdobas; los anulados se excluyen.',
                  ),
                  const SizedBox(height: 10),
                ],
                if (kind == 'movements' ||
                    kind == 'credit_cards' ||
                    kind == 'credit_card_expenses' ||
                    kind == 'accounts' ||
                    kind == 'debit_cards' ||
                    kind == 'person' && !allHistory)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text('${reportDate(start)} – ${reportDate(end)}'),
                    onPressed: busy
                        ? null
                        : () async {
                            final value = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: kind == 'person'
                                  ? DateTime(2100)
                                  : DateTime.now(),
                              initialDateRange: DateTimeRange(
                                start: start,
                                end: end,
                              ),
                            );
                            if (value != null && mounted) {
                              setState(() {
                                start = value.start;
                                end = value.end;
                                clear();
                              });
                            }
                          },
                  ),
                if (kind == 'budgets')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${month.month.toString().padLeft(2, '0')}/${month.year}',
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: month,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (value != null && mounted) {
                              setState(() {
                                month = DateTime(value.year, value.month);
                                clear();
                              });
                            }
                          },
                  ),
                if (kind == 'debts')
                  const Text(
                    'Deudas y cuotas se exportan con sus saldos actuales, no como un saldo histórico del mes.',
                  ),
                const SizedBox(height: 18),
                GuideAnchor(
                  id: 'prepare',
                  child: FilledButton.icon(
                    onPressed:
                        busy ||
                            (kind == 'person' &&
                                (loadingPeople ||
                                    peopleError != null ||
                                    personId == null))
                        ? null
                        : prepare,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(busy ? 'Procesando...' : 'Preparar reportes'),
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(error!),
                  ),
                if (report != null) ...[
                  const SizedBox(height: 18),
                  if (report
                      case final PersonAccountExportReport personReport) ...[
                    Card(
                      color: personReport.settled
                          ? const Color(0xFFEDF3F9)
                          : const Color(0xFFEFF6FF),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'QUIÉN LE DEBE A QUIÉN',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              personReport.direction,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              personReport.paymentNioLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            Text(
                              personReport.paymentUsdLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            Text(personReport.paymentRateLabel),
                            const Text(
                              'Son alternativas para la misma deuda; no se suman.',
                            ),
                            Text(
                              'Titular: ${personReport.ownerName}\nCuenta con: ${personReport.personName}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${report!.title} · ${report!.rowCount} registros',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(report!.period),
                          if (report!.scopeLabel case final scope?) Text(scope),
                          const Divider(height: 24),
                          ...report!.totals.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${t.currency} · ${t.label}: ${formatMoneyCents(t.cents, t.currency)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GuideAnchor(
                    id: 'files',
                    child: AdaptiveColumns(
                      minColumnWidth: 370,
                      children: [fileActions(false), fileActions(true)],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'En la web, el navegador gestiona la descarga. Compartir muestra los destinos disponibles en tu dispositivo.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF596B7D)),
                    ),
                  ),
                  if (pdfNotice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(pdfNotice!),
                    ),
                  const SizedBox(height: 12),
                  ...report!.notes.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        n,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF596B7D),
                        ),
                      ),
                    ),
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
