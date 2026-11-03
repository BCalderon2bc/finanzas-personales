import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales aisladas por usuario y versión del recorrido.
class GuideProgress {
  GuideProgress(this.userId);
  final String userId;
  String get _prefix => 'mi_billete.guide.v1.$userId';
  static final Map<String, Object> _memory = {};

  Future<Object?> _read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).get(key) ?? _memory[key];
    } catch (_) {
      return _memory[key];
    }
  }

  Future<void> _write(String key, Object value) async {
    _memory[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      }
      if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (_) {
      /* La guía continúa si el dispositivo bloquea preferencias. */
    }
  }

  Future<bool> get welcomeSeen async => await _read('$_prefix.welcome') == true;
  Future<void> markWelcome() => _write('$_prefix.welcome', true);
  Future<bool> completed(String topic) async =>
      await _read('$_prefix.$topic.done') == true;
  Future<String?> resumeAt(String topic) async {
    final value = await _read('$_prefix.$topic.step');
    return value is String ? value : null;
  }

  Future<void> saveStep(String topic, String step) =>
      _write('$_prefix.$topic.step', step);
  Future<void> complete(String topic) => _write('$_prefix.$topic.done', true);
  Future<void> restart(String topic) async {
    await _write('$_prefix.$topic.done', false);
    await _write('$_prefix.$topic.step', '');
  }
}
