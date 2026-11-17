import 'package:flutter/material.dart';

const appNavy = Color(0xFF304B64);
const appNavigationText = Color(0xFFDCE7F1);
const appNavigationSelection = Color(0xFF4E6D88);
const primaryColor = Color(0xFF426583);
const appBackground = Color(0xFFF1F5F9);
const appText = Color(0xFF203449);
const appPrimaryDeep = Color(0xFF36536D);
const appSurfaceSubtle = Color(0xFFF7FAFC);
const appSurfaceMuted = Color(0xFFE9EFF5);
const appPrimaryTint = Color(0xFFDFE9F2);
const appMuted = Color(0xFF526579);
const appBorder = Color(0xFFDCE5EE);
const appPositive = Color(0xFF35745C);
const appWarning = Color(0xFF886128);
const appNegative = Color(0xFFA3453D);

ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: primaryColor).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: appPrimaryTint,
    onPrimaryContainer: const Color(0xFF2F4B65),
    secondary: const Color(0xFF5C7184),
    secondaryContainer: const Color(0xFFE8EEF4),
    onSecondaryContainer: appText,
    tertiary: appWarning,
    tertiaryContainer: const Color(0xFFF7EEDC),
    onTertiaryContainer: const Color(0xFF684A21),
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: appSurfaceSubtle,
    surfaceContainer: appSurfaceMuted,
    surfaceContainerHigh: const Color(0xFFE6EDF4),
    surfaceContainerHighest: const Color(0xFFDFE8F0),
    onSurface: appText,
    onSurfaceVariant: appMuted,
    outline: const Color(0xFF708499),
    outlineVariant: appBorder,
    error: appNegative,
    errorContainer: const Color(0xFFF9EBE8),
    onErrorContainer: const Color(0xFF79342E),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Noto Sans',
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: const BorderSide(color: appBorder),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: appBorder),
  );
  final type = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 22,
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
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: appText.withValues(alpha: .14),
      centerTitle: false,
      titleTextStyle: type.titleLarge?.copyWith(color: Colors.white),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primaryColor,
      unselectedLabelColor: appMuted,
      indicatorColor: primaryColor,
      labelStyle: type.labelLarge,
      unselectedLabelStyle: type.labelLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: appNavy.withValues(alpha: .13),
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: appNavy,
      surfaceTintColor: Colors.transparent,
      indicatorColor: appNavigationSelection,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : appNavigationText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => type.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : appNavigationText,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: appNavy,
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
