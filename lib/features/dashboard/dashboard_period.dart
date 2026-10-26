/// Calendar-day interval, inclusive on both ends. No UTC conversion is applied
/// to a date chosen in the UI; timestamps are localized by the loader.
class DashboardPeriod {
  DashboardPeriod(DateTime from, DateTime until)
    : start = DateTime(from.year, from.month, from.day),
      end = DateTime(until.year, until.month, until.day) {
    if (end.isBefore(start))
      throw ArgumentError('La fecha Hasta debe ser igual o posterior a Desde.');
  }
  factory DashboardPeriod.forMonth(DateTime date) => DashboardPeriod(
    DateTime(date.year, date.month, 1),
    DateTime(date.year, date.month + 1, 0),
  );
  final DateTime start, end;
  static int _ordinal(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  int get days => _ordinal(end) - _ordinal(start) + 1;
  bool contains(DateTime date) =>
      _ordinal(date) >= _ordinal(start) && _ordinal(date) <= _ordinal(end);
  bool get isFullMonth =>
      start.day == 1 &&
      start.year == end.year &&
      start.month == end.month &&
      end.day == DateTime(end.year, end.month + 1, 0).day;
  bool overlapsMonth(DateTime month) =>
      !DateTime(month.year, month.month + 1, 0).isBefore(start) &&
      !DateTime(month.year, month.month).isAfter(end);
  DashboardPeriod get previous {
    if (isFullMonth)
      return DashboardPeriod.forMonth(DateTime(start.year, start.month - 1));
    // UTC day arithmetic prevents DST transitions from shortening a day.
    final previousEnd = DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).subtract(const Duration(days: 1));
    return DashboardPeriod(
      previousEnd.subtract(Duration(days: days - 1)),
      previousEnd,
    );
  }

  String get label => '${dateLabel(start)} – ${dateLabel(end)}';
  static String dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
