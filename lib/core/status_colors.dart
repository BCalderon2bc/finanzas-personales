import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Uses calendar days; completed and inactive records override their due date.
Color appDueColor(
  DateTime? due, {
  bool settled = false,
  bool inactive = false,
  DateTime? now,
}) {
  if (inactive) return appMuted;
  if (settled) return appPositive;
  if (due == null) return appMuted;
  final today = now ?? DateTime.now();
  final days = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days < 0) return appNegative;
  if (days == 0) return appDueToday;
  if (days <= 7) return appWarning;
  return appMuted;
}
