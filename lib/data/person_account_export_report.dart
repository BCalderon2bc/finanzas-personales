import '../utils/money.dart';
import 'export_report_models.dart';
import 'exchange_rate.dart';

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
    this.settlementRate,
  });
  final String ownerName, personName;
  final int closingCents;
  final ExchangeRate? settlementRate;
  bool get settled => closingCents == 0;
  String get debtor => closingCents > 0 ? ownerName : personName;
  String get creditor => closingCents > 0 ? personName : ownerName;
  String get direction =>
      settled ? 'Ninguno le debe al otro' : '$debtor le debe a $creditor';
  String get amountLabel => formatMoneyCents(closingCents.abs(), 'NIO');
  int? get paymentUsdCents =>
      settled ? 0 : settlementRate?.convert(closingCents.abs(), 'NIO', 'USD');
  String get paymentNioLabel => 'Si paga en córdobas: $amountLabel';
  String get paymentUsdLabel => paymentUsdCents == null
      ? 'Si paga en dólares: indica una tasa de pago'
      : 'Si paga en dólares: ${formatMoneyCents(paymentUsdCents!, 'USD')}';
  String get paymentRateLabel => settlementRate == null
      ? 'Sin tasa de pago indicada'
      : 'Tasa de pago: C\$ ${settlementRate!.decimal} por US\$ 1';
}
