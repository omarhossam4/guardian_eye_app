import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, User>> call(String email, String password) {
    return repository.login(email, password);
  }
}
