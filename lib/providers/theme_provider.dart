import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeProvider(this._prefs)
      : _themeMode = _loadThemeMode(_prefs);

  ThemeMode get themeMode => _themeMode;

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(_themeKey);
    if (value == 'light') return ThemeMode.light;
    if (value == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    
    await _prefs.setString(_themeKey, value);
  }

  Future<void> toggleTheme() async {
    ThemeMode nextMode;
    switch (_themeMode) {
      case ThemeMode.system:
        nextMode = ThemeMode.light;
        break;
      case ThemeMode.light:
        nextMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        nextMode = ThemeMode.system;
        break;
    }
    await setThemeMode(nextMode);
  }
}
