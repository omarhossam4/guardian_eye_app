import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:guardian_eye/core/errors/failures.dart';
import 'package:guardian_eye/features/tracking/data/datasources/location_local_datasource.dart';
import 'package:guardian_eye/features/tracking/data/datasources/location_remote_datasource.dart';
import 'package:guardian_eye/features/tracking/domain/entities/location.dart';
import 'package:guardian_eye/features/tracking/domain/entities/tracked_person.dart';
import 'package:guardian_eye/features/tracking/domain/repositories/tracking_repository.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  final LocationRemoteDataSource remoteDataSource;
  final LocationLocalDataSource localDataSource;

  TrackingRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Stream<Either<Failure, LocationData>> getLocationStream() async* {
    // Mock location stream
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield Right(LocationData(
        latitude: 30.0444 + (DateTime.now().millisecond / 100000),
        longitude: 31.2357 + (DateTime.now().millisecond / 100000),
        accuracy: 10.0,
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updateLocation(LocationData location) async {
    try {
      await remoteDataSource.updateLocation(
          location.latitude, location.longitude);
      await localDataSource.cacheLastLocation(
          location.latitude, location.longitude);
      return const Right(null);
    } catch (e) {
      return const Left(LocationFailure());
    }
  }

  @override
  Future<Either<Failure, List<TrackedPerson>>> getTrackedPersons() async {
    try {
      final persons = await remoteDataSource.getTrackedPersons();
      return Right(persons);
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, TrackedPerson>> getTrackedPersonById(String id) async {
    try {
      final persons = await remoteDataSource.getTrackedPersons();
      final person = persons.firstWhere((p) => p.id == id);
      return Right(person);
    } catch (e) {
      return const Left(UserNotFoundFailure());
    }
  }

  @override
  Future<Either<Failure, void>> addTrackedPerson(String pairingCode) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return const Right(null);
    } catch (e) {
      return const Left(PairingFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeTrackedPerson(String id) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return const Right(null);
    } catch (e) {
      return const Left(ServerFailure());
    }
  }
}
