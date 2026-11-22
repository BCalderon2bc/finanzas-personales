import 'appearance.dart';
import 'package:flutter/material.dart';

Color get appNavy => AppearanceController.instance.palette.navigation;
Color get appNavigationText => const Color(0xFFE4ECF1);
Color get appNavigationSelection =>
    AppearanceController.instance.palette.selection;
Color get primaryColor => AppearanceController.instance.palette.primary;
Color get appBackground => AppearanceController.instance.palette.background;
Color get appText => const Color(0xFF253543);
Color get appPrimaryDeep => AppearanceController.instance.palette.navigation;
Color get appSurfaceSubtle => Color.lerp(
  Colors.white,
  AppearanceController.instance.palette.background,
  .5,
)!;
Color get appSurfaceMuted => AppearanceController.instance.palette.tint;
Color get appPrimaryTint => AppearanceController.instance.palette.tint;
Color get appMuted => const Color(0xFF5D6C73);
Color get appBorder => Color.lerp(
  AppearanceController.instance.palette.primary,
  Colors.white,
  .82,
)!;
const appPositive = Color(0xFF397455);
const appDueToday = Color(0xFFA65322);
const appWarning = Color(0xFF946200);
const appNegative = Color(0xFFB13D32);

ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: primaryColor).copyWith(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: appPrimaryTint,
    onPrimaryContainer: appNavy,
    secondary: appMuted,
    secondaryContainer: appSurfaceMuted,
    onSecondaryContainer: appText,
    tertiary: appWarning,
    tertiaryContainer: const Color(0xFFF7EEDC),
    onTertiaryContainer: const Color(0xFF684A21),
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: appSurfaceSubtle,
    surfaceContainer: appSurfaceMuted,
    surfaceContainerHigh: appSurfaceMuted,
    surfaceContainerHighest: appPrimaryTint,
    onSurface: appText,
    onSurfaceVariant: appMuted,
    outline: appMuted,
    outlineVariant: appBorder,
    error: appNegative,
    errorContainer: const Color(0xFFF9EBE8),
    onErrorContainer: const Color(0xFF79342E),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppearanceController.instance.fontFamily,
    visualDensity: AppearanceController.instance.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(color: appBorder),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: appBorder),
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
      backgroundColor: appNavy,
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
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      labelStyle: TextStyle(color: appMuted),
      hintStyle: TextStyle(color: appMuted),
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
        side: BorderSide(color: appBorder),
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
      side: BorderSide(color: appBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: appText,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: appBorder, thickness: 1),
    listTileTheme: ListTileThemeData(
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
