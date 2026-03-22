import 'package:flutter/material.dart';

/// A simple ChangeNotifier that holds the current theme mode.
class ThemeNotifier extends ChangeNotifier {
  bool _isDark;
  ThemeNotifier({bool isDark = true}) : _isDark = isDark;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
  }
}
