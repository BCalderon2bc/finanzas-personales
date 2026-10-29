import 'dart:typed_data';
import 'package:excel/excel.dart' as x;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/money.dart';
import 'export_report_models.dart';
import 'person_account_export_report.dart';

Uint8List reportExcel(ExportReport report) {
  final excel = x.Excel.createExcel();
  excel.rename(excel.getDefaultSheet()!, 'Resumen');
  final summary = excel['Resumen'];
  final person = report is PersonAccountExportReport ? report : null;
  summary.appendRow([x.TextCellValue('Mi Billete · ${report.title}')]);
  summary.appendRow([x.TextCellValue(report.period)]);
  summary.appendRow([
    x.TextCellValue('Generado: ${report.generatedAt.toIso8601String()}'),
  ]);
  if (person != null) {
    void highlighted(String value, {int fontSize = 12, double height = 30}) {
      summary.appendRow([x.TextCellValue(value)]);
      final row = summary.maxRows - 1;
      summary.merge(
        x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        x.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      );
      summary
          .cell(x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .cellStyle = x.CellStyle(
        bold: true,
        fontSize: fontSize,
        textWrapping: x.TextWrapping.WrapText,
        fontColorHex: x.ExcelColor.fromHexString('#17493D'),
        backgroundColorHex: x.ExcelColor.fromHexString('#EAF7F0'),
      );
      summary.setRowHeight(row, height);
    }

    highlighted('QUIÉN LE DEBE A QUIÉN');
    highlighted(person.direction, fontSize: 18, height: 58);
    highlighted('Pendiente: ${person.amountLabel}', fontSize: 22, height: 38);
    highlighted('Titular: ${person.ownerName}', height: 34);
    highlighted('Cuenta con: ${person.personName}', height: 34);
    if (!person.settled) {
      highlighted('Debe pagar: ${person.debtor}', height: 34);
      highlighted('Debe recibir: ${person.creditor}', height: 34);
    }
    summary.appendRow([]);
  }
  summary.appendRow([
    x.TextCellValue('Moneda'),
    x.TextCellValue('Concepto'),
    x.TextCellValue('Monto'),
  ]);
  for (final total in report.totals) {
    summary.appendRow([
      x.TextCellValue(total.currency),
      x.TextCellValue(total.label),
      x.DoubleCellValue(total.cents / 100),
    ]);
    if (person != null) {
      final row = summary.maxRows - 1;
      summary
          .cell(x.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .cellStyle = x.CellStyle(
        textWrapping: x.TextWrapping.WrapText,
      );
      summary.setRowHeight(row, 34);
    }
    summary
        .cell(
          x.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: summary.maxRows - 1,
          ),
        )
        .cellStyle = x.CellStyle(
      numberFormat: x.NumFormat.custom(formatCode: '#,##0.00'),
    );
  }
  summary.appendRow([]);
  for (final note in report.notes) {
    summary.appendRow([x.TextCellValue(note)]);
    final row = summary.maxRows - 1;
    summary.merge(
      x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      x.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
    );
    summary
        .cell(x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = x.CellStyle(
      textWrapping: x.TextWrapping.WrapText,
      fontSize: 11,
    );
    summary.setRowHeight(row, 52);
  }
  summary.merge(
    x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    x.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0),
  );
  summary
      .cell(x.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      .cellStyle = x.CellStyle(
    bold: true,
    fontSize: 18,
  );
  for (final table in report.tables) {
    final sheet = excel[table.name];
    sheet.appendRow(table.columns.map((c) => x.TextCellValue(c)).toList());
    for (var col = 0; col < table.columns.length; col++) {
      sheet.setColumnWidth(
        col,
        table.columns[col] == 'Descripción'
            ? 45
            : table.columns[col] == 'Quién debe después'
            ? 48
            : table.columns[col] == 'Movimiento' ||
                  table.columns[col] == 'Tipo / signo'
            ? 32
            : 24,
      );
      sheet
          .cell(x.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .cellStyle = x.CellStyle(
        bold: true,
        fontColorHex: x.ExcelColor.white,
        backgroundColorHex: x.ExcelColor.fromHexString('#005544'),
      );
    }
    for (final row in table.rows) {
      sheet.appendRow(
        row
            .map<x.CellValue?>(
              (v) => switch (v) {
                MoneyCell(:final cents) => x.DoubleCellValue(cents / 100),
                int n => x.IntCellValue(n),
                double n => x.DoubleCellValue(n),
                _ => x.TextCellValue(v?.toString() ?? ''),
              },
            )
            .toList(),
      );
      if (person != null) {
        for (var col = 0; col < row.length; col++) {
          if (row[col] is! MoneyCell) {
            sheet
                .cell(
                  x.CellIndex.indexByColumnRow(
                    columnIndex: col,
                    rowIndex: sheet.maxRows - 1,
                  ),
                )
                .cellStyle = x.CellStyle(
              textWrapping: x.TextWrapping.WrapText,
            );
          }
        }
        var lines = 1;
        for (var col = 0; col < row.length; col++) {
          final capacity = table.columns[col] == 'Descripción'
              ? 42
              : table.columns[col] == 'Quién debe después'
              ? 45
              : table.columns[col] == 'Movimiento'
              ? 29
              : 21;
          final needed = reportCellText(row[col])
              .split('\n')
              .fold<int>(
                0,
                (n, line) =>
                    n +
                    ((line.runes.length + capacity - 1) ~/ capacity)
                        .clamp(1, 1000)
                        .toInt(),
              );
          if (needed > lines) lines = needed;
        }
        sheet.setRowHeight(
          sheet.maxRows - 1,
          (lines * 14.0 + 10).clamp(52, 400).toDouble(),
        );
      }
      for (var col = 0; col < row.length; col++) {
        if (row[col] is MoneyCell) {
          sheet
              .cell(
                x.CellIndex.indexByColumnRow(
                  columnIndex: col,
                  rowIndex: sheet.maxRows - 1,
                ),
              )
              .cellStyle = x.CellStyle(
            numberFormat: x.NumFormat.custom(formatCode: '#,##0.00'),
          );
        }
      }
    }
  }
  summary.setColumnWidth(0, 25);
  summary.setColumnWidth(1, 60);
  summary.setColumnWidth(2, 24);
  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('No se pudo crear el Excel.');
  }
  return Uint8List.fromList(bytes);
}

String reportCellText(Object? v) =>
    v is MoneyCell ? formatAmountCents(v.cents) : v?.toString() ?? '';
List<List<String>> _pdfRows(List<List<Object?>> rows) {
  final output = <List<String>>[];
  for (final row in rows) {
    final chunks = row.map((v) {
      final codes = reportCellText(v).runes.toList();
      if (codes.isEmpty) {
        return <String>[''];
      }
      return [
        for (var n = 0; n < codes.length; n += 220)
          String.fromCharCodes(
            codes.sublist(n, (n + 220).clamp(0, codes.length).toInt()),
          ),
      ];
    }).toList();
    final count = chunks.fold<int>(1, (n, c) => c.length > n ? c.length : n);
    for (var index = 0; index < count; index++) {
      output.add(chunks.map((c) => index < c.length ? c[index] : '').toList());
    }
  }
  return output;
}

Future<Uint8List> reportPdf(
  ExportReport report, {
  required ByteData regularFont,
  required ByteData boldFont,
  Uint8List? logo,
}) async {
  if (report.rowCount > 5000) {
    throw StateError(
      'Para PDF usa un período menor: hay más de 5,000 filas. Excel conserva el detalle completo.',
    );
  }
  final person = report is PersonAccountExportReport ? report : null;
  final pdf = pw.Document(
    title: 'Mi Billete · ${report.title}',
    author: 'Mi Billete',
  );
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(regularFont),
    bold: pw.Font.ttf(boldFont),
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.all(person == null ? 28 : 24),
      theme: theme,
      maxPages: 1000,
      header: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.SizedBox(
              width: 150,
              height: 45,
              child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
            )
          else
            pw.Text(
              'Mi Billete',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          pw.Text(
            report.title,
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(report.period, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado: ${reportDate(report.generatedAt)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Página ${c.pageNumber} de ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (c) => [
        if (person != null) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEAF7F0),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'QUIÉN LE DEBE A QUIÉN',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF17493D),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  person.direction,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  person.amountLabel,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF17493D),
                  ),
                ),
                pw.SizedBox(height: 5),
                if (person.settled)
                  pw.Text(
                    'Titular: ${person.ownerName}  |  Cuenta con: ${person.personName}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                if (!person.settled) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Debe pagar: ${person.debtor}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Debe recibir: ${person.creditor}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Resumen del período',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
        ],
        for (final total in report.totals)
          pw.Text(
            '${total.currency} · ${total.label}: ${formatMoneyCents(total.cents, total.currency)}',
            style: pw.TextStyle(fontSize: person == null ? 10 : 9),
          ),
        pw.SizedBox(height: 10),
        for (final table in report.tables) ...[
          pw.Text(
            table.name,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (table.rows.isEmpty)
            pw.Text('Sin registros.', style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headers: table.columns,
              data: _pdfRows(table.rows),
              columnWidths: {
                for (var n = 0; n < table.columns.length; n++)
                  n: pw.FlexColumnWidth(
                    person != null
                        ? switch (table.columns[n]) {
                            'Fecha' => 1.5,
                            'Movimiento' => 2.7,
                            'Descripción' => 3.2,
                            'Moneda' => 1.1,
                            'Importe original' => 1.5,
                            'Tasa C\$/US\$' => 1.4,
                            'Variación C\$' => 1.5,
                            'Saldo C\$' => 1.4,
                            'Quién debe después' => 3.0,
                            _ => 1.6,
                          }
                        : table.columns[n] == 'Descripción'
                        ? 3.2
                        : table.columns[n] == 'Moneda'
                        ? 0.75
                        : table.columns[n] == 'Fecha'
                        ? 1.1
                        : 1.6,
                  ),
              },
              cellAlignments: {
                for (var n = 0; n < table.columns.length; n++)
                  if (table.rows.any((r) => r[n] is MoneyCell))
                    n: pw.Alignment.centerRight,
              },
              headerStyle: pw.TextStyle(
                fontSize: person == null ? 8 : 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF005544),
              ),
              cellStyle: pw.TextStyle(fontSize: person == null ? 8 : 7.5),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
            ),
          pw.SizedBox(height: 12),
        ],
        for (final note in report.notes.skip(person == null ? 0 : 2))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              note,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
      ],
    ),
  );
  return pdf.save();
}
