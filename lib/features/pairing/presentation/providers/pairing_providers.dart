// lib/features/pairing/presentation/providers/pairing_providers.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// PURPOSE
// Tracks whether the current Firebase user has already completed pairing.
// Stored in SharedPreferences keyed by uid so it survives cold restarts
// but resets when a different account signs in.
//
// HOW TO USE
// • Router reads `isPairedProvider` to decide where to redirect after login.
// • PairingCodeScreen calls `markPaired()` after a successful code verification.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Shared Preferences instance (singleton) ──────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Override sharedPreferencesProvider in ProviderScope before use.',
  );
});

// ── Pairing notifier ──────────────────────────────────────────────────────────
class PairingNotifier extends StateNotifier<bool> {
  PairingNotifier(this._prefs, this._uid) : super(false) {
    _load();
  }

  final SharedPreferences _prefs;
  final String _uid;

  String get _key => 'is_paired_$_uid';

  void _load() {
    state = _prefs.getBool(_key) ?? false;
  }

  /// Call this once the guardian has entered a valid pairing code.
  Future<void> markPaired() async {
    await _prefs.setBool(_key, true);
    state = true;
  }

  /// Call on logout so the next account starts fresh.
  Future<void> reset() async {
    await _prefs.remove(_key);
    state = false;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
// `uid` is passed as a family parameter so each Firebase user gets its own
// pairing state without sharing between accounts.
final pairingNotifierProvider =
StateNotifierProvider.family<PairingNotifier, bool, String>(
      (ref, uid) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return PairingNotifier(prefs, uid);
  },
);

// Convenience provider: resolves the current user's pairing state.
// Returns false when no user is signed in (safe default).
final isPairedProvider = Provider<bool>((ref) {
  // Import authControllerProvider from auth_providers.dart in your real file.
  // We keep this file import-free of auth to avoid circular deps —
  // the router wires them together (see app_router.dart).
  return false; // overridden in app_router.dart via ref.watch
});