import 'package:flutter/material.dart';

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key, required this.icon, required this.title,
    required this.subtitle, this.onTap, this.enabled = true,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: enabled ? colors.primary.withAlpha(20) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon,
                  color: enabled ? colors.primary : colors.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(
                color: enabled ? colors.onSurface : colors.onSurfaceVariant,
              )),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
            )),
            const SizedBox(width: 8),
            Icon(enabled ? Icons.chevron_right_rounded : Icons.lock_outline,
                color: colors.onSurfaceVariant, size: 22),
          ]),
        ),
      ),
    );
  }
}