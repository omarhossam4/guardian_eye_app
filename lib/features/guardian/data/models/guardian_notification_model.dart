class GuardianNotificationModel {
  const GuardianNotificationModel({
    required this.id,
    required this.kind,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.title,
    this.userId,
    this.userUniqueId,
    this.userName,
    this.details,
  });

  final String id;
  final String kind;
  final String message;
  final DateTime timestamp;
  final String? title;
  final String? userId;
  final String? userUniqueId;
  final String? userName;
  final String? details;
  final bool isRead;

  bool get isLocationUpdate {
    final normalized = kind.toLowerCase();
    return normalized.contains('location');
  }

  factory GuardianNotificationModel.fromJson(Map<String, dynamic> json) {
    final kind = (json['type'] ??
            json['kind'] ??
            json['notification_type'] ??
            json['event_type'] ??
            'notification')
        .toString();

    final message = (json['message'] ??
            json['body'] ??
            json['description'] ??
            json['content'] ??
            json['title'] ??
            'Notification')
        .toString();

    return GuardianNotificationModel(
      id: (json['notification_id'] ??
              json['id'] ??
              json['_id'] ??
              json['alert_id'] ??
              DateTime.now().microsecondsSinceEpoch)
          .toString(),
      kind: kind,
      message: message,
      timestamp: DateTime.tryParse(
            (json['timestamp'] ??
                    json['created_at'] ??
                    json['createdAt'] ??
                    json['updated_at'] ??
                    json['updatedAt'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          ) ??
          DateTime.now(),
      title: json['title']?.toString(),
      userId: (json['user_id'] ??
              json['userId'] ??
              json['blind_user_id'] ??
              json['blindUserId'])
          ?.toString(),
      userUniqueId: (json['user_unique_id'] ??
              json['userUniqueId'] ??
              json['unique_id'] ??
              json['uniqueId'] ??
              json['blind_user_unique_id'] ??
              json['blindUserUniqueId'] ??
              json['blind_user_id'] ??
              json['user_id'])
          ?.toString(),
      userName: (json['user_name'] ??
              json['userName'] ??
              json['blind_user_name'] ??
              json['blindUserName'] ??
              json['name'])
          ?.toString(),
      details: (json['details'] ??
              json['detail'] ??
              json['metadata'] ??
              json['data'])
          ?.toString(),
      isRead: json['is_read'] as bool? ??
          json['read'] as bool? ??
          json['acknowledged'] as bool? ??
          false,
    );
  }
}
