import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, User>> register(
      String email, String password, String name);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User>> getCurrentUser();
  Stream<User?> authStateChanges();
  Future<Either<Failure, void>> updateUserRole(UserRole role);
  Future<Either<Failure, void>> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  });
}
