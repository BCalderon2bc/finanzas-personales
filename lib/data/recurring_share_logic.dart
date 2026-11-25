/// Returns the user's monthly share in the same fixed monetary units as the input.
int recurringOwnShare(int total, int discount, int people) {
  if (total <= 0 ||
      discount < 0 ||
      discount >= total ||
      people < 1 ||
      people > 100) {
    throw ArgumentError('Revisa el monto, descuento y número de personas.');
  }
  final share =
      ((BigInt.from(total - discount) + BigInt.from(people ~/ 2)) ~/
              BigInt.from(people))
          .toInt();
  if (share <= 0) throw ArgumentError('Tu parte debe ser mayor que cero.');
  return share;
}
