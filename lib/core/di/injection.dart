import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian_eye/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:guardian_eye/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:guardian_eye/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:guardian_eye/features/auth/domain/repositories/auth_repository.dart';
import 'package:guardian_eye/features/auth/domain/usecases/login_usecase.dart';
import 'package:guardian_eye/features/auth/domain/usecases/register_usecase.dart';
import 'package:guardian_eye/features/auth/domain/usecases/logout_usecase.dart';
import 'package:guardian_eye/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:guardian_eye/features/auth/domain/usecases/update_user_role_usecase.dart';
import 'package:guardian_eye/features/tracking/data/datasources/location_local_datasource.dart';
import 'package:guardian_eye/features/tracking/data/datasources/location_remote_datasource.dart';
import 'package:guardian_eye/features/tracking/data/repositories/tracking_repository_impl.dart';
import 'package:guardian_eye/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:guardian_eye/features/tracking/domain/usecases/get_location_stream_usecase.dart';
import 'package:guardian_eye/features/tracking/domain/usecases/update_location_usecase.dart';
import 'package:guardian_eye/features/tracking/domain/usecases/get_tracked_persons_usecase.dart';

final sl = GetIt.instance;

Future<void> setupDependencies({
  required SharedPreferences sharedPreferences,
}) async {
  if (sl.isRegistered<SharedPreferences>()) {
    return;
  }

  // External
  sl.registerLazySingleton(() => sharedPreferences);

  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<LocationLocalDataSource>(
    () => LocationLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<LocationRemoteDataSource>(
    () => LocationRemoteDataSourceImpl(),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<TrackingRepository>(
    () => TrackingRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // Use Cases - Auth
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserRoleUseCase(sl()));

  // Use Cases - Tracking
  sl.registerLazySingleton(() => GetLocationStreamUseCase(sl()));
  sl.registerLazySingleton(() => UpdateLocationUseCase(sl()));
  sl.registerLazySingleton(() => GetTrackedPersonsUseCase(sl()));
}
