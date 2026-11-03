import 'dart:typed_data';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

Future<bool> shareReportFile(
  Uint8List bytes,
  String filename,
  String mime,
  String title,
  Rect origin,
) async {
  final result = await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: mime, name: filename)],
    fileNameOverrides: [filename],
    subject: title,
    sharePositionOrigin: origin,
  );
  return result.status.name != 'unavailable';
}
