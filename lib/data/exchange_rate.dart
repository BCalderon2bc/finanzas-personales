/// Tasa manual: córdobas por un dólar, con hasta seis decimales.
/// Se usa BigInt para redondear centavos sin errores de coma flotante.
class ExchangeRate {
  ExchangeRate._(this.micros);
  final int micros;

  static ExchangeRate? tryParse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,6})?$').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('.');
    final whole = int.parse(parts.first);
    final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(6, '0'));
    final value = whole * 1000000 + fraction;
    if (value <= 0 || value > 1000000 * 1000000) {
      return null;
    }
    return ExchangeRate._(value);
  }

  String get decimal {
    final whole = micros ~/ 1000000;
    final fraction = (micros % 1000000).toString().padLeft(6, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }

  int convert(int cents, String from, String to) {
    if (!['NIO', 'USD'].contains(from) || !['NIO', 'USD'].contains(to)) {
      throw ArgumentError('Solo se admiten NIO y USD.');
    }
    if (from == to) {
      return cents;
    }
    final amount = BigInt.from(cents);
    final rate = BigInt.from(micros);
    final scale = BigInt.from(1000000);
    final numerator = from == 'USD' ? amount * rate : amount * scale;
    final denominator = from == 'USD' ? scale : rate;
    final absolute = numerator.abs();
    final rounded = (absolute + denominator ~/ BigInt.from(2)) ~/ denominator;
    final signed = numerator.isNegative ? -rounded : rounded;
    // Dart web almacena los int como números JS: conservar precisión exacta.
    if (signed.abs() > BigInt.parse('9007199254740991')) {
      throw StateError('El importe convertido excede el rango de precisión.');
    }
    return signed.toInt();
  }
}
