import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' show CellIndex, Excel;
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

class OfficeReceiptPreview extends StatefulWidget {
  const OfficeReceiptPreview({
    super.key,
    required this.bytes,
    required this.extension,
  });

  final Uint8List bytes;
  final String extension;

  @override
  State<OfficeReceiptPreview> createState() => _OfficeReceiptPreviewState();
}

class _OfficeReceiptPreviewState extends State<OfficeReceiptPreview> {
  static const _maxRows = 200;
  static const _maxColumns = 30;
  String? _word;
  Excel? _excel;
  String? _sheet;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes);
      final totalSize = archive.files.fold<int>(
        0,
            (size, file) => size + file.size,
      );
      if (totalSize > 32 * 1024 * 1024 || archive.files.length > 1000) {
        throw const FormatException('Documento demasiado grande.');
      }
      if (widget.extension == 'docx') {
        final file = archive.findFile('word/document.xml');
        if (file == null) throw const FormatException('Documento inválido.');
        final document = XmlDocument.parse(
          utf8.decode(file.content as List<int>),
        );
        String paragraphText(XmlElement paragraph) => paragraph.descendants
            .whereType<XmlElement>()
            .where(
              (element) =>
              const {'t', 'tab', 'br'}.contains(element.name.local),
        )
            .map(
              (element) => switch (element.name.local) {
            'tab' => '\t',
            'br' => '\n',
            _ => element.innerText,
          },
        )
            .join();

        final body = document.rootElement.childElements.firstWhere(
              (element) => element.name.local == 'body',
        );
        final lines = <String>[];
        for (final block in body.childElements) {
          if (block.name.local == 'p') {
            lines.add(paragraphText(block));
          } else if (block.name.local == 'tbl') {
            for (final row in block.childElements.where(
                  (element) => element.name.local == 'tr',
            )) {
              lines.add(
                row.childElements
                    .where((element) => element.name.local == 'tc')
                    .map(
                      (cell) => cell.childElements
                      .where((element) => element.name.local == 'p')
                      .map(paragraphText)
                      .join(' '),
                )
                    .join('  │  '),
              );
            }
          }
        }
        final text = lines.join('\n');
        _word = text.length <= 100000
            ? text
            : '${text.substring(0, 100000)}\n\n[Vista previa recortada]';
      } else {
        _excel = Excel.decodeBytes(widget.bytes);
        _sheet = _excel!.tables.keys.firstOrNull;
      }
    } catch (_) {
      _error = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Text(
          'No se pudo mostrar este documento. Puedes descargar el original.',
        ),
      );
    }
    if (_word case final word?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vista rápida del texto. El original conserva el diseño y las imágenes.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                word.trim().isEmpty ? 'No hay texto para mostrar.' : word,
              ),
            ),
          ),
        ],
      );
    }

    final tables = _excel!.tables;
    final sheet = tables[_sheet];
    if (sheet == null)
      return const Center(child: Text('No hay hojas para mostrar.'));
    final rowCount = sheet.maxRows.clamp(0, _maxRows).toInt();
    final columns = sheet.maxColumns.clamp(0, _maxColumns).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          value: _sheet,
          items: [
            for (final name in tables.keys)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _sheet = value),
        ),
        const Text(
          'Vista rápida de celdas. Las fórmulas se muestran sin calcular.',
        ),
        if (sheet.maxRows > rowCount || sheet.maxColumns > columns)
          Text(
            'Se muestran hasta $_maxRows filas y $_maxColumns columnas por hoja.',
          ),
        const SizedBox(height: 8),
        Expanded(
          child: rowCount == 0 || columns == 0
              ? const Center(child: Text('La hoja está vacía.'))
              : SingleChildScrollView(
            key: ValueKey(_sheet),
            primary: false,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: columns * 130.0 + 48,
              child: ListView.builder(
                primary: false,
                itemCount: rowCount,
                itemBuilder: (context, row) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${row + 1}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    for (var column = 0; column < columns; column++)
                      Container(
                        width: 130,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: SelectableText(
                          sheet
                              .cell(
                            CellIndex.indexByColumnRow(
                              columnIndex: column,
                              rowIndex: row,
                            ),
                          )
                              .value
                              ?.toString() ??
                              '',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
