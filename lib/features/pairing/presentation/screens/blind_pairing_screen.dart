import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/features/pairing/data/models/pairing_handshake.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BlindPairingScreen extends ConsumerStatefulWidget {
  const BlindPairingScreen({super.key});

  @override
  ConsumerState<BlindPairingScreen> createState() => _BlindPairingScreenState();
}

class _BlindPairingScreenState extends ConsumerState<BlindPairingScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _signIn(PairingHandshake handshake) async {
    final ok = await ref
        .read(blindHandshakeSignInControllerProvider.notifier)
        .signInWith(handshake);
    if (!mounted) return;
    if (ok) {
      context.go(RoutePaths.myGuardians);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handshakeIdAsync = ref.watch(startBlindHandshakeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: handshakeIdAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            message: error is AppException
                ? error.message
                : error.toString(),
            onRetry: () => ref.invalidate(startBlindHandshakeProvider),
          ),
          data: (deviceId) =>
              _PairingBody(deviceId: deviceId, onCompleted: _signIn),
        ),
      ),
    );
  }
}

class _PairingBody extends ConsumerWidget {
  const _PairingBody({required this.deviceId, required this.onCompleted});

  final String deviceId;
  final Future<void> Function(PairingHandshake) onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handshakeAsync =
        ref.watch(pairingHandshakeStreamProvider(deviceId));
    final signInState = ref.watch(blindHandshakeSignInControllerProvider);

    ref.listen<AsyncValue<PairingHandshake?>>(
      pairingHandshakeStreamProvider(deviceId),
      (previous, next) {
        final handshake = next.valueOrNull;
        if (handshake != null && handshake.isCompleted) {
          onCompleted(handshake);
        }
      },
    );

    final handshake = handshakeAsync.valueOrNull;
    final isCompleted = handshake?.isCompleted ?? false;
    final isExpired = handshake?.isExpired ?? false;
    final isSigningIn = signInState.isLoading || isCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go(RoutePaths.login),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Pair with your guardian', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Hold your phone up. Your guardian scans this code with their phone — you don’t need to type anything.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                    semanticsLabel:
                        'Hold your phone up. Your guardian will scan the code on your screen with their phone. You do not need to type anything.',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.softShadow,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          label: 'Pairing QR code on screen',
                          excludeSemantics: true,
                          child: Center(
                            child: QrImageView(
                              data: deviceId,
                              version: QrVersions.auto,
                              size: 260,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.textPrimary,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Device code',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          deviceId,
                          style: AppTextStyles.h3.copyWith(letterSpacing: 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatusBanner(
                    isSigningIn: isSigningIn,
                    isExpired: isExpired,
                    signInError: signInState.error,
                  ),
                  const SizedBox(height: 16),
                  if (isExpired)
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(startBlindHandshakeProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh code'),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.isSigningIn,
    required this.isExpired,
    required this.signInError,
  });

  final bool isSigningIn;
  final bool isExpired;
  final Object? signInError;

  @override
  Widget build(BuildContext context) {
    if (signInError != null) {
      final message = signInError is AppException
          ? (signInError as AppException).message
          : signInError.toString();
      return _Banner(
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        title: 'Sign in failed',
        message: message,
      );
    }
    if (isSigningIn) {
      return const _Banner(
        icon: Icons.lock_open_rounded,
        color: AppColors.primary,
        title: 'Signing you in',
        message: 'Your guardian linked your account. One moment…',
        spinning: true,
      );
    }
    if (isExpired) {
      return const _Banner(
        icon: Icons.timer_off_rounded,
        color: AppColors.warning,
        title: 'Code expired',
        message: 'Refresh to get a new code.',
      );
    }
    return const _Banner(
      icon: Icons.hourglass_top_rounded,
      color: AppColors.primary,
      title: 'Waiting for your guardian',
      message: 'Ask them to open the app and scan this screen.',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.spinning = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          spinning
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Could not start pairing',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
