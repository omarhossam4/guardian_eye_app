class LocationModel {
  const LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.address,
    this.accuracy,
  });

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final String? address;
  final double? accuracy;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      userId: (json['user_id'] ?? json['userId'] ?? json['unique_id'] ?? '')
          .toString(),
      latitude: _toDouble(json['latitude'] ?? json['lat']),
      longitude: _toDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      updatedAt: DateTime.tryParse(
            (json['updated_at'] ??
                    json['updatedAt'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          ) ??
          DateTime.now(),
      address: json['address']?.toString(),
      accuracy: _nullableDouble(json['accuracy']),
    );
  }

  static double _toDouble(dynamic value) {
    return _nullableDouble(value) ?? 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
