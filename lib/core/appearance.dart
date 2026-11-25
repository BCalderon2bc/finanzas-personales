import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearancePalette {
  const AppearancePalette(
    this.name,
    this.primary,
    this.navigation,
    this.background,
    this.tint,
  );
  final String name;
  final Color primary, navigation, background, tint;
  Color get selection => Color.lerp(navigation, primary, .65)!;
}

const appearancePalettes = {
  'slate': AppearancePalette(
    '1 · Pizarra + cian',
    Color(0xFF217E9F),
    Color(0xFF253543),
    Color(0xFFF2F5F8),
    Color(0xFFE4F1F6),
  ),
  'petrol': AppearancePalette(
    '2 · Verde petróleo',
    Color(0xFF356F70),
    Color(0xFF253E40),
    Color(0xFFF3F7F6),
    Color(0xFFE3EFED),
  ),
  'sage': AppearancePalette(
    '3 · Salvia suave',
    Color(0xFF557562),
    Color(0xFF34493E),
    Color(0xFFF4F6F2),
    Color(0xFFE5EDE3),
  ),
};
const appearanceFonts = {
  'noto': 'Noto Sans',
  'open': 'Open Sans',
  'serif': 'DejaVu Serif',
  'liberation': 'Liberation Sans',
};

class AppearanceController extends ChangeNotifier {
  static final instance = AppearanceController._();
  AppearanceController._();
  String theme = 'slate', font = 'noto';
  double scale = 1;
  bool compact = false;
  AppearancePalette get palette => appearancePalettes[theme]!;
  String get fontFamily => appearanceFonts[font]!;
  String get regularAsset => switch (font) {
    'liberation' => 'assets/fonts/LiberationSans-Regular.ttf',
    'open' => 'assets/fonts/OpenSans-Regular.ttf',
    'serif' => 'assets/fonts/DejaVuSerif.ttf',
    _ => 'assets/fonts/NotoSans-Regular.ttf',
  };
  String get boldAsset => switch (font) {
    'liberation' => 'assets/fonts/LiberationSans-Bold.ttf',
    'open' => 'assets/fonts/OpenSans-Bold.ttf',
    'serif' => 'assets/fonts/DejaVuSerif-Bold.ttf',
    _ => 'assets/fonts/NotoSans-Bold.ttf',
  };
  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        'appearance.v1',
      );
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (appearancePalettes.containsKey(data['theme'])) theme = data['theme'];
      if (appearanceFonts.containsKey(data['font'])) font = data['font'];
      if (data['scale'] is num &&
          const [
            .8,
            .9,
            1.0,
            1.1,
            1.2,
          ].contains((data['scale'] as num).toDouble())) {
        scale = (data['scale'] as num).toDouble();
      }
      compact = data['compact'] == true;
    } catch (_) {
      /* Keep usable defaults if stored settings are unavailable. */
    }
  }

  Future<void> update({
    String? theme,
    String? font,
    double? scale,
    bool? compact,
  }) async {
    final nextTheme = theme ?? this.theme, nextFont = font ?? this.font;
    final nextScale = (scale ?? this.scale).clamp(.8, 1.2).toDouble();
    final nextCompact = compact ?? this.compact;
    if (!appearancePalettes.containsKey(nextTheme) ||
        !appearanceFonts.containsKey(nextFont))
      throw ArgumentError('Apariencia no válida');
    final saved = await (await SharedPreferences.getInstance()).setString(
      'appearance.v1',
      jsonEncode({
        'theme': nextTheme,
        'font': nextFont,
        'scale': nextScale,
        'compact': nextCompact,
      }),
    );
    if (!saved) throw StateError('No se pudo guardar la apariencia');
    this.theme = nextTheme;
    this.font = nextFont;
    this.scale = nextScale;
    this.compact = nextCompact;
    notifyListeners();
  }

  Future<void> reset() =>
      update(theme: 'slate', font: 'noto', scale: 1, compact: false);
}
