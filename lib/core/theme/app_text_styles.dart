import 'package:flutter/material.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Inter';
  static const TextStyle _baseStyle = TextStyle(fontFamily: fontFamily);

  // --- Display Styles ---
  static TextStyle get displayLarge => _baseStyle.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get display => _baseStyle.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: AppColors.textPrimary,
      );

  // --- Heading Styles ---
  static TextStyle get h1 => _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => _baseStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => _baseStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get h4 => _baseStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: AppColors.textPrimary,
      );

  // --- Body Styles ---
  static TextStyle get bodyLarge => _baseStyle.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => _baseStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => _baseStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  // --- Specialized ---
  static TextStyle get label => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSmall => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get button => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
      );

  static TextStyle get caption => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.4,
      );

  static TextStyle get overline => _baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.4,
        height: 1.4,
      );

  // --- Aliases for backward-compat ---
  static TextStyle get heading2 => h2;
  static TextStyle get heading3 => h3;
  static TextStyle get heading4 => h4;
  static TextStyle get body1 => bodyLarge;
  static TextStyle get body2 => bodyMedium;
  static TextStyle get subtitle1 => h3;
  static TextStyle get buttonSmall =>
      caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2);
}
