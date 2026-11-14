import 'package:material_ui/material_ui.dart';

import '../core/storage/stores.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';
  final KeyValueStore _store;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeController(this._store) {
    _mode = switch (_store.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _store.setString(_key, mode.name);
  }

  /// Quick toggle: flips between light and dark based on what is currently
  /// on screen. "System" is chosen from the menu / settings page.
  Future<void> toggle(Brightness current) =>
      setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}
