import 'package:flutter/material.dart';
import '../../core/appearance.dart';
import '../../core/app_theme.dart';
import '../../widgets/adaptive_layout.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});
  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool saving = false;
  Future<void> save(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la apariencia. Intenta nuevamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppearanceController.instance,
    builder: (context, _) {
      final appearance = AppearanceController.instance;
      final theme = Theme.of(context);
      Widget panel(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Colores y fuente')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: EdgeInsets.all(pageGutter(context)),
                children: [
                  Text(
                    'Personaliza Mi Billete',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const Text(
                    'Se aplica a las pantallas y a los nuevos reportes PDF y Excel. Se guarda en este dispositivo.',
                  ),
                  if (saving) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  panel('Tema de color', [
                    AdaptiveColumns(
                      minColumnWidth: 220,
                      maxColumns: 3,
                      spacing: 12,
                      children: [
                        for (final entry in appearancePalettes.entries)
                          Card(
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: appearance.theme == entry.key
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                width: appearance.theme == entry.key ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: saving
                                  ? null
                                  : () => save(
                                      () => appearance.update(theme: entry.key),
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.value.name,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ),
                                        if (appearance.theme == entry.key)
                                          Icon(
                                            Icons.check_circle,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 28,
                                      color: entry.value.navigation,
                                    ),
                                    Container(
                                      height: 38,
                                      color: entry.value.background,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Container(
                                        height: 12,
                                        width: 64,
                                        color: entry.value.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ]),
                  panel('Tipografía y lectura', [
                    DropdownButtonFormField<String>(
                      initialValue: appearance.font,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Fuente'),
                      items: [
                        for (final entry in appearanceFonts.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: TextStyle(fontFamily: entry.value),
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null)
                                save(() => appearance.update(font: value));
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<double>(
                      initialValue: appearance.scale,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tamaño de letra',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: .9,
                          child: Text('Pequeño · 90%'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Normal · 100%'),
                        ),
                        DropdownMenuItem(
                          value: 1.1,
                          child: Text('Grande · 110%'),
                        ),
                        DropdownMenuItem(
                          value: 1.2,
                          child: Text('Más grande · 120%'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null)
                                save(() => appearance.update(scale: value));
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Controles compactos'),
                      subtitle: const Text(
                        'Reduce el espacio de botones y listas sin reducir la letra.',
                      ),
                      value: appearance.compact,
                      onChanged: saving
                          ? null
                          : (value) =>
                                save(() => appearance.update(compact: value)),
                    ),
                    const Text(
                      'El tamaño se combina con la configuración de accesibilidad de tu dispositivo.',
                    ),
                  ]),
                  panel('Vista previa', [
                    Text(
                      'Gastos consolidados',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    AdaptiveColumns(
                      minColumnWidth: 180,
                      maxColumns: 2,
                      spacing: 12,
                      children: [
                        for (final label in [
                          'Dólares · \$125.50',
                          'Córdobas · C\$4,596.77',
                        ])
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: 'Pago de tarjeta',
                      decoration: const InputDecoration(
                        labelText: 'Descripción de ejemplo',
                      ),
                      readOnly: true,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Botón de ejemplo'),
                      ),
                    ),
                  ]),
                  panel('Estados y alertas', [
                    const Text(
                      'Estos colores conservan su significado en los tres temas; el texto y los iconos también indican el estado.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in <(String, IconData, Color)>[
                          ('Vencido / error', Icons.error_outline, appNegative),
                          ('Vence hoy', Icons.today, appDueToday),
                          (
                            'Próximo / advertencia',
                            Icons.warning_amber,
                            appWarning,
                          ),
                          (
                            'Pagado / completado',
                            Icons.check_circle_outline,
                            appPositive,
                          ),
                          (
                            'Inactivo / histórico',
                            Icons.pause_circle_outline,
                            appMuted,
                          ),
                        ])
                          Chip(
                            avatar: Icon(item.$2, color: item.$3, size: 18),
                            label: Text(
                              item.$1,
                              style: TextStyle(color: item.$3),
                            ),
                            backgroundColor: item.$3.withValues(alpha: .08),
                          ),
                      ],
                    ),
                  ]),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => save(appearance.reset),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar apariencia predeterminada'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
