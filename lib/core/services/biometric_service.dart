import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps `local_auth` for the blind-user unlock flow.
///
/// We only care about three questions:
///   1. Can this device do biometric / device-credential auth at all?
///   2. Did the blind user opt into biometric on first sign-in?
///   3. Run the auth prompt and tell the caller pass/fail.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static const _blindUnlockEnabledKey = 'blind_biometric_enabled';

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return _auth.canCheckBiometrics;
    } catch (error) {
      debugPrint('[BIO] isAvailable error: $error');
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Unlock GuardianEye',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (error) {
      debugPrint('[BIO] authenticate error: $error');
      return false;
    }
  }

  Future<bool> isBlindUnlockEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_blindUnlockEnabledKey}_$uid') ?? false;
  }

  Future<void> setBlindUnlockEnabled(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_blindUnlockEnabledKey}_$uid', enabled);
  }
}
