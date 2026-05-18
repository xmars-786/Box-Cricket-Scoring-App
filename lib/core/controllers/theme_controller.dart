import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app theme (system/dark/light mode) with persistence using GetX.
class ThemeController extends GetxController {
  final _themeMode = ThemeMode.system.obs;
  static const String _themeKey = 'theme_mode_v2'; // Changed key to reset for system support

  ThemeMode get themeMode => _themeMode.value;
  
  bool get isDarkMode {
    if (_themeMode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return _themeMode.value == ThemeMode.dark;
  }

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme == 'light') {
      _themeMode.value = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode.value = ThemeMode.dark;
    } else {
      _themeMode.value = ThemeMode.system;
    }
    Get.changeThemeMode(_themeMode.value);
  }

  /// Toggle between dark and light mode (cycles through system if needed or just switches)
  /// User requested manual change to still work fine
  Future<void> toggleTheme() async {
    if (_themeMode.value == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode.value = mode;
    Get.changeThemeMode(mode);
    
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'system';
    if (mode == ThemeMode.dark) themeStr = 'dark';
    if (mode == ThemeMode.light) themeStr = 'light';
    
    await prefs.setString(_themeKey, themeStr);
  }
}
