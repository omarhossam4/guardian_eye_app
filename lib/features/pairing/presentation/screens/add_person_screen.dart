import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/shared/widgets/custom_text_field.dart';
import 'package:guardian_eye/shared/widgets/primary_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Post-auth screen the guardian lands on if they're not yet linked to a
/// wearable. Two ways to link:
///   • Type the device id printed on the wearable.
///   • Scan the QR code printed on the wearable.
///
/// On success the router redirects to the guardian home (see app_router.dart),
/// because `linked_blind_user_id` flips from null to a value.
class AddPersonScreen extends ConsumerStatefulWidget {
  const AddPersonScreen({super.key});

  @override
  ConsumerState<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends ConsumerState<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  MobileScannerController? _scanner;
  bool _isScanning = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit({String? overrideId}) async {
    if (_isProcessing) return;
    final raw = (overrideId ?? _deviceIdController.text).trim();
    if (raw.isEmpty) {
      if (overrideId == null) {
        _formKey.currentState?.validate();
      }
      return;
    }

    setState(() => _isProcessing = true);
    debugPrint('[LINK] handleSubmit start for "$raw"');

    GuardianLinkResult? result;
    try {
      result = await ref
          .read(guardianDeviceLinkControllerProvider.notifier)
          .linkByDeviceId(raw);
    } catch (error, stack) {
      // linkByDeviceId already maps errors into controller state, but guard
      // here too so an unexpected throw can never strand us in loading.
      debugPrint('[LINK] linkByDeviceId threw: $error\n$stack');
      result = null;
    }
    debugPrint('[LINK] linkByDeviceId returned: ${result?.blindId ?? 'null'}');
    if (!mounted) return;

    if (result != null) {
      // Stop the camera, but NEVER let it block the success flow — on some
      // devices MobileScanner.stop() can stall, which previously left the
      // screen stuck in "Linking…" with no dialog and no error even though
      // the link had already succeeded. Fire and forget.
      unawaited(_safeStopScanner());
      // Ask the guardian what to call this wearable. Skipping (cancel) is
      // allowed — the link is already saved; only the label is optional.
      await _promptForLabel(result);
      if (!mounted) return;
      debugPrint('[LINK] navigating to guardian home');
      context.go(RoutePaths.guardianHome);
      return;
    }

    final error = ref.read(guardianDeviceLinkControllerProvider).error;
    final message = error is AppException
        ? error.message
        : (error?.toString() ?? 'Could not link this device.');
    debugPrint('[LINK] link failed: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (mounted) setState(() => _isProcessing = false);
    if (overrideId != null) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      try {
        await _scanner?.start();
      } catch (error) {
        debugPrint('[LINK] scanner restart failed: $error');
      }
    }
  }

  /// Stops the camera without ever throwing or hanging the caller.
  Future<void> _safeStopScanner() async {
    try {
      await _scanner?.stop().timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('[LINK] scanner stop failed/slow (ignored): $error');
    }
  }

  Future<void> _promptForLabel(GuardianLinkResult linkResult) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LabelDialog(linkResult: linkResult),
    );
  }

  void _openScanner() {
    _scanner ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    setState(() => _isScanning = true);
  }

  Future<void> _closeScanner() async {
    await _safeStopScanner();
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    HapticFeedback.lightImpact();
    _deviceIdController.text = raw;
    await _handleSubmit(overrideId: raw);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isScanning,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isScanning) await _closeScanner();
      },
      child: Scaffold(
        backgroundColor: _isScanning ? Colors.black : AppColors.background,
        body: SafeArea(
          top: !_isScanning,
          child: _isScanning ? _buildScanner() : _buildForm(),
        ),
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    final isLoading =
        ref.watch(guardianDeviceLinkControllerProvider).isLoading ||
            _isProcessing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Builder(builder: (context) {
                final linkState =
                    ref.watch(guardianLinkStateProvider).valueOrNull;
                final hasExistingLinks = linkState?.isLinked ?? false;
                return GestureDetector(
                  onTap: () async {
                    if (hasExistingLinks) {
                      // Guardian already has wearables — back to dashboard.
                      context.go(RoutePaths.guardianHome);
                      return;
                    }
                    // Zero links → only way out is to sign out.
                    await ref.read(authControllerProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go(RoutePaths.login);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      hasExistingLinks
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.logout_rounded,
                      size: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 16),
              Text('Link a wearable', style: AppTextStyles.h3),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.devices_other_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connect to a wearable device',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Type the device ID printed on the wearable, or scan the QR code on the device.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomTextField(
                    label: 'Device ID',
                    hint: 'e.g. 123456',
                    controller: _deviceIdController,
                    prefixIcon: Icons.qr_code_2_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'Connect',
                    onPressed: isLoading ? null : () => _handleSubmit(),
                    isLoading: isLoading,
                    icon: Icons.link_rounded,
                  ),
                  const SizedBox(height: 14),
                  const _OrSeparator(),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _openScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan the wearable QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Scanner ─────────────────────────────────────────────────────────────
  Widget _buildScanner() {
    final scanner = _scanner!;
    return Stack(
      children: [
        MobileScanner(controller: scanner, onDetect: _onDetect),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: GestureDetector(
              onTap: _closeScanner,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Point the camera at the device QR',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The wearable will sign you in once it is recognized.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Linking…',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OrSeparator extends StatelessWidget {
  const _OrSeparator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Self-contained dialog that owns its TextEditingController via the State's
/// lifecycle. The previous version created the controller in the parent
/// async scope and disposed it the moment `showDialog` returned — that
/// disposed it mid-exit-animation, while the TextField was still reading
/// from it, triggering "TextEditingController was used after being disposed".
class _LabelDialog extends ConsumerStatefulWidget {
  const _LabelDialog({required this.linkResult});

  final GuardianLinkResult linkResult;

  @override
  ConsumerState<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends ConsumerState<_LabelDialog> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.linkResult.defaultLabel);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = 'Enter a name');
      return;
    }
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    final ok = await ref
        .read(guardianDeviceLinkControllerProvider.notifier)
        .saveLabel(
          blindId: widget.linkResult.blindId,
          label: value,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the name.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Text('Name this wearable', style: AppTextStyles.h3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a name you will recognize on your dashboard. Only you see this — other guardians can pick their own name.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Mom, Dad, Sara',
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Skip',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
