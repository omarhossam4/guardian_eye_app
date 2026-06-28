import 'package:guardian_eye/features/tracking/domain/entities/tracked_person.dart';

abstract class LocationRemoteDataSource {
  Future<void> updateLocation(double latitude, double longitude);
  Future<List<TrackedPerson>> getTrackedPersons();
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  @override
  Future<void> updateLocation(double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<List<TrackedPerson>> getTrackedPersons() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data
    return [
      TrackedPerson(
        id: '1',
        name: 'Sarah Johnson',
        latitude: 30.0450,
        longitude: 31.2360,
        batteryLevel: 85,
        status: PersonStatus.online,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 2)),
        address: 'Downtown Cairo',
      ),
      TrackedPerson(
        id: '2',
        name: 'Michael Chen',
        latitude: 30.0440,
        longitude: 31.2350,
        batteryLevel: 42,
        status: PersonStatus.online,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
        address: 'Zamalek District',
      ),
    ];
  }
}
