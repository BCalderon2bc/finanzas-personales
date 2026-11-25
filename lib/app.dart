import 'core/appearance.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_gate.dart';

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppearanceController.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mi Billete',
        theme: createAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: ReadableTextScaler(
              MediaQuery.textScalerOf(context),
              AppearanceController.instance.scale,
            ),
          ),
          child: child!,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Apply the chosen size without forcing a minimum or an extra enlargement.
/// Preserve the operating system's accessibility scaling.
class ReadableTextScaler extends TextScaler {
  const ReadableTextScaler(this.system, this.preference);
  final TextScaler system;
  final double preference;
  @override
  double scale(double fontSize) {
    if (fontSize == 0) return 0;
    return system.scale(fontSize) * preference;
  }

  @override
  double get textScaleFactor => scale(14) / 14;
}
