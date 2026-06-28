class CreatedBlindCredentials {
  const CreatedBlindCredentials({
    required this.email,
    required this.password,
    required this.blindId,
    required this.authUid,
    required this.pairingToken,
  });

  final String email;
  final String password;
  final String blindId;
  final String authUid;
  final String pairingToken;
}
