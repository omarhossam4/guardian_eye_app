import 'package:flutter/material.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';

/// Premium GuardianEye logo widget with refined glow and typography.
class GuardianLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDark;

  const GuardianLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark || Theme.of(context).brightness == Brightness.dark;
    final double iconSize = size * 0.52;
    final double dotSize = size * 0.12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mark
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3BAEE8),
                Color(0xFF2D9CDB),
                Color(0xFF0F4C81),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D9CDB).withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF0F4C81).withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle inner highlight ring
              Container(
                width: size * 0.88,
                height: size * 0.88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
              // Shield icon
              Icon(
                Icons.shield_rounded,
                size: iconSize,
                color: Colors.white,
              ),
              // White eye dot in center
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.22),
          Text(
            'GuardianEye',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              color: effectiveDark ? Colors.white : const Color(0xFF0F4C81),
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Safety. Vision. Care.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: size * 0.16,
              fontWeight: FontWeight.w500,
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : AppColors.textSecondary.withValues(alpha: 0.85),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}
