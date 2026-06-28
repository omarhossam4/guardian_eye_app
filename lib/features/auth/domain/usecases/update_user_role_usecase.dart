import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/auth/domain/repositories/auth_repository.dart';

class UpdateUserRoleUseCase {
  final AuthRepository repository;

  UpdateUserRoleUseCase(this.repository);

  Future<Either<Failure, void>> call(UserRole role) {
    return repository.updateUserRole(role);
  }
}
