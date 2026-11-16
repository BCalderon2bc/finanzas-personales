import 'package:flutter/material.dart';

class CollapsibleFilters extends StatelessWidget {
  const CollapsibleFilters({super.key, required this.children, this.summary});

  final List<Widget> children;
  final String? summary;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      maintainState: true,
      leading: const Icon(Icons.tune_rounded),
      title: const Text('Filtros'),
      subtitle: summary == null ? null : Text(summary!),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: children,
    ),
  );
}
