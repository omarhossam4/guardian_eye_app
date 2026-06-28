import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:guardian_eye/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final userModel = await remoteDataSource.login(email, password);
      await localDataSource.cacheUser(userModel);
      await localDataSource.cacheToken('mock_token_${userModel.id}');
      return Right(userModel.toEntity());
    } catch (e) {
      return const Left(InvalidCredentialsFailure());
    }
  }

  @override
  Future<Either<Failure, User>> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userModel = await remoteDataSource.register(email, password, name);
      await localDataSource.cacheUser(userModel);
      await localDataSource.cacheToken('mock_token_${userModel.id}');
      return Right(userModel.toEntity());
    } catch (e) {
      return const Left(AuthFailure('Registration failed'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearCache();
      return const Right(null);
    } catch (e) {
      return const Left(AuthFailure('Logout failed'));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser != null) {
        return Right(cachedUser.toEntity());
      }

      final token = await localDataSource.getToken();
      if (token != null) {
        final user = await remoteDataSource.getCurrentUser();
        await localDataSource.cacheUser(user);
        return Right(user.toEntity());
      }

      return const Left(AuthFailure('No user logged in'));
    } catch (e) {
      return const Left(AuthFailure('Failed to get current user'));
    }
  }

  @override
  Stream<User?> authStateChanges() async* {
    final user = await getCurrentUser();
    yield user.fold((_) => null, (user) => user);
  }

  @override
  Future<Either<Failure, void>> updateUserRole(UserRole role) async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser == null) {
        return const Left(AuthFailure('No user logged in'));
      }

      await remoteDataSource.updateUserRole(cachedUser.id, role);

      final updatedUser = cachedUser.copyWith(role: role);
      await localDataSource.cacheUser(updatedUser);

      return const Right(null);
    } catch (e) {
      return const Left(AuthFailure('Failed to update role'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      if (cachedUser == null) {
        return const Left(AuthFailure('No user logged in'));
      }

      final updatedUser = cachedUser.copyWith(
        name: name ?? cachedUser.name,
        phoneNumber: phoneNumber ?? cachedUser.phoneNumber,
        photoUrl: photoUrl ?? cachedUser.photoUrl,
        updatedAt: DateTime.now(),
      );

      await localDataSource.cacheUser(updatedUser);
      return const Right(null);
    } catch (e) {
      return const Left(AuthFailure('Failed to update profile'));
    }
  }
}
