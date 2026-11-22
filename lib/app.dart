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
            textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(context).scale(1) *
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
