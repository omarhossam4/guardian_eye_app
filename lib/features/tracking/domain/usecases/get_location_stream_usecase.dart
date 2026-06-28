import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/tracking/domain/entities/location.dart';
import 'package:guardian_eye/features/tracking/domain/repositories/tracking_repository.dart';

class GetLocationStreamUseCase {
  final TrackingRepository repository;

  GetLocationStreamUseCase(this.repository);

  Stream<Either<Failure, LocationData>> call() {
    return repository.getLocationStream();
  }
}
