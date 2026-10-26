import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import '../../data/export_report_models.dart';
import '../../data/export_report_repository.dart';
import '../../data/export_report_writer.dart';
import '../../core/supabase_client.dart';
import '../../utils/money.dart';
import '../../data/person_account_repository.dart';
import '../../data/person_account_report_repository.dart';

class ExportReportsPage extends StatefulWidget {
  const ExportReportsPage({super.key, this.initialPersonId});
  final String? initialPersonId;
  @override
  State<ExportReportsPage> createState() => _ExportReportsPageState();
}

class _ExportReportsPageState extends State<ExportReportsPage> {
  String kind = 'movements', currency = 'all';
  bool busy = false, loadingPeople = true, allHistory = true;
  String? personId, peopleError;
  List<Map<String, dynamic>> people = [];
  @override
  void initState() {
    super.initState();
    personId = widget.initialPersonId;
    if (personId != null) kind = 'person';
    loadPeople();
  }

  Future<void> loadPeople() async {
    setState(() {
      loadingPeople = true;
      peopleError = null;
    });
    try {
      final uid = personUserId();
      final rows = await personRows('person_accounts', uid);
      rows.sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );
      checkPersonSession(uid);
      if (!mounted) return;
      setState(() {
        people = rows;
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
      if (kind == 'person' && personId == null)
        throw StateError('Selecciona una persona.');
      final result = kind == 'person'
          ? await loadPersonAccountReport(
              personId!,
              start: allHistory ? null : start,
              end: allHistory ? null : end,
            )
          : await loadExportReport(
              kind: kind,
              currency: currency,
              start: start,
              end: end,
              month: month,
            );
      final xlsx = reportExcel(result);
      Uint8List? pdfData;
      String? note;
      try {
        final fonts = await Future.wait([
          rootBundle.load('assets/fonts/DejaVuSans.ttf'),
          rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
        ]);
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
          regularFont: fonts[0],
          boldFont: fonts[1],
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
      final name =
          'MiBillete_${kind}${suffix}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
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
        if (path != null) {
          message('Archivo guardado.');
        }
      }
    } catch (e) {
      message('No se pudo guardar: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exportar reportes')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Mi Billete',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prepara el archivo y después elige dónde guardarlo. Los importes conservan su moneda original.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
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
                    child: Text('Movimientos · ingresos y gastos'),
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
                            if (v == 'movements') {
                              final today = DateUtils.dateOnly(DateTime.now());
                              if (end.isAfter(today)) end = today;
                              if (start.isAfter(end))
                                start = DateTime(end.year, end.month);
                            }
                            clear();
                          });
                        }
                      },
              ),
              const SizedBox(height: 14),
              if (kind != 'person')
                DropdownButtonFormField<String>(
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
              const SizedBox(height: 14),
              if (kind == 'person') ...[
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
                  DropdownButtonFormField<String>(
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
              if (kind == 'movements' || kind == 'person' && !allHistory)
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
              FilledButton.icon(
                onPressed:
                    busy ||
                        (kind == 'person' &&
                            (loadingPeople ||
                                peopleError != null ||
                                personId == null))
                    ? null
                    : prepare,
                icon: const Icon(Icons.description_outlined),
                label: Text(busy ? 'Preparando...' : 'Preparar reportes'),
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
                OutlinedButton.icon(
                  onPressed: busy || excel == null ? null : () => save(false),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Guardar Excel (.xlsx)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy || pdf == null ? null : () => save(true),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Guardar PDF'),
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
                        color: Color(0xFF64748B),
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
  );
}
