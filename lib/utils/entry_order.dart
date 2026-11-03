/// Orden del historial por ingreso: las ediciones no cambian de posición.
/// Fecha del movimiento se usa solo como respaldo para datos antiguos sin creación.
int compareNewestEntry(Map<String, dynamic> a, Map<String, dynamic> b) {
  DateTime? entered(Map<String, dynamic> row) =>
      DateTime.tryParse('${row['created_at']}') ??
      DateTime.tryParse('${row['transaction_date'] ?? row['payment_date']}');
  final first = entered(a), second = entered(b);
  if (first == null && second != null) return 1;
  if (second == null && first != null) return -1;
  final byDate = first == null ? 0 : second!.compareTo(first);
  if (byDate != 0) return byDate;
  final byId = '${b['id']}'.compareTo('${a['id']}');
  return byId != 0 ? byId : '${b['source']}'.compareTo('${a['source']}');
}
