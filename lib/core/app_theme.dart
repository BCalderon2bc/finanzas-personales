import 'package:flutter/material.dart';

const primaryColor = Color(0xFF17604E);
const appBackground = Color(0xFFF5F7F3);
const appText = Color(0xFF182B24);
const appMuted = Color(0xFF50665B);
const appBorder = Color(0xFFD9E3DA);
const appPositive = Color(0xFF14684D);
const appWarning = Color(0xFF895510);
const appNegative = Color(0xFFA2322C);

ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: primaryColor).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDDEFE4),
    onPrimaryContainer: const Color(0xFF174938),
    secondary: const Color(0xFF386455),
    secondaryContainer: const Color(0xFFE7EEE8),
    onSecondaryContainer: appText,
    tertiary: appWarning,
    tertiaryContainer: const Color(0xFFF8ECD5),
    onTertiaryContainer: const Color(0xFF5B3A10),
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF8FAF7),
    surfaceContainer: const Color(0xFFF0F4EF),
    surfaceContainerHigh: const Color(0xFFEAF0EA),
    surfaceContainerHighest: const Color(0xFFE4EBE4),
    onSurface: appText,
    onSurfaceVariant: appMuted,
    outline: const Color(0xFF788E81),
    outlineVariant: appBorder,
    error: appNegative,
    errorContainer: const Color(0xFFFBEAE6),
    onErrorContainer: const Color(0xFF732522),
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
