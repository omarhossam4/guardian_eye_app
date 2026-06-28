import 'package:flutter/material.dart';

class AppColors {
  static bool isDark = false;

  // Primary Colors - GuardianEye Brand
  static const Color primary = Color(0xFF2D9CDB);
  static const Color primaryLight = Color(0xFF56CCF2);
  static const Color primaryDark = Color(0xFF0F4C81);

  // Secondary Colors
  static const Color secondary = Color(0xFF0F4C81);
  static const Color secondaryLight = Color(0xFF1A6BB3);
  static const Color secondaryDark = Color(0xFF0A3459);

  // Accent Colors
  static const Color accent = Color(0xFF56CCF2);
  static const Color accentLight = Color(0xFF7DD8F5);
  static const Color accentDark = Color(0xFF2D9CDB);

  // Neutral Colors
  static Color get background => isDark ? darkBackground : const Color(0xFFF4F7FB);
  static Color get surface => isDark ? darkSurface : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => isDark ? darkSurfaceVariant : const Color(0xFFEDF1F7);
  static const Color surfaceTray = Color(0xFFF8FAFE);

  // Text Colors
  static Color get textPrimary => isDark ? darkTextPrimary : const Color(0xFF0F4C81);
  static Color get textSecondary => isDark ? darkTextSecondary : const Color(0xFF5A7A99);
  static const Color textHint = Color(0xFF8BA4BD);
  static const Color textDisabled = Color(0xFFB4C5D4);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF27AE60);
  static const Color successLight = Color(0xFFD4F0E1);
  static const Color error = Color(0xFFEB5757);
  static const Color errorLight = Color(0xFFFDEDED);
  static const Color warning = Color(0xFFF2994A);
  static const Color warningLight = Color(0xFFFEF0E6);
  static const Color info = Color(0xFF2D9CDB);

  // Status Colors
  static const Color online = Color(0xFF27AE60);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color lowBattery = Color(0xFFF2994A);
  static const Color sos = Color(0xFFEB5757);

  // Map Colors
  static const Color mapMarkerGuardian = Color(0xFF2D9CDB);
  static const Color mapMarkerImpaired = Color(0xFF0F4C81);
  static const Color mapTrail = Color(0xFF56CCF2);
  static const Color mapGeofence = Color(0xFF27AE60);

  // Border Colors
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color textTertiary = Color(0xFF8BA4BD);
  static Color get border => isDark ? darkSurfaceVariant : const Color(0xFFDFE8F0);
  static Color get borderLight => isDark ? darkSurfaceVariant : const Color(0xFFF0F4F8);
  static Color get divider => isDark ? const Color(0xFF1F3A56) : const Color(0xFFE8EDF4);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF07111F);
  static const Color darkSurface = Color(0xFF0D1F33);
  static const Color darkSurfaceVariant = Color(0xFF152D47);
  static const Color darkTextPrimary = Color(0xFFF0F4F8);
  static const Color darkTextSecondary = Color(0xFF7A9AB8);

  // --- Gradients ---

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2D9CDB), Color(0xFF1A7FBF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDeep = LinearGradient(
    colors: [Color(0xFF1A7FBF), Color(0xFF0F4C81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF0F4C81), Color(0xFF2D9CDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A3459), Color(0xFF0F4C81), Color(0xFF2D9CDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleSkyGradient = LinearGradient(
    colors: [Color(0xFFF0F7FF), Color(0xFFF4F9FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Shadows ---

  /// Ambient soft shadow for cards
  static List<BoxShadow>? get cardShadow => isDark ? null : [
        BoxShadow(
          color: const Color(0xFF0F4C81).withValues(alpha: 0.06),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F4C81).withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Pronounced shadow for primary action buttons
  static List<BoxShadow>? get buttonShadow => isDark ? null : [
        BoxShadow(
          color: const Color(0xFF2D9CDB).withValues(alpha: 0.38),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F4C81).withValues(alpha: 0.14),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Light ambient lift for nav bars / headers
  static List<BoxShadow>? get elevatedShadow => isDark ? null : [
        BoxShadow(
          color: const Color(0xFF0F4C81).withValues(alpha: 0.10),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  /// Very soft shadow for subtle lift
  static List<BoxShadow>? get softShadow => isDark ? null : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  /// Deep dramatic shadow for hero elements
  static List<BoxShadow>? get deepShadow => isDark ? null : [
        BoxShadow(
          color: const Color(0xFF0F4C81).withValues(alpha: 0.20),
          blurRadius: 40,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Icon container backgrounds
  static Color iconBg(Color color) => color.withValues(alpha: 0.10);
  static Color iconBgStrong(Color color) => color.withValues(alpha: 0.16);
}
