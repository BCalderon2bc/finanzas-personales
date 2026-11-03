import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import 'person_receipts_dialog.dart';
export 'person_receipts_dialog.dart' show PendingReceipt;

const receiptDraftKey = '_pendingReceipt';

class ReceiptDraft {
  PendingReceipt? file;
  bool picking = false;

  Map<String, dynamic> get fields => {if (file != null) receiptDraftKey: file};
}

class ReceiptDraftField extends StatefulWidget {
  const ReceiptDraftField({super.key, required this.draft});
  final ReceiptDraft draft;

  @override
  State<ReceiptDraftField> createState() => _ReceiptDraftFieldState();
}

class _ReceiptDraftFieldState extends State<ReceiptDraftField> {
  String? error;

  Future<void> pick() async {
    setState(() {
      widget.draft.picking = true;
      error = null;
    });
    try {
      final file = await PendingReceipt.pick();
      if (mounted && file != null) widget.draft.file = file;
    } catch (e) {
      if (mounted) {
        error = e is FormatException
            ? e.message
            : 'No se pudo leer el archivo.';
      }
    } finally {
      widget.draft.picking = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      TextButton.icon(
        onPressed: widget.draft.picking ? null : pick,
        icon: const Icon(Icons.attach_file),
        label: Text(
          widget.draft.picking
              ? 'Leyendo…'
              : widget.draft.file == null
              ? 'Adjuntar comprobante'
              : 'Cambiar comprobante',
        ),
      ),
      if (widget.draft.file case final file?)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(file.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            IconButton(
              tooltip: 'Vista previa',
              onPressed: widget.draft.picking
                  ? null
                  : () => file.preview(context),
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'Quitar comprobante',
              onPressed: widget.draft.picking
                  ? null
                  : () => setState(() {
                      widget.draft.file = null;
                      error = null;
                    }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      if (error case final message?)
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

Future<bool> uploadSavedReceipt(
  BuildContext context, {
  required PendingReceipt receipt,
  required String uid,
  required String folder,
  bool person = false,
}) async {
  final bucket = supabase.storage.from(
    person ? 'person-receipts' : 'movement-receipts',
  );
  while (context.mounted) {
    try {
      await receipt.upload(bucket, folder, uid);
      return true;
    } catch (_) {
      if (!context.mounted || supabase.auth.currentUser?.id != uid)
        return false;
      final retry = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Registro guardado'),
          content: const Text(
            'No se confirmó la carga del comprobante. Puedes volver a intentar sin duplicar el registro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Reintentar carga'),
            ),
          ],
        ),
      );
      if (retry != true) return false;
    }
  }
  return false;
}

Future<void> attachFinancialReceipt(
  BuildContext context,
  PendingReceipt? receipt,
  String uid,
  String table,
  Object? id,
) async {
  if (receipt == null || !context.mounted) return;
  if (id == null || id.toString().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registro guardado. Abre Comprobantes en el historial para adjuntar el archivo.',
        ),
      ),
    );
    return;
  }
  await uploadSavedReceipt(
    context,
    receipt: receipt,
    uid: uid,
    folder: '$table/$id',
  );
}
