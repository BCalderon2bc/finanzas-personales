import '../utils/money.dart';
import 'export_report_models.dart';

/// El saldo conserva el signo del registro; los nombres aclaran la dirección
/// para quien reciba el archivo, sin depender de interpretar un + o un -.
class PersonAccountExportReport extends ExportReport {
  const PersonAccountExportReport({
    required super.title,
    required super.period,
    required super.generatedAt,
    required super.tables,
    required super.totals,
    required super.notes,
    required this.ownerName,
    required this.personName,
    required this.closingCents,
  });
  final String ownerName, personName;
  final int closingCents;
  bool get settled => closingCents == 0;
  String get debtor => closingCents > 0 ? ownerName : personName;
  String get creditor => closingCents > 0 ? personName : ownerName;
  String get direction =>
      settled ? 'Ninguno le debe al otro' : '$debtor le debe a $creditor';
  String get amountLabel => formatMoneyCents(closingCents.abs(), 'NIO');
}
