import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version reported by this build, rather than a hard-coded display string.
class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});
  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  late Future<PackageInfo> information;
  @override
  void initState() {
    super.initState();
    information = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: FutureBuilder<PackageInfo>(
      future: information,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version.trim() ?? '';
        final build = info?.buildNumber.trim() ?? '';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
          [
            if (snapshot.connectionState != ConnectionState.done)
              Center(child: const Text('Consultando versión…', style: TextStyle(fontSize: 12)))
            else if (snapshot.hasError || version.isEmpty)
              Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Versión no disponible',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reintentar',
                    onPressed: () => setState(
                      () => information = PackageInfo.fromPlatform(),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ],
              )
            else
              Center(
                child: Text(
                  'Versión $version${build.isEmpty ? '' : ' · compilación $build'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
