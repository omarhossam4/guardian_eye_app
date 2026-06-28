import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/auth/domain/repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.logout();
  }
}
