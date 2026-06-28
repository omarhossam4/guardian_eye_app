import 'package:cloud_firestore/cloud_firestore.dart';

enum PairingHandshakeStatus { waiting, completed }

/// A short-lived doc the blind user's phone creates at pairing time and
/// listens to. The guardian scans the blind user's QR, fills in the
/// credentials, and the blind phone's listener picks them up.
class PairingHandshake {
  const PairingHandshake({
    required this.deviceId,
    required this.status,
    required this.email,
    required this.password,
    required this.blindId,
    required this.blindAuthUid,
    required this.guardianId,
    required this.expiresAt,
  });

  final String deviceId;
  final PairingHandshakeStatus status;
  final String email;
  final String password;
  final String blindId;
  final String blindAuthUid;
  final String guardianId;
  final DateTime expiresAt;

  factory PairingHandshake.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final expires = data['expires_at'];
    final status = (data['status'] ?? 'waiting').toString();
    return PairingHandshake(
      deviceId: snapshot.id,
      status: status == 'completed'
          ? PairingHandshakeStatus.completed
          : PairingHandshakeStatus.waiting,
      email: (data['email'] ?? '').toString(),
      password: (data['password'] ?? '').toString(),
      blindId: (data['blind_id'] ?? '').toString(),
      blindAuthUid: (data['blind_auth_uid'] ?? '').toString(),
      guardianId: (data['guardian_id'] ?? '').toString(),
      expiresAt: expires is Timestamp
          ? expires.toDate()
          : DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == PairingHandshakeStatus.completed;
}
