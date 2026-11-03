import 'package:file_selector/file_selector.dart' show XFile;
import 'package:file_selector_web/file_selector_web.dart';

Future<XFile?> pickReceiptFile() => FileSelectorWeb().openFile();