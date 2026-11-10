import 'package:flutter/material.dart';
import '../utils/money.dart';
import '../utils/total_parts.dart';

Future<void> showTotalDetails(
  BuildContext context, {
  required String title,
  required String scope,
  required int total,
  required String currency,
  required List<TotalPart> parts,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 620,
        height: size.height * .55,
        child: ListView.builder(
          itemCount: parts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scope),
                    Text(
                      formatMoneyCents(total, currency),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (parts.isEmpty)
                      const Text('No hay registros para este total.'),
                  ],
                ),
              );
            }
            final part = parts[index - 1];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(part.label),
              subtitle: Text(formatMoneyCents(part.cents, part.currency)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  },
);
