import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/services/api_service.dart';
import 'package:guardian_eye/core/services/auth_service.dart';
import 'package:guardian_eye/core/services/biometric_service.dart';
import 'package:guardian_eye/core/services/firestore_auth_flow_service.dart';
import 'package:guardian_eye/features/auth/data/models/auth_session_model.dart';
import 'package:guardian_eye/features/auth/data/models/blind_migration_result.dart';
import 'package:guardian_eye/features/auth/data/models/blind_user_profile.dart';
import 'package:guardian_eye/features/auth/data/models/created_blind_credentials.dart';
import 'package:guardian_eye/features/auth/data/models/guardian_firestore_profile.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/guardian/data/models/create_guardian_profile_request.dart';
import 'package:guardian_eye/features/pairing/data/models/pairing_handshake.dart';

final firestoreAuthFlowServiceProvider =
    Provider<FirestoreAuthFlowService>((ref) {
  return FirestoreAuthFlowService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
  );
});

final authApiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(authService: ref.watch(authServiceProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSessionModel?>>((ref) {
  final apiService = ref.read(authApiServiceProvider);
  final controller = AuthController(
    authService: ref.read(authServiceProvider),
    firestoreAuthFlowService: ref.read(firestoreAuthFlowServiceProvider),
    biometricService: ref.read(biometricServiceProvider),
    verifyToken: apiService.verifyToken,
    createGuardianProfile: ({
      required String name,
      String? phoneNumber,
    }) async {
      await apiService.createGuardianProfile(
        CreateGuardianProfileRequest(
          name: name,
          phoneNumber: phoneNumber,
        ),
      );
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class AuthController extends StateNotifier<AsyncValue<AuthSessionModel?>> {
  AuthController({
    required AuthService authService,
    required FirestoreAuthFlowService firestoreAuthFlowService,
    required BiometricService biometricService,
    required Future<void> Function() verifyToken,
    required Future<void> Function({
      required String name,
      String? phoneNumber,
    }) createGuardianProfile,
  })  : _authService = authService,
        _firestoreAuthFlowService = firestoreAuthFlowService,
        _biometricService = biometricService,
        _verifyToken = verifyToken,
        _createGuardianProfileRequest = createGuardianProfile,
        super(const AsyncValue.loading()) {
    _initialize();
  }

  final AuthService _authService;
  final FirestoreAuthFlowService _firestoreAuthFlowService;
  final BiometricService _biometricService;
  final Future<void> Function() _verifyToken;
  final Future<void> Function({
    required String name,
    String? phoneNumber,
  }) _createGuardianProfileRequest;
  StreamSubscription<AuthSessionModel?>? _authSubscription;

  Future<void> _initialize() async {
    try {
      // Both blind users and guardians stay signed in across cold starts.
      // Blind side is gated by biometric; guardian side restores silently
      // — the router decides whether to send them to device-link or
      // dashboard based on their `linked_blind_user_id`.
      final uid = _authService.currentFirebaseUid;
      if (uid != null) {
        try {
          final role = await _firestoreAuthFlowService.resolveRoleForUid(uid);
          if (role == UserRole.blind) {
            final keepSession = await _tryRestoreBlindSession(uid);
            if (keepSession) {
              _subscribeToAuthChanges();
              return;
            }
            // Biometric failed / disabled → fall through to logout.
          } else {
            final session = await _authService.restoreSession();
            if (session != null) {
              state = AsyncValue.data(session);
              _subscribeToAuthChanges();
              return;
            }
          }
        } catch (error) {
          debugPrint('[AUTH] role resolve failed: $error');
          // Unable to resolve role → safer to logout than guess.
        }
      }

      await _authService.logout();
      state = const AsyncValue.data(null);
      _subscribeToAuthChanges();
    } catch (error) {
      debugPrint('[AUTH] initialize error: $error');
      state = const AsyncValue.data(null);
    }
  }

  /// Returns true when a blind-user session was restored (and the caller
  /// should NOT logout). Returns false otherwise (any failure falls back to
  /// the default logout-on-launch behavior).
  Future<bool> _tryRestoreBlindSession(String uid) async {
    try {
      final role = await _firestoreAuthFlowService.resolveRoleForUid(uid);
      if (role != UserRole.blind) return false;

      final enabled = await _biometricService.isBlindUnlockEnabled(uid);
      if (!enabled) return false;

      final passed = await _biometricService.authenticate(
        reason: 'Unlock GuardianEye',
      );
      if (!passed) return false;

      final session = await _authService.restoreSession();
      if (session == null) return false;
      state = AsyncValue.data(session);
      return true;
    } catch (error) {
      debugPrint('[AUTH] blind restore failed: $error');
      return false;
    }
  }

  void _subscribeToAuthChanges() {
    _authSubscription = _authService.authStateChanges().listen(
      (session) {
        state = AsyncValue.data(session);
        _maybeEnableBlindBiometric(session);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[AUTH] stream error: $error');
        state = const AsyncValue.data(null);
      },
    );
  }

  Future<void> _maybeEnableBlindBiometric(AuthSessionModel? session) async {
    if (session == null) return;
    if (session.user.role != UserRole.blind) return;
    try {
      final available = await _biometricService.isAvailable();
      if (!available) return;
      await _biometricService.setBlindUnlockEnabled(session.user.id, true);
    } catch (error) {
      debugPrint('[AUTH] enable biometric failed: $error');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      debugPrint('[AUTH] register start -> email=$email');
      final session = await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: name,
      );
      try {
        await _verifyToken();
      } catch (_) {
        // Keep Firebase session alive; backend verification errors should not
        // force an auth sign-out loop back to login.
        state = AsyncValue.data(session);
        return;
      }
      try {
        await _createGuardianProfile(
          name: session.user.name,
          phoneNumber: session.user.phoneNumber,
        );
      } on AppException catch (error) {
        if (!_isGuardianProfileAlreadyPresent(error)) {
          rethrow;
        }
      }
      debugPrint('[AUTH] register success -> email=${session.user.email}');
      state = AsyncValue.data(session);
    } catch (error, stackTrace) {
      debugPrint('[AUTH] register error -> $error');
      state = AsyncValue.error(error, stackTrace);
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
    }
  }

  Future<void> login({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      debugPrint('[AUTH] login start -> email=$email');
      final session = await _authService.loginWithEmail(
        email: email,
        password: password,
        role: role,
      );
      try {
        await _verifyToken();
      } catch (_) {
        // Keep Firebase session alive; backend verification errors should not
        // force an auth sign-out loop back to login.
        state = AsyncValue.data(session);
        return;
      }
      debugPrint('[AUTH] login success -> email=${session.user.email}');
      state = AsyncValue.data(session);
    } catch (error, stackTrace) {
      debugPrint('[AUTH] login error -> $error');
      state = AsyncValue.error(error, stackTrace);
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
    }
  }

  Future<void> logout() async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();

    try {
      await _authService.logout();
      debugPrint('[AUTH] logout success');
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      debugPrint('[AUTH] logout error -> $error');
      state = AsyncValue.error(error, stackTrace);
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
    }
  }

  Future<void> refreshToken() async {
    final previous = state.valueOrNull;
    if (previous == null) return;

    state = const AsyncValue.loading();

    try {
      final token = await _authService.refreshIdToken();
      if (token == null) throw const AppException('Unable to refresh token.');

      final refreshedSession = await _authService.restoreSession();
      debugPrint(
        '[AUTH] refreshToken success -> tokenPresent=${token.isNotEmpty} '
        'user=${refreshedSession?.user.email ?? previous.user.email}',
      );
      state = AsyncValue.data(refreshedSession ?? previous);
    } catch (error, stackTrace) {
      debugPrint('[AUTH] refreshToken error -> $error');
      state = AsyncValue.error(error, stackTrace);
      state = AsyncValue.data(previous);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _createGuardianProfile({
    required String name,
    String? phoneNumber,
  }) async {
    await _createGuardianProfileRequest(
      name: name,
      phoneNumber: phoneNumber,
    );
  }

  bool _isGuardianProfileAlreadyPresent(AppException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 409 ||
        message.contains('already exists') ||
        message.contains('profile already') ||
        message.contains('duplicate');
  }
}

extension AuthStateX on AsyncValue<AuthSessionModel?> {
  String? get friendlyErrorMessage {
    final err = error;
    if (err is AppException) return err.message;
    return err?.toString();
  }

  bool get isAuthenticated => valueOrNull != null;
}

final currentBlindUserProfileProvider =
    FutureProvider.autoDispose<BlindUserProfile>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const AppException('Please sign in first.');
  }
  if (session.user.role != UserRole.blind) {
    throw const AppException('This account is not a blind user.');
  }
  return ref
      .watch(firestoreAuthFlowServiceProvider)
      .getBlindProfileForCurrentUser();
});

final currentGuardianFirestoreProfileProvider =
    FutureProvider.autoDispose<GuardianFirestoreProfile>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    throw const AppException('Please sign in first.');
  }
  return ref
      .watch(firestoreAuthFlowServiceProvider)
      .getGuardianProfileForCurrentUser();
});

final blindGuardiansProvider =
    FutureProvider.autoDispose<List<GuardianFirestoreProfile>>((ref) async {
  final profile = await ref.watch(currentBlindUserProfileProvider.future);
  if (profile.linkedGuardians.isEmpty) return [];
  return ref
      .read(firestoreAuthFlowServiceProvider)
      .getGuardiansForBlindUser(profile.linkedGuardians);
});

final blindUnlinkGuardianControllerProvider =
    StateNotifierProvider<BlindUnlinkGuardianController, AsyncValue<void>>(
        (ref) {
  return BlindUnlinkGuardianController(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
    readBlindProfile: () => ref.read(currentBlindUserProfileProvider.future),
  );
});

class BlindUnlinkGuardianController extends StateNotifier<AsyncValue<void>> {
  BlindUnlinkGuardianController({
    required FirestoreAuthFlowService firestoreAuthFlowService,
    required Future<BlindUserProfile> Function() readBlindProfile,
  })  : _firestoreAuthFlowService = firestoreAuthFlowService,
        _readBlindProfile = readBlindProfile,
        super(const AsyncValue.data(null));

  final FirestoreAuthFlowService _firestoreAuthFlowService;
  final Future<BlindUserProfile> Function() _readBlindProfile;

  Future<bool> unlinkGuardian(String guardianId) async {
    state = const AsyncValue.loading();
    try {
      final blindProfile = await _readBlindProfile();
      await _firestoreAuthFlowService.unlinkGuardianFromBlindUser(
        blindUser: blindProfile,
        guardianId: guardianId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

final blindMigrationControllerProvider = StateNotifierProvider.autoDispose<
    BlindMigrationController, AsyncValue<List<BlindMigrationResult>>>((ref) {
  return BlindMigrationController(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
  );
});

// ─── Guardian → device-id linking ───────────────────────────────────────
//
// The guardian types or scans the wearable's device id. We look up the
// matching blind_users doc and persist the link on both sides.

/// Streams the current guardian doc so the router can react to link state
/// changes. `isLinked` is true when the guardian has at least one entry in
/// `monitored_users` — guardians can link multiple wearables.
final guardianLinkStateProvider =
    StreamProvider.autoDispose<GuardianLinkState>((ref) {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null || session.user.role != UserRole.guardian) {
    return Stream.value(const GuardianLinkState.unauthenticated());
  }
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('guardians')
      .doc(session.user.id)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return const GuardianLinkState.unlinked();
    final monitored = (snap.data()?['monitored_users'] as List<dynamic>? ??
            const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (monitored.isEmpty) return const GuardianLinkState.unlinked();
    return GuardianLinkState.linked(monitored);
  });
});

class GuardianLinkState {
  const GuardianLinkState._({
    required this.isAuthenticated,
    required this.linkedBlindUserIds,
  });

  const GuardianLinkState.unauthenticated()
      : this._(isAuthenticated: false, linkedBlindUserIds: const <String>[]);
  const GuardianLinkState.unlinked()
      : this._(isAuthenticated: true, linkedBlindUserIds: const <String>[]);
  const GuardianLinkState.linked(List<String> ids)
      : this._(isAuthenticated: true, linkedBlindUserIds: ids);

  final bool isAuthenticated;
  final List<String> linkedBlindUserIds;

  bool get isLinked => linkedBlindUserIds.isNotEmpty;
}

/// Result of a successful link: enough info for the screen to ask the
/// guardian to label the wearable afterwards.
class GuardianLinkResult {
  const GuardianLinkResult({
    required this.blindId,
    required this.defaultLabel,
  });

  final String blindId;
  final String defaultLabel;
}

final guardianDeviceLinkControllerProvider = StateNotifierProvider.autoDispose<
    GuardianDeviceLinkController,
    AsyncValue<GuardianLinkResult?>>((ref) {
  return GuardianDeviceLinkController(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
    readGuardianId: () {
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session == null) {
        throw const AppException('Please sign in first.');
      }
      if (session.user.role != UserRole.guardian) {
        throw const AppException('This action is for guardians only.');
      }
      return session.user.id;
    },
  );
});

class GuardianDeviceLinkController
    extends StateNotifier<AsyncValue<GuardianLinkResult?>> {
  GuardianDeviceLinkController({
    required FirestoreAuthFlowService firestoreAuthFlowService,
    required String Function() readGuardianId,
  })  : _firestoreAuthFlowService = firestoreAuthFlowService,
        _readGuardianId = readGuardianId,
        super(const AsyncValue.data(null));

  final FirestoreAuthFlowService _firestoreAuthFlowService;
  final String Function() _readGuardianId;

  Future<GuardianLinkResult?> linkByDeviceId(String deviceId) async {
    final trimmed = deviceId.trim();
    if (trimmed.isEmpty) {
      state = AsyncValue.error(
        const AppException('Enter a device ID.'),
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncValue.loading();
    try {
      final guardianId = _readGuardianId();
      final blindUser =
          await _firestoreAuthFlowService.findBlindUserByDeviceId(trimmed);
      if (blindUser == null) {
        throw AppException(
          'No wearable matched "$trimmed". Check the code on the device and try again.',
        );
      }
      await _firestoreAuthFlowService.linkGuardianToBlindUser(
        guardianId: guardianId,
        blindUser: blindUser,
        deviceId: trimmed,
      );
      final fallback = blindUser.name.isNotEmpty
          ? blindUser.name
          : 'Wearable $trimmed';
      final result = GuardianLinkResult(
        blindId: blindUser.blindId,
        defaultLabel: fallback,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<bool> saveLabel({
    required String blindId,
    required String label,
  }) async {
    try {
      final guardianId = _readGuardianId();
      await _firestoreAuthFlowService.setMonitoredUserLabel(
        guardianId: guardianId,
        blindId: blindId,
        label: label,
      );
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

// ─── Pairing handshake providers ─────────────────────────────────────────
// Blind side: opens a fresh handshake, displays the device id as a QR, and
// listens to the doc until the guardian fills in credentials.
// Guardian side: scans the blind user's QR and completes the handshake.

/// Blind-side: kicks off a new handshake doc and returns its device id.
/// The widget watches this once and then renders the QR for [deviceId].
final startBlindHandshakeProvider =
    FutureProvider.autoDispose<String>((ref) async {
  return ref
      .read(firestoreAuthFlowServiceProvider)
      .startPairingHandshake();
});

/// Blind-side: streams a specific handshake doc so the screen can react when
/// the guardian completes it.
final pairingHandshakeStreamProvider = StreamProvider.autoDispose
    .family<PairingHandshake?, String>((ref, deviceId) {
  return ref
      .read(firestoreAuthFlowServiceProvider)
      .watchPairingHandshake(deviceId);
});

/// Blind-side helper: sign in with the delivered credentials, then delete
/// the handshake doc. Exposed as a controller so the UI can show loading and
/// error states without juggling its own state.
final blindHandshakeSignInControllerProvider = StateNotifierProvider
    .autoDispose<BlindHandshakeSignInController, AsyncValue<bool>>((ref) {
  return BlindHandshakeSignInController(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
    login: ({required String email, required String password}) =>
        ref.read(authControllerProvider.notifier).login(
              email: email,
              password: password,
              role: UserRole.blind,
            ),
  );
});

class BlindHandshakeSignInController extends StateNotifier<AsyncValue<bool>> {
  BlindHandshakeSignInController({
    required FirestoreAuthFlowService firestoreAuthFlowService,
    required Future<void> Function({
      required String email,
      required String password,
    }) login,
  })  : _firestoreAuthFlowService = firestoreAuthFlowService,
        _login = login,
        super(const AsyncValue.data(false));

  final FirestoreAuthFlowService _firestoreAuthFlowService;
  final Future<void> Function({
    required String email,
    required String password,
  }) _login;
  bool _redeemed = false;

  Future<bool> signInWith(PairingHandshake handshake) async {
    if (_redeemed) return true;
    _redeemed = true;
    state = const AsyncValue.loading();
    try {
      await _login(email: handshake.email, password: handshake.password);
      _firestoreAuthFlowService
          .deletePairingHandshake(handshake.deviceId)
          .ignore();
      state = const AsyncValue.data(true);
      return true;
    } catch (error, stackTrace) {
      _redeemed = false;
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

/// Guardian-side: scan a blind device's QR and create the blind account.
final guardianCompleteHandshakeControllerProvider = StateNotifierProvider
    .autoDispose<GuardianCompleteHandshakeController,
        AsyncValue<CreatedBlindCredentials?>>((ref) {
  return GuardianCompleteHandshakeController(
    firestoreAuthFlowService: ref.watch(firestoreAuthFlowServiceProvider),
    readGuardianId: () {
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session == null) {
        throw const AppException('Please sign in as a guardian first.');
      }
      if (session.user.role != UserRole.guardian) {
        throw const AppException('Only guardians can add a care recipient.');
      }
      return session.user.id;
    },
  );
});

class GuardianCompleteHandshakeController
    extends StateNotifier<AsyncValue<CreatedBlindCredentials?>> {
  GuardianCompleteHandshakeController({
    required FirestoreAuthFlowService firestoreAuthFlowService,
    required String Function() readGuardianId,
  })  : _firestoreAuthFlowService = firestoreAuthFlowService,
        _readGuardianId = readGuardianId,
        super(const AsyncValue.data(null));

  final FirestoreAuthFlowService _firestoreAuthFlowService;
  final String Function() _readGuardianId;

  Future<CreatedBlindCredentials?> complete({
    required String deviceId,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final guardianId = _readGuardianId();
      final credentials =
          await _firestoreAuthFlowService.completePairingHandshake(
        deviceId: deviceId,
        guardianId: guardianId,
        blindName: name,
      );
      state = AsyncValue.data(credentials);
      return credentials;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

class BlindMigrationController
    extends StateNotifier<AsyncValue<List<BlindMigrationResult>>> {
  BlindMigrationController({
    required FirestoreAuthFlowService firestoreAuthFlowService,
  })  : _firestoreAuthFlowService = firestoreAuthFlowService,
        super(const AsyncValue.data(<BlindMigrationResult>[]));

  final FirestoreAuthFlowService _firestoreAuthFlowService;

  Future<void> runMigration({String defaultPassword = 'Blind@1234'}) async {
    state = const AsyncValue.loading();
    try {
      final results = await _firestoreAuthFlowService.migrateBlindUsers(
        defaultPassword: defaultPassword,
      );
      state = AsyncValue.data(results);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
