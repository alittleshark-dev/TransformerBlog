import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全站主题设置：深浅色模式与主色调。
///
/// 设置保存在本地（Web 上就是 localStorage），只对当前浏览器生效。
/// 想让所有访客看到同一个配色，需要把颜色写进代码或配置里。
class AppSettings extends ChangeNotifier {
  static const Color defaultSeedColor = Color(0xFF2196F3);
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  static const String _seedColorKey = 'seedColor';
  static const String _themeModeKey = 'themeMode';

  Color _seedColor = defaultSeedColor;
  ThemeMode _themeMode = defaultThemeMode;

  Color get seedColor => _seedColor;
  ThemeMode get themeMode => _themeMode;

  /// 是否改过配色，用于决定要不要显示「恢复默认」。
  bool get isCustomized =>
      _seedColor != defaultSeedColor || _themeMode != defaultThemeMode;

  /// 读取上次保存的设置，读不到就保持默认值。
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? colorValue = prefs.getInt(_seedColorKey);
      final String? modeName = prefs.getString(_themeModeKey);

      bool changed = false;
      if (colorValue != null) {
        _seedColor = Color(colorValue);
        changed = true;
      }
      if (modeName != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (ThemeMode mode) => mode.name == modeName,
          orElse: () => defaultThemeMode,
        );
        changed = true;
      }
      if (changed) notifyListeners();
    } on Exception {
      // 读取失败不影响页面显示，继续用默认值
    }
  }

  /// 修改主色调。[persist] 为 false 时只改内存，用于拖动滑块时的实时预览。
  Future<void> setSeedColor(Color color, {bool persist = true}) async {
    if (color != _seedColor) {
      _seedColor = color;
      notifyListeners();
    }
    if (!persist) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_seedColorKey, color.toARGB32());
    } on Exception {
      // 保存失败不影响当前会话
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    final ThemeMode mode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } on Exception {
      // 保存失败不影响当前会话
    }
  }

  Future<void> resetTheme() async {
    _seedColor = defaultSeedColor;
    _themeMode = defaultThemeMode;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_seedColorKey);
      await prefs.remove(_themeModeKey);
    } on Exception {
      // 保存失败不影响当前会话
    }
  }
}
