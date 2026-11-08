import 'package:flutter/material.dart';

bool compactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 650;

double pageGutter(BuildContext context) => compactLayout(context) ? 12 : 24;

/// Use the monitor's width while keeping very wide windows readable.
const double widePageMaxWidth = 1680;

/// Keeps the same children mounted when the viewport switches column count.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.children,
    required this.minColumnWidth,
    this.maxColumns = 2,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (children.isEmpty) return const SizedBox.shrink();
      final available = constraints.maxWidth;
      final limit = children.length < maxColumns ? children.length : maxColumns;
      final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
        1.0,
        1.8,
      );
      final columnWidth = minColumnWidth * textScale;
      final columns = ((available + spacing) / (columnWidth + spacing))
          .floor()
          .clamp(1, limit)
          .toInt();
      final width = columns == 1
          ? available
          : ((available - spacing * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class CompactActionBar extends StatelessWidget {
  const CompactActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

/// Centers scrollable content and gives dense lists a readable desktop width.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 1080});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}
