class AlertModel {
  const AlertModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.severity,
    this.type,
    this.objectType,
    this.distanceMeters,
    this.acknowledged = false,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? severity;
  final String? type;
  final String? objectType;
  final double? distanceMeters;
  final bool acknowledged;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final objectType = json['object_type']?.toString();
    final distanceMeters = (json['distance_meters'] as num?)?.toDouble();
    final title = _buildTitle(
      type: type,
      objectType: objectType,
      fallbackTitle:
          json['title']?.toString() ?? json['alert_title']?.toString(),
    );
    final message = _buildMessage(
      type: type,
      objectType: objectType,
      distanceMeters: distanceMeters,
      fallbackMessage:
          json['message']?.toString() ?? json['description']?.toString(),
    );

    return AlertModel(
      id: (json['alert_id'] ?? json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      title: title,
      message: message,
      createdAt: DateTime.tryParse(
            (json['timestamp'] ??
                    json['created_at'] ??
                    json['createdAt'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          ) ??
          DateTime.now(),
      severity: json['severity']?.toString(),
      type: type,
      objectType: objectType,
      distanceMeters: distanceMeters,
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }

  static String _buildTitle({
    required String? type,
    required String? objectType,
    required String? fallbackTitle,
  }) {
    if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty) {
      return fallbackTitle.trim();
    }

    final formattedType = _formatLabel(type);
    final formattedObjectType = _formatLabel(objectType);

    if (formattedType != null && formattedObjectType != null) {
      return '$formattedType: $formattedObjectType';
    }
    if (formattedType != null) {
      return formattedType;
    }
    if (formattedObjectType != null) {
      return formattedObjectType;
    }
    return 'Alert';
  }

  static String _buildMessage({
    required String? type,
    required String? objectType,
    required double? distanceMeters,
    required String? fallbackMessage,
  }) {
    if (fallbackMessage != null && fallbackMessage.trim().isNotEmpty) {
      return fallbackMessage.trim();
    }

    final parts = <String>[];
    final formattedObjectType = _formatLabel(objectType);
    final formattedType = _formatLabel(type);

    if (formattedObjectType != null) {
      parts.add('Object: $formattedObjectType');
    }
    if (formattedType != null) {
      parts.add('Obstacle: $formattedType');
    }
    if (distanceMeters != null) {
      final decimals = distanceMeters % 1 == 0 ? 0 : 1;
      parts.add('Distance: ${distanceMeters.toStringAsFixed(decimals)} m');
    }

    return parts.isEmpty ? 'No additional details.' : parts.join(' | ');
  }

  static String? _formatLabel(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return null;

    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
