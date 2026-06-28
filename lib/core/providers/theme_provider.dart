import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guardian_eye/core/theme/app_colors.dart';

const _kDarkModeKey = 'dark_mode_enabled';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = _prefs;
    final isDark = prefs.getBool(_kDarkModeKey) ?? false;
    AppColors.isDark = isDark;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool value) async {
    AppColors.isDark = value;
    state = value ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_kDarkModeKey, value);
  }

  bool get isDark => state == ThemeMode.dark;

  SharedPreferences get _prefs => GetIt.instance<SharedPreferences>();
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
