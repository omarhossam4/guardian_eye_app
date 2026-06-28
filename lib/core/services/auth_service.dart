import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guardian_eye/core/constants/app_constants.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/services/firestore_auth_flow_service.dart';
import 'package:guardian_eye/features/auth/data/models/auth_session_model.dart';
import 'package:guardian_eye/features/auth/data/models/user_model.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';

class AuthService {
  AuthService({
    fb.FirebaseAuth? firebaseAuth,
    FlutterSecureStorage? secureStorage,
    FirestoreAuthFlowService? firestoreAuthFlowService,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _firestoreAuthFlowService =
            firestoreAuthFlowService ?? FirestoreAuthFlowService();

  final fb.FirebaseAuth _firebaseAuth;
  final FlutterSecureStorage _secureStorage;
  final FirestoreAuthFlowService _firestoreAuthFlowService;

  String? get currentFirebaseUid => _firebaseAuth.currentUser?.uid;

  Stream<AuthSessionModel?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        await clearSession();
        return null;
      }

      try {
        return await _buildAndPersistSession(firebaseUser);
      } catch (_) {
        final storedRole = await _readStoredRole();
        return _buildFallbackSession(
          firebaseUser,
          role: storedRole ?? UserRole.guardian,
        );
      }
    });
  }

  Future<AuthSessionModel?> restoreSession() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      return await _buildAndPersistSession(firebaseUser);
    } catch (_) {
      final storedRole = await _readStoredRole();
      return _buildFallbackSession(
        firebaseUser,
        role: storedRole ?? UserRole.guardian,
      );
    }
  }

  Future<AuthSessionModel> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AppException('Unable to create Firebase user.');
      }

      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.reload();

      try {
        return await _buildAndPersistSession(_firebaseAuth.currentUser!);
      } on AppException {
        return _buildFallbackSession(
          _firebaseAuth.currentUser!,
          role: UserRole.guardian,
        );
      }
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Registration failed.',
        code: error.code,
      );
    }
  }

  Future<AuthSessionModel> loginWithEmail({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    // Persist the intended role BEFORE Firebase signs in so the authStateChanges
    // stream handler can read it as a fallback if Firestore lookup fails.
    if (role != null) {
      await _persistRole(role);
    }
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AppException('Unable to sign in user.');
      }

      return _buildAndPersistSession(firebaseUser);
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Login failed.',
        code: error.code,
      );
    }
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(AuthSessionModel session) onVerificationCompleted,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          final result = await _firebaseAuth.signInWithCredential(credential);
          final user = result.user;
          if (user == null) {
            throw const AppException(
                'Phone verification did not return a user.');
          }
          final session = await _buildAndPersistSession(user);
          onVerificationCompleted(session);
        },
        verificationFailed: (error) {
          throw AppException(
            error.message ?? 'Phone verification failed.',
            code: error.code,
          );
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (_) {},
      );
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Unable to send verification code.',
        code: error.code,
      );
    }
  }

  Future<AuthSessionModel> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AppException('Phone sign in failed.');
      }

      return _buildAndPersistSession(user);
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Invalid SMS code.',
        code: error.code,
      );
    }
  }

  Future<String?> getStoredToken() {
    return _secureStorage.read(key: AppConstants.secureTokenKey);
  }

  Future<String?> getValidIdToken({bool forceRefresh = false}) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    final tokenResult = await firebaseUser.getIdTokenResult(forceRefresh);
    final expirationTime = tokenResult.expirationTime;
    final expiresSoon = expirationTime != null &&
        expirationTime.isBefore(
          DateTime.now().add(const Duration(minutes: 5)),
        );

    final token = expiresSoon && !forceRefresh
        ? await firebaseUser.getIdToken(true)
        : tokenResult.token;

    if (token == null) {
      return null;
    }

    await _persistToken(
      token: token,
      expiresAt: expirationTime,
      refreshAt: expiresSoon ? DateTime.now() : expirationTime,
    );

    return token;
  }

  Future<String?> refreshIdToken() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    final token = await firebaseUser.getIdToken(true);
    final tokenResult = await firebaseUser.getIdTokenResult();
    await _persistToken(
      token: token ?? '',
      expiresAt: tokenResult.expirationTime,
      refreshAt: DateTime.now(),
    );
    return token;
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await clearSession();
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: AppConstants.secureTokenKey);
    await _secureStorage.delete(key: AppConstants.secureTokenExpiryKey);
    await _secureStorage.delete(key: AppConstants.secureRefreshAtKey);
    await _secureStorage.delete(key: AppConstants.userRoleKey);
  }

  Future<AuthSessionModel> _buildAndPersistSession(fb.User firebaseUser) async {
    final tokenResult = await firebaseUser.getIdTokenResult();
    final token =
        tokenResult.token ?? await firebaseUser.getIdToken() ?? await getStoredToken();

    UserRole role;
    try {
      role = await _firestoreAuthFlowService.resolveRoleForUid(firebaseUser.uid);
      // Persist the Firestore-confirmed role so future fallbacks are accurate.
      await _persistRole(role);
    } catch (_) {
      final stored = await _readStoredRole();
      if (stored == null) rethrow;
      role = stored;
    }

    final session = _buildFallbackSession(
      firebaseUser,
      role: role,
      token: token ?? '',
      expiresAt: tokenResult.expirationTime,
      lastRefreshAt: DateTime.now(),
    );

    if (token != null && token.isNotEmpty) {
      await _persistToken(
        token: token,
        expiresAt: tokenResult.expirationTime,
        refreshAt: DateTime.now(),
      );
    }

    return session;
  }

  Future<void> _persistRole(UserRole role) async {
    await _secureStorage.write(
      key: AppConstants.userRoleKey,
      value: role.name,
    );
  }

  Future<UserRole?> _readStoredRole() async {
    final raw = await _secureStorage.read(key: AppConstants.userRoleKey);
    if (raw == null) return null;
    try {
      return UserRole.values.firstWhere((r) => r.name == raw);
    } catch (_) {
      return null;
    }
  }

  AuthSessionModel _buildFallbackSession(
    fb.User firebaseUser, {
    UserRole role = UserRole.guardian,
    String token = '',
    DateTime? expiresAt,
    DateTime? lastRefreshAt,
  }) {
    final user = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName?.trim().isNotEmpty == true
          ? firebaseUser.displayName!.trim()
          : _fallbackName(firebaseUser),
      photoUrl: firebaseUser.photoURL,
      phoneNumber: firebaseUser.phoneNumber,
      role: role,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: firebaseUser.metadata.lastSignInTime ?? DateTime.now(),
    );

    return AuthSessionModel(
      user: user,
      idToken: token,
      expiresAt: expiresAt,
      lastRefreshAt: lastRefreshAt,
    );
  }

  Future<void> _persistToken({
    required String token,
    DateTime? expiresAt,
    DateTime? refreshAt,
  }) async {
    await _secureStorage.write(
      key: AppConstants.secureTokenKey,
      value: token,
    );

    if (expiresAt != null) {
      await _secureStorage.write(
        key: AppConstants.secureTokenExpiryKey,
        value: expiresAt.toIso8601String(),
      );
    }

    if (refreshAt != null) {
      await _secureStorage.write(
        key: AppConstants.secureRefreshAtKey,
        value: refreshAt.toIso8601String(),
      );
    }
  }

  String _fallbackName(fb.User firebaseUser) {
    final email = firebaseUser.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return firebaseUser.phoneNumber ?? 'User';
  }
}
