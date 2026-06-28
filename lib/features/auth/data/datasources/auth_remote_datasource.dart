import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/features/auth/data/models/user_model.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String email, String password, String name);
  Future<void> logout();
  Future<UserModel> getCurrentUser();
  Future<void> updateUserRole(String userId, UserRole role);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({fb.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _firebaseAuth;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _userModelFromFirebase(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AppException(_mapAuthError(e.code), code: e.code);
    }
  }

  @override
  Future<UserModel> register(
      String email, String password, String name) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();
      return _userModelFromFirebase(_firebaseAuth.currentUser!);
    } on fb.FirebaseAuthException catch (e) {
      throw AppException(_mapAuthError(e.code), code: e.code);
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AppException('No authenticated user.');
    return _userModelFromFirebase(user);
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    // Role updates are handled via Firestore in the backend.
  }

  UserModel _userModelFromFirebase(fb.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : _nameFromEmail(user.email),
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      role: UserRole.guardian,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      updatedAt: user.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  String _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return 'User';
    return email.split('@').first;
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
