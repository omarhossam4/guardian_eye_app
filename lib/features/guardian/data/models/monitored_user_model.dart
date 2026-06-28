class MonitoredUserModel {
  const MonitoredUserModel({
    required this.id,
    required this.uniqueId,
    required this.name,
    this.deviceId,
    this.active = false,
    this.createdAt,
    this.guardianCount = 0,
    this.batteryLevel,
  });

  final String id;
  final String uniqueId;
  final String name;
  final String? deviceId;
  final bool active;
  final DateTime? createdAt;
  final int guardianCount;
  final int? batteryLevel;

  factory MonitoredUserModel.fromJson(Map<String, dynamic> json) {
    final uniqueId =
        (json['unique_id'] ?? json['uniqueId'] ?? json['user_unique_id'] ?? '')
            .toString();

    return MonitoredUserModel(
      id: (json['id'] ??
              json['_id'] ??
              json['user_id'] ??
              json['userId'] ??
              uniqueId)
          .toString(),
      uniqueId: uniqueId,
      name: (json['name'] ?? 'Unknown User').toString(),
      deviceId: (json['device_id'] ?? json['deviceId'])?.toString(),
      active: json['active'] as bool? ?? false,
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
      guardianCount: (json['guardian_count'] as num?)?.toInt() ?? 0,
      batteryLevel: _toInt(
        json['battery_level'] ??
            json['batteryLevel'] ??
            (json['current_location'] is Map
                ? (json['current_location'] as Map)['battery_level']
                : null),
      ),
    );
  }

  MonitoredUserModel copyWith({
    String? id,
    String? uniqueId,
    String? name,
    String? deviceId,
    bool? active,
    DateTime? createdAt,
    int? guardianCount,
    int? batteryLevel,
  }) {
    return MonitoredUserModel(
      id: id ?? this.id,
      uniqueId: uniqueId ?? this.uniqueId,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      guardianCount: guardianCount ?? this.guardianCount,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
