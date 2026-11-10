import 'package:flutter/material.dart';

const primaryColor = Color(0xFF3C70AA);
const appBackground = Color(0xFFF5F7FA);
const appText = Color(0xFF243447);
const appMuted = Color(0xFF596B7D);
const appBorder = Color(0xFFDCE3EB);
const appPositive = Color(0xFF35745C);
const appWarning = Color(0xFF886128);
const appNegative = Color(0xFFA3453D);

ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: primaryColor).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE5EDF6),
    onPrimaryContainer: const Color(0xFF304F70),
    secondary: const Color(0xFF627A91),
    secondaryContainer: const Color(0xFFEBEFF4),
    onSecondaryContainer: appText,
    tertiary: appWarning,
    tertiaryContainer: const Color(0xFFF7EEDC),
    onTertiaryContainer: const Color(0xFF684A21),
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF8FAFC),
    surfaceContainer: const Color(0xFFF0F3F7),
    surfaceContainerHigh: const Color(0xFFEAF0F5),
    surfaceContainerHighest: const Color(0xFFE3EAF1),
    onSurface: appText,
    onSurfaceVariant: appMuted,
    outline: const Color(0xFF77899B),
    outlineVariant: appBorder,
    error: appNegative,
    errorContainer: const Color(0xFFF9EBE8),
    onErrorContainer: const Color(0xFF79342E),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: const BorderSide(color: appBorder),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: appBorder),
  );
  final type = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: appMuted, height: 1.4),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  return base.copyWith(
    textTheme: type,
    scaffoldBackgroundColor: appBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: appText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: appText.withValues(alpha: .14),
      centerTitle: false,
      titleTextStyle: type.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: surfaceShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      helperMaxLines: 3,
      errorMaxLines: 3,
      prefixIconColor: appMuted,
      suffixIconColor: appMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: controlShape,
        textStyle: type.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: appBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: controlShape,
        textStyle: type.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: controlShape,
        textStyle: type.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: type.titleLarge,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: surfaceShape,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      side: const BorderSide(color: appBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: appText,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: appBorder, thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: primaryColor,
      textColor: appText,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: scheme.primaryContainer,
    ),
  );
}
