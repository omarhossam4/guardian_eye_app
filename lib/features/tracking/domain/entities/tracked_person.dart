import 'package:equatable/equatable.dart';

enum PersonStatus {
  online,
  offline,
  sos,
}

class TrackedPerson extends Equatable {
  final String id;
  final String name;
  final String? photoUrl;
  final double latitude;
  final double longitude;
  final int batteryLevel;
  final PersonStatus status;
  final DateTime lastUpdated;
  final String? address;

  const TrackedPerson({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    required this.status,
    required this.lastUpdated,
    this.address,
  });

  TrackedPerson copyWith({
    String? id,
    String? name,
    String? photoUrl,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    PersonStatus? status,
    DateTime? lastUpdated,
    String? address,
  }) {
    return TrackedPerson(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      address: address ?? this.address,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        photoUrl,
        latitude,
        longitude,
        batteryLevel,
        status,
        lastUpdated,
        address,
      ];
}
