import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/app_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final storage = await AppStorage.getInstance();
    final value = storage.getString(_keyThemeMode);
    switch (value) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final storage = await AppStorage.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await storage.setString(_keyThemeMode, 'light');
      case ThemeMode.dark:
        await storage.setString(_keyThemeMode, 'dark');
      case ThemeMode.system:
        await storage.setString(_keyThemeMode, 'system');
    }
    notifyListeners();
  }

  ThemeMode nextMode(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_themeMode == ThemeMode.system) {
      return brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      return ThemeMode.light;
    } else {
      return ThemeMode.dark;
    }
  }

  IconData get icon {
    switch (_themeMode) {
      case ThemeMode.light:
        return LucideIcons.sun;
      case ThemeMode.dark:
        return LucideIcons.moon;
      case ThemeMode.system:
        return LucideIcons.monitor;
    }
  }

  String get label {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
