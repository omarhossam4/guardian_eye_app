import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/tracking/domain/entities/location.dart';
import 'package:guardian_eye/features/tracking/domain/entities/tracked_person.dart';

abstract class TrackingRepository {
  Stream<Either<Failure, LocationData>> getLocationStream();
  Future<Either<Failure, void>> updateLocation(LocationData location);
  Future<Either<Failure, List<TrackedPerson>>> getTrackedPersons();
  Future<Either<Failure, TrackedPerson>> getTrackedPersonById(String id);
  Future<Either<Failure, void>> addTrackedPerson(String pairingCode);
  Future<Either<Failure, void>> removeTrackedPerson(String id);
}
