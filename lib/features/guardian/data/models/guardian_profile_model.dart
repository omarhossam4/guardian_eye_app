class GuardianProfileModel {
  const GuardianProfileModel({
    required this.id,
    required this.name,
    required this.monitoredUsers,
    this.email,
    this.phoneNumber,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final List<String> monitoredUsers;
  final DateTime? createdAt;

  factory GuardianProfileModel.fromJson(Map<String, dynamic> json) {
    return GuardianProfileModel(
      id: (json['guardian_id'] ?? json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      phoneNumber: (json['phone'] ?? json['phone_number'] ?? json['phoneNumber'])
          ?.toString(),
      monitoredUsers: (json['monitored_users'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      createdAt: DateTime.tryParse(
          (json['created_at'] ?? json['createdAt'] ?? '').toString()),
    );
  }
}
