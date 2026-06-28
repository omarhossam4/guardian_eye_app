class BlindMigrationResult {
  const BlindMigrationResult({
    required this.blindId,
    required this.name,
    required this.email,
    required this.password,
    required this.authUid,
    required this.status,
  });

  final String blindId;
  final String name;
  final String email;
  final String password;
  final String authUid;
  final String status;
}
