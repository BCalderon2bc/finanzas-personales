import 'office_receipt_preview.dart';
import 'dart:convert';
import 'dart:math';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';
import '../../widgets/adaptive_layout.dart';
import 'receipt_file_picker.dart'
    if (dart.library.js_interop) 'receipt_file_picker_web.dart';

const _types = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'txt': 'text/plain',
};

Future<bool?> showFilePreview(
  BuildContext context, {
  required String label,
  required String sourceName,
  required Future<Uint8List> Function() load,
  bool allowDownload = false,
  bool expanded = false,
}) {
  final extension = label.split('.').last.toLowerCase();
  final mimeType = _types[extension];
  final isImage = mimeType?.startsWith('image/') ?? false;
  final isPdf = extension == 'pdf';
  final isText = extension == 'txt';
  final isOffice = extension == 'docx' || extension == 'xlsx';
  final supported = isImage || isPdf || isText || isOffice;
  final bytes = supported ? load() : null;

  return showDialog<bool>(
    context: context,
    builder: (context) {
      final preview = supported
          ? FutureBuilder<Uint8List>(
              future: bytes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudo cargar el archivo.'),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (isOffice) {
                  return OfficeReceiptPreview(
                    bytes: data,
                    extension: extension,
                  );
                }
                if (isPdf) {
                  return _PdfFilePreview(
                    bytes: data,
                    sourceName: sourceName,
                    showControls: expanded,
                  );
                }
                if (isText) {
                  return SingleChildScrollView(
                    child: SelectableText(
                      utf8.decode(data, allowMalformed: true),
                    ),
                  );
                }
                return InteractiveViewer(
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: Image.memory(
                      data,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text(
                          'Este dispositivo no puede mostrar la imagen.',
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          : Text(
              allowDownload
                  ? 'Este formato solo está disponible para descarga.'
                  : 'Este formato no tiene vista previa. Puedes adjuntarlo al guardar.',
            );
      final actions = [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        if (allowDownload)
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar'),
          ),
      ];
      if (!expanded) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 760,
            height: supported ? MediaQuery.sizeOf(context).height * .65 : null,
            child: preview,
          ),
          actions: actions,
        );
      }

      final size = MediaQuery.sizeOf(context);
      final content = Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (allowDownload) actions.last,
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: preview),
        ],
      );
      final compact = size.width < 600 || size.height < 480;
      return Dialog(
        insetPadding: compact ? EdgeInsets.zero : const EdgeInsets.all(20),
        constraints: const BoxConstraints(),
        shape: compact ? const RoundedRectangleBorder() : null,
        clipBehavior: Clip.antiAlias,
        child: SizedBox.expand(child: content),
      );
    },
  );
}

class _PdfFilePreview extends StatefulWidget {
  const _PdfFilePreview({
    required this.bytes,
    required this.sourceName,
    required this.showControls,
  });

  final Uint8List bytes;
  final String sourceName;
  final bool showControls;

  @override
  State<_PdfFilePreview> createState() => _PdfFilePreviewState();
}

class _PdfFilePreviewState extends State<_PdfFilePreview> {
  final _controller = PdfViewerController();
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final viewer = PdfViewer.data(
      widget.bytes,
      sourceName: widget.sourceName,
      controller: widget.showControls ? _controller : null,
      params: PdfViewerParams(
        errorBannerBuilder: (_, _, _, _) =>
            const Center(child: Text('No se pudo mostrar el PDF.')),
        calculateInitialZoom: widget.showControls
            ? (_, controller, _, _) =>
                  (controller.viewSize.width - controller.params.margin * 2) /
                  controller.layout.pageLayouts.first.width
            : null,
        onViewerReady: widget.showControls
            ? (_, _) {
                if (mounted) setState(() => _ready = true);
              }
            : null,
      ),
    );
    if (!widget.showControls) return viewer;

    final canZoom = _ready && _controller.isReady;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Alejar',
              onPressed: canZoom ? () => _controller.zoomDown() : null,
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Ajustar al ancho',
              onPressed: canZoom
                  ? () => _controller.goTo(
                      _controller.calcMatrixFitWidthForPage(
                        pageNumber: _controller.pageNumber ?? 1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.fit_screen_outlined),
            ),
            IconButton(
              tooltip: 'Acercar',
              onPressed: canZoom ? () => _controller.zoomUp() : null,
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
        Expanded(child: viewer),
      ],
    );
  }
}

/// A validated selection held locally until its movement has been saved.
class PendingReceipt {
  const PendingReceipt._(this.label, this._name, this._type, this._bytes);

  final String label, _name, _type;
  final Uint8List _bytes;

  static Future<PendingReceipt?> pick() async {
    final file = await pickReceiptFile();
    if (file == null) return null;
    final dot = file.name.lastIndexOf('.');
    final extension = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    final type = _types[extension];
    if (type == null) {
      throw const FormatException('Usa una imagen, PDF, Word, Excel o TXT.');
    }
    final size = await file.length();
    if (size <= 0 || size > 10 * 1024 * 1024) {
      throw const FormatException(
        'El comprobante debe pesar entre 1 byte y 10 MB.',
      );
    }
    var base = file.name
        .substring(0, dot)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    if (base.length > 80) base = base.substring(0, 80);
    if (base.isEmpty) base = 'comprobante';
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException(
        'El comprobante debe pesar entre 1 byte y 10 MB.',
      );
    }
    return PendingReceipt._(file.name, '${id}_$base.$extension', type, bytes);
  }

  Future<String?> readFirstPdfPage() async {
    if (_type != 'application/pdf') return null;
    final document = await PdfDocument.openData(_bytes, sourceName: _name);
    try {
      if (document.pages.isEmpty) return null;
      return (await document.pages.first.loadText()).fullText;
    } finally {
      await document.dispose();
    }
  }

  Future<void> preview(BuildContext context) async {
    await showFilePreview(
      context,
      label: label,
      sourceName: _name,
      load: () async => _bytes,
    );
  }

  Future<void> upload(StorageFileApi bucket, String folder, String uid) async {
    checkPersonSession(uid);
    await bucket.uploadBinary(
      '$folder/$_name',
      _bytes,
      fileOptions: FileOptions(contentType: _type, upsert: false),
    );
  }
}

class PersonReceiptsDialog extends StatefulWidget {
  const PersonReceiptsDialog({
    super.key,
    required this.accountId,
    required this.entryId,
    required this.canAdd,
    required this.canRemove,
  }) : movementTable = null,
       statementDocuments = const {};

  const PersonReceiptsDialog.movement({
    super.key,
    required String table,
    required this.entryId,
    required bool writable,
  }) : movementTable = table,
       statementDocuments = const {},
       accountId = '',
       canAdd = writable,
       canRemove = writable;

  const PersonReceiptsDialog.statement({
    super.key,
    required this.entryId,
    required this.statementDocuments,
  }) : accountId = '',
       movementTable = 'credit_card_statements',
       canAdd = false,
       canRemove = false;

  /// Document IDs and their write permissions, including older per-currency IDs.
  final Map<String, bool> statementDocuments;
  final String accountId, entryId;
  final String? movementTable;
  final bool canAdd, canRemove;

  @override
  State<PersonReceiptsDialog> createState() => _PersonReceiptsDialogState();
}

class _PersonReceiptsDialogState extends State<PersonReceiptsDialog> {
  late final String _uid;
  final _files = <({String folder, String name, bool writable})>[];
  bool _loaded = false;
  bool _busy = false;
  String? _notice;

  bool get _isStatement => widget.statementDocuments.isNotEmpty;
  bool get _canAdd => _isStatement
      ? _loaded &&
            _files.isEmpty &&
            widget.statementDocuments[widget.entryId] == true
      : widget.canAdd;
  String get _folder =>
      '${widget.movementTable ?? widget.accountId}/${widget.entryId}';
  StorageFileApi get _bucket => supabase.storage.from(
    widget.movementTable == null ? 'person-receipts' : 'movement-receipts',
  );

  @override
  void initState() {
    super.initState();
    _uid = personUserId();
    _run(_load);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      checkPersonSession(_uid);
      await action();
    } catch (e) {
      if (mounted) setState(() => _notice = 'No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final folders = _isStatement
        ? {
            for (final entry in widget.statementDocuments.entries)
              'credit_card_statements/${entry.key}': entry.value,
          }
        : {_folder: widget.canRemove};
    final files = <({String folder, String name, bool writable})>[];
    for (final folder in folders.entries) {
      for (var offset = 0; ; offset += 100) {
        final page = await _bucket.list(
          path: folder.key,
          searchOptions: SearchOptions(limit: 100, offset: offset),
        );
        checkPersonSession(_uid);
        files.addAll(
          page.map(
            (file) =>
                (folder: folder.key, name: file.name, writable: folder.value),
          ),
        );
        if (page.length < 100) break;
      }
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _files
        ..clear()
        ..addAll(files);
    });
  }

  String _label(String name) =>
      name.replaceFirst(RegExp(r'^[a-f0-9]{32}_'), '');

  Future<void> _add() => _run(() async {
    final receipt = await PendingReceipt.pick();
    if (receipt == null || !mounted) return;
    if (_isStatement) {
      await _load();
      if (!mounted || !_canAdd) return;
    }
    await receipt.upload(_bucket, _folder, _uid);
    await _load();
  });

  Future<void> _preview(String folder, String name) async {
    final path = '$folder/$name';
    final download = await showFilePreview(
      context,
      label: _label(name),
      sourceName: path,
      load: () => _runPreviewLoad(path),
      allowDownload: true,
    );
    if (download == true && mounted) await _download(folder, name);
  }

  Future<Uint8List> _runPreviewLoad(String path) async {
    checkPersonSession(_uid);
    final bytes = await _bucket.download(path);
    checkPersonSession(_uid);
    return bytes;
  }

  Future<void> _download(String folder, String name) => _run(() async {
    final display = _label(name);
    final dot = display.lastIndexOf('.');
    final ext = display.substring(dot + 1);
    final base = display.substring(0, dot);
    final bytes = await _bucket.download('$folder/$name');
    if (!mounted) return;
    checkPersonSession(_uid);
    final saver = FileSaver.instance;
    final String? result;
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
      result = await saver.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: ext,
        mimeType: MimeType.custom,
        customMimeType: _types[ext]!,
      );
    } else {
      result = await saver.saveAs(
        name: base,
        bytes: bytes,
        fileExtension: ext,
        mimeType: MimeType.custom,
        customMimeType: _types[ext]!,
      );
    }
    if (result != null &&
        (result.isEmpty || result.startsWith('Something went wrong'))) {
      throw StateError('El sistema no pudo guardar el archivo.');
    }
    if (result != null && mounted)
      setState(() => _notice = 'Descarga solicitada.');
  });

  Future<void> _remove(String folder, String name) => _run(() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isStatement ? 'Quitar documento' : 'Quitar comprobante'),
        content: Text(_label(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    checkPersonSession(_uid);
    await _bucket.remove(['$folder/$name']);
    await _load();
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: EdgeInsets.symmetric(
      horizontal: compactLayout(context) ? 12 : 40,
      vertical: 20,
    ),
    title: Text(_isStatement ? 'Documento del banco' : 'Comprobantes'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_notice != null) Text(_notice!),
            if (_files.isEmpty && !_busy && _notice == null)
              Text(
                _isStatement
                    ? 'Todavía no hay un documento para este corte.'
                    : 'Este movimiento todavía no tiene comprobantes.',
              ),
            for (final (:folder, :name, :writable) in _files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(name)),
                leading: const Icon(Icons.attach_file),
                onTap: _busy ? null : () => _preview(folder, name),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Vista previa',
                      onPressed: _busy ? null : () => _preview(folder, name),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                    IconButton(
                      tooltip: 'Descargar',
                      onPressed: _busy ? null : () => _download(folder, name),
                      icon: const Icon(Icons.download_outlined),
                    ),
                    if (writable)
                      IconButton(
                        tooltip: 'Quitar',
                        onPressed: _busy ? null : () => _remove(folder, name),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            if (_canAdd)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Imágenes, PDF, Word, Excel o TXT. Hasta 10 MB por archivo.',
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      IconButton(
        tooltip: 'Actualizar',
        onPressed: _busy ? null : () => _run(_load),
        icon: const Icon(Icons.refresh),
      ),
      if (_canAdd)
        FilledButton.icon(
          onPressed: _busy ? null : _add,
          icon: const Icon(Icons.upload_file),
          label: Text(_isStatement ? 'Adjuntar documento' : 'Adjuntar'),
        ),
    ],
  );
}

/// Identifies the original record so linked views share the same attachments.
class MovementReceiptsButton extends StatelessWidget {
  const MovementReceiptsButton({
    super.key,
    required this.table,
    required this.record,
    this.iconOnly = false,
    this.count = 0,
    this.onClosed,
  });

  final String table;
  final Map<String, dynamic> record;
  final bool iconOnly;
  final int count;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final id = record['id']?.toString();
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    Future<void> open() async {
      await showDialog<void>(
        context: context,
        builder: (_) => PersonReceiptsDialog.movement(
          table: table,
          entryId: id,
          writable: record['is_voided'] != true,
        ),
      );
      if (context.mounted) onClosed?.call();
    }

    return iconOnly
        ? IconButton(
            tooltip: 'Comprobantes',
            onPressed: open,
            icon: const Icon(Icons.attach_file),
          )
        : Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: open,
              icon: const Icon(Icons.attach_file),
              label: Text(count > 0 ? 'Comprobantes ($count)' : 'Comprobantes'),
            ),
          );
  }
}
