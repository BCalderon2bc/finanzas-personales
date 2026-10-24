import 'package:flutter/material.dart';

const primaryColor = Color(0xFF2563EB);
const appBackground = Color(0xFFF4F7FB);
const appText = Color(0xFF172033);
const appMuted = Color(0xFF64748B);
const appBorder = Color(0xFFE2E8F0);

ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    secondary: const Color(0xFF0F766E),
    surface: Colors.white,
    onSurface: appText,
    onSurfaceVariant: appMuted,
    outline: appBorder,
    error: const Color(0xFFB42318),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: appBorder),
  );

  return base.copyWith(
    scaffoldBackgroundColor: appBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: appBackground,
      foregroundColor: appText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: appText, fontSize: 20, fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: appText, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: appText, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: appText, fontSize: 21, fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: appText, fontSize: 16, fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: appText, fontSize: 14, height: 1.45,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: appMuted, fontSize: 12, height: 1.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: appBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: primaryColor, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      labelStyle: const TextStyle(color: appMuted),
      hintStyle: const TextStyle(color: appMuted),
      prefixIconColor: appMuted,
      suffixIconColor: appMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: appBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: buttonShape,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: appText,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: appBorder, thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: primaryColor,
      textColor: appText,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: Color(0xFFE8EEF8),
    ),
  );
}