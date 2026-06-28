class LinkUserRequest {
  const LinkUserRequest({
    required this.userUniqueId,
  });

  final String userUniqueId;

  Map<String, dynamic> toJson() {
    return {
      'user_unique_id': userUniqueId,
      'unique_id': userUniqueId,
      'monitored_user_unique_id': userUniqueId,
      'blind_user_unique_id': userUniqueId,
      'userId': userUniqueId,
      'user_id': userUniqueId,
    };
  }
}
