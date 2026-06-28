import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianFirestoreProfile {
  const GuardianFirestoreProfile({
    required this.guardianId,
    required this.email,
    required this.name,
    required this.monitoredUsers,
    required this.monitoredUserLabels,
    required this.reference,
  });

  final String guardianId;
  final String email;
  final String name;

  /// IDs of the `blind_users` docs this guardian is linked to. A guardian
  /// can link multiple wearables via the device-id flow.
  final List<String> monitoredUsers;

  /// Per-guardian display names for each linked wearable. Map of
  /// `blindId -> label` (e.g. `"BLIND-AB1234": "Mom"`). Different guardians
  /// can call the same wearable different names.
  final Map<String, String> monitoredUserLabels;

  final DocumentReference<Map<String, dynamic>> reference;

  bool get hasLinkedBlindUser => monitoredUsers.isNotEmpty;

  String? labelFor(String blindId) {
    final raw = monitoredUserLabels[blindId]?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  factory GuardianFirestoreProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawLabels = data['monitored_user_labels'];
    final labels = <String, String>{};
    if (rawLabels is Map) {
      rawLabels.forEach((key, value) {
        final k = key.toString().trim();
        final v = value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) labels[k] = v;
      });
    }
    return GuardianFirestoreProfile(
      guardianId: snapshot.id,
      email: (data['email'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      monitoredUsers: (data['monitored_users'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      monitoredUserLabels: labels,
      reference: snapshot.reference,
    );
  }
}
