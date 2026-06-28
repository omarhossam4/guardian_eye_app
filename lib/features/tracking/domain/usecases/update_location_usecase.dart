import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/tracking/domain/entities/location.dart';
import 'package:guardian_eye/features/tracking/domain/repositories/tracking_repository.dart';

class UpdateLocationUseCase {
  final TrackingRepository repository;

  UpdateLocationUseCase(this.repository);

  Future<Either<Failure, void>> call(LocationData location) {
    return repository.updateLocation(location);
  }
}
