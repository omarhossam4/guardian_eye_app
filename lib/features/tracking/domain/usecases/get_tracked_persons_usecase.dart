import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/tracking/domain/entities/tracked_person.dart';
import 'package:guardian_eye/features/tracking/domain/repositories/tracking_repository.dart';

class GetTrackedPersonsUseCase {
  final TrackingRepository repository;

  GetTrackedPersonsUseCase(this.repository);

  Future<Either<Failure, List<TrackedPerson>>> call() {
    return repository.getTrackedPersons();
  }
}
