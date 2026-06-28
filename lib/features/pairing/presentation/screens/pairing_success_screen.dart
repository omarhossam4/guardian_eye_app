import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/shared/widgets/primary_button.dart';

class PairingSuccessScreen extends StatefulWidget {
  const PairingSuccessScreen({super.key});

  @override
  State<PairingSuccessScreen> createState() => _PairingSuccessScreenState();
}

class _PairingSuccessScreenState extends State<PairingSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _rippleCtrl;

  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bounceCtrl,
          curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

    _bounceCtrl.forward().then((_) => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background blobs ──
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.success.withValues(alpha: 0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Animated success icon with ripple ──
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_bounceCtrl, _fadeCtrl, _rippleCtrl]),
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ripple rings
                            ...List.generate(3, (i) {
                              final delay = i * 0.33;
                              final progress =
                              (_rippleAnim.value - delay).clamp(0.0, 1.0);
                              return Transform.scale(
                                scale: 0.5 + progress * 0.8,
                                child: Opacity(
                                  opacity: (1 - progress) * 0.25,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // Main icon
                            Transform.scale(
                              scale: _scaleAnim.value,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2ECC71),
                                      AppColors.success
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success.withValues(alpha: 0.4),
                                      blurRadius: 32,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Text content ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Text(
                          'Connected!',
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You are now connected and can start\ntracking in real-time.',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // ── Connected user card ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryLight
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('S',
                                      style: AppTextStyles.h3.copyWith(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Sarah Johnson',
                                        style: AppTextStyles.h3),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                              color: AppColors.online,
                                              shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('Online · Just connected',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                color: AppColors.online)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Buttons ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        PrimaryButton(
                          text: 'Go to Dashboard',
                          onPressed: () => context.go(RoutePaths.guardianHome),
                          icon: Icons.home_rounded,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          text: 'Add Another Person',
                          onPressed: () =>
                              context.go(RoutePaths.pairingCode),
                          isOutlined: true,
                          icon: Icons.person_add_alt_1_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}