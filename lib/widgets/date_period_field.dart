import 'package:flutter/material.dart';
import '../data/period_logic.dart';
import 'adaptive_layout.dart';

class DatePeriodField extends StatelessWidget {
  const DatePeriodField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.enabled = true,
  });
  final DateTime start, end;
  final ValueChanged<DateTimeRange> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Builder(
      builder: (context) {
        Widget button(String label, DateTime date, bool from) =>
            OutlinedButton.icon(
              onPressed: !enabled
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: from ? DateTime(1900) : start,
                        lastDate: from ? end : DateTime(2200),
                      );
                      if (selected != null)
                        onChanged(
                          DateTimeRange(
                            start: from ? selected : start,
                            end: from ? end : selected,
                          ),
                        );
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                '$label\n${isoDay(date)}',
                textAlign: TextAlign.center,
              ),
            );
        return AdaptiveColumns(
          minColumnWidth: 164,
          children: [
            button('Fecha inicial', start, true),
            button('Fecha final', end, false),
          ],
        );
      },
    ),
  );
}
