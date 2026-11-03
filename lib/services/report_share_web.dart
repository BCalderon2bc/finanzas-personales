import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';
import 'package:web/web.dart' as web;

@JS('navigator.canShare')
external JSBoolean _canShare(JSObject data);
@JS('navigator.share')
external JSPromise<JSAny?> _share(JSObject data);

Future<bool> shareReportFile(
  Uint8List bytes,
  String filename,
  String mime,
  String title,
  Rect origin,
) async {
  // File se construye sin lectura asíncrona: navigator.share conserva el toque.
  final file = web.File(
    [bytes.toJS].toJS,
    filename,
    web.FilePropertyBag(type: mime),
  );
  final data =
      {
            'files': [file],
            'title': title,
          }.jsify()!
          as JSObject;
  try {
    if (!_canShare(data).toDart) return false;
    await _share(data).toDart;
    return true;
  } catch (error) {
    // Cerrar la hoja del sistema no es un error ni provoca una descarga.
    if (error.toString().contains('AbortError')) return true;
    return false;
  }
}
