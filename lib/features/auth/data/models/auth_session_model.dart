import 'package:guardian_eye/features/auth/data/models/user_model.dart';

class AuthSessionModel {
  const AuthSessionModel({
    required this.user,
    required this.idToken,
    this.expiresAt,
    this.lastRefreshAt,
  });

  final UserModel user;
  final String idToken;
  final DateTime? expiresAt;
  final DateTime? lastRefreshAt;
}
