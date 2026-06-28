import 'package:cloud_firestore/cloud_firestore.dart';

class BlindUserProfile {
  const BlindUserProfile({
    required this.blindId,
    required this.name,
    required this.authUid,
    required this.linkedGuardians,
    required this.reference,
  });

  final String blindId;
  final String name;
  final String authUid;
  final List<String> linkedGuardians;
  final DocumentReference<Map<String, dynamic>> reference;

  factory BlindUserProfile.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return BlindUserProfile(
      blindId: snapshot.id,
      name: (data['name'] ?? '').toString().trim(),
      authUid: (data['auth_uid'] ?? '').toString(),
      linkedGuardians: (data['linked_guardians'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      reference: snapshot.reference,
    );
  }
}
