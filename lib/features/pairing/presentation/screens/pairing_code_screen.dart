import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/features/guardian/presentation/providers/guardian_providers.dart';
import 'package:guardian_eye/features/pairing/presentation/providers/pairing_providers.dart';
import 'package:guardian_eye/shared/widgets/primary_button.dart';

class PairingCodeScreen extends ConsumerStatefulWidget {
  const PairingCodeScreen({super.key});

  @override
  ConsumerState<PairingCodeScreen> createState() =>
      _PairingCodeScreenState();
}

class _PairingCodeScreenState extends ConsumerState<PairingCodeScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _isLoading = false;
  bool _hasError = false;
  bool _isFocused = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _codeFocusNode.addListener(() {
      setState(() => _isFocused = _codeFocusNode.hasFocus);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String get _code => _codeController.text.trim().toUpperCase();

  Future<void> _handleVerify() async {
    if (_code.length < 4 || _isLoading) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again.')),
        );
        context.go(RoutePaths.login);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await ref
          .read(guardianDashboardProvider.notifier)
          .linkUser(userUniqueId: _code);
      await ref
          .read(pairingNotifierProvider(session.user.id).notifier)
          .markPaired();

      if (!mounted) return;
      context.go(RoutePaths.profile);
    } catch (error) {
      if (!mounted) return;
      await _shakeController.forward(from: 0);
      if (!mounted) return;
      setState(() => _hasError = true);
      final message =
          error is AppException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearAll() {
    _codeController.clear();
    setState(() => _hasError = false);
    _codeFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned(
            top: -110,
            right: -70,
            child: _Blob(
                size: 300, color: AppColors.primary, opacity: 0.07),
          ),
          const Positioned(
            bottom: 80,
            left: -70,
            child: _Blob(
              size: 200,
              color: AppColors.primaryLight,
              opacity: 0.09,
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _BackButton(
                        onTap: () => context.go(RoutePaths.profile),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(28, 12, 28, 36),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Icon hero
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF3BAEE8),
                                  Color(0xFF2D9CDB),
                                  Color(0xFF0F4C81),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.32),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.link_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 28),

                          Text(
                            'Link A Device',
                            style: AppTextStyles.h1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Enter the monitored user unique ID\n(e.g. BLIND001 or USER-AB1234).',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 36),

                          // Code input
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration:
                                    const Duration(milliseconds: 200),
                                style: AppTextStyles.label.copyWith(
                                  color: _hasError
                                      ? AppColors.error
                                      : _isFocused
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: const Text('User Unique ID'),
                              ),
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _shakeAnim,
                                builder: (context, child) =>
                                    Transform.translate(
                                  offset: Offset(_shakeAnim.value, 0),
                                  child: child,
                                ),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: _isFocused
                                        ? [
                                            BoxShadow(
                                              color: (_hasError
                                                      ? AppColors.error
                                                      : AppColors.primary)
                                                  .withValues(alpha: 0.12),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: TextField(
                                    controller: _codeController,
                                    focusNode: _codeFocusNode,
                                    onChanged: (_) =>
                                        setState(() => _hasError = false),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    keyboardType: TextInputType.text,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9\-_]'),
                                      ),
                                      LengthLimitingTextInputFormatter(24),
                                    ],
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'BLIND001',
                                      filled: true,
                                      fillColor: _isFocused
                                          ? AppColors.surface
                                          : AppColors.surfaceVariant,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _isFocused
                                                ? AppColors.primary
                                                    .withValues(alpha: 0.10)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.qr_code_rounded,
                                            size: 18,
                                            color: _isFocused
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(minWidth: 0),
                                      hintStyle:
                                          AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textHint,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                            color: AppColors.border,
                                            width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _hasError
                                              ? AppColors.error
                                              : AppColors.border,
                                          width: _hasError ? 1.5 : 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _hasError
                                              ? AppColors.error
                                              : AppColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_hasError) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 14,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Failed to link — check the ID and try again.',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 32),

                          PrimaryButton(
                            text: 'Verify & Connect',
                            onPressed: _code.length >= 4 && !_isLoading
                                ? _handleVerify
                                : null,
                            isLoading: _isLoading,
                            icon: Icons.verified_rounded,
                          ),

                          const SizedBox(height: 12),

                          TextButton.icon(
                            onPressed: _clearAll,
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            label: Text(
                              'Clear',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
