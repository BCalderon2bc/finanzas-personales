/// Córdobas por un dólar. Redondea únicamente el importe recibido.
int transferReceivedCents(
  int sentCents,
  String source,
  String destination,
  double rate,
) {
  if (!['NIO', 'USD'].contains(source) ||
      !['NIO', 'USD'].contains(destination) ||
      sentCents <= 0 ||
      !rate.isFinite ||
      rate <= 0 ||
      rate > 1000000) {
    throw ArgumentError('Monto, moneda o tasa inválidos.');
  }
  final received = source == destination
      ? sentCents
      : (source == 'USD' ? sentCents * rate : sentCents / rate).round();
  if (received <= 0 || received > 100000000000000) {
    throw ArgumentError('El monto recibido queda fuera del rango permitido.');
  }
  return received;
}
