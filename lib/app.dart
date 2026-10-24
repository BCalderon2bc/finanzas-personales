import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'core/app_theme.dart';

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mis Finanzas',
      theme: createAppTheme(),
      home: const AuthGate(),
    );
  }
}
