import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/features/auth/data/models/blind_migration_result.dart';
import 'package:guardian_eye/features/auth/data/models/blind_user_profile.dart';
import 'package:guardian_eye/features/auth/data/models/created_blind_credentials.dart';
import 'package:guardian_eye/features/auth/data/models/guardian_firestore_profile.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/pairing/data/models/pairing_handshake.dart';

class FirestoreAuthFlowService {
  FirestoreAuthFlowService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _firebaseAuth;
  static const _blindUsersCollection = 'blind_users';
  static const _guardiansCollection = 'guardians';
  static const _pairingHandshakesCollection = 'pairing_handshakes';
  static const _handshakeTtl = Duration(minutes: 3);

  Future<UserRole> resolveRoleForUid(String uid) async {
    final guardianDoc =
        await _firestore.collection(_guardiansCollection).doc(uid).get();
    if (guardianDoc.exists) {
      return UserRole.guardian;
    }

    final blindQuery = await _firestore
        .collection(_blindUsersCollection)
        .where('auth_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (blindQuery.docs.isNotEmpty) {
      return UserRole.blind;
    }

    throw const AppException(
      'No matching guardian or blind user profile was found for this account.',
    );
  }

  Future<BlindUserProfile> getBlindProfileForCurrentUser() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('Please sign in first.');
    }

    final query = await _firestore
        .collection(_blindUsersCollection)
        .where('auth_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw const AppException('Blind user profile not found.');
    }

    return BlindUserProfile.fromSnapshot(query.docs.first);
  }

  Future<GuardianFirestoreProfile> getGuardianProfileForCurrentUser() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('Please sign in first.');
    }

    final snapshot =
        await _firestore.collection(_guardiansCollection).doc(uid).get();
    if (!snapshot.exists) {
      throw const AppException('Guardian profile not found.');
    }

    return GuardianFirestoreProfile.fromSnapshot(snapshot);
  }

  Future<List<GuardianFirestoreProfile>> getGuardiansForBlindUser(
    List<String> guardianIds,
  ) async {
    if (guardianIds.isEmpty) return [];
    final snapshots = await Future.wait(
      guardianIds.map(
        (id) => _firestore.collection(_guardiansCollection).doc(id).get(),
      ),
    );
    return snapshots
        .where((s) => s.exists)
        .map(GuardianFirestoreProfile.fromSnapshot)
        .toList();
  }

  // ─── Device-id linking (guardian side) ──────────────────────────────────
  //
  // Wearables are provisioned with a stable `device_id` (printed on the
  // device as a QR sticker). The matching `blind_users` doc carries the
  // same value in its `device_id` field.

  /// Returns the blind user whose `device_id` matches [deviceId], or null.
  Future<BlindUserProfile?> findBlindUserByDeviceId(String deviceId) async {
    final normalized = deviceId.trim();
    if (normalized.isEmpty) {
      throw const AppException('Enter a device ID.');
    }
    final query = _firestore
        .collection(_blindUsersCollection)
        .where('device_id', isEqualTo: normalized)
        .limit(1);

    // Default get() waits for the server. On a slow connection that can hang
    // the link flow, so cap it and fall back to the local cache — the wearable
    // doc is usually already cached from a prior session.
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    }
    if (snapshot.docs.isEmpty) return null;
    return BlindUserProfile.fromSnapshot(snapshot.docs.first);
  }

  /// Persists the link in both `guardians/{guardianId}` and
  /// `blind_users/{blindId}` atomically. Multiple wearables may be linked
  /// to the same guardian — each call adds another entry to
  /// `monitored_users[]`.
  Future<void> linkGuardianToBlindUser({
    required String guardianId,
    required BlindUserProfile blindUser,
    required String deviceId,
  }) async {
    // The guardian-side write is the one that flips link state and lets the
    // UI navigate to the dashboard, so issue it on its own (not batched with
    // the blind-side write, which could stall or roll it back).
    final guardianWrite = _firestore
        .collection(_guardiansCollection)
        .doc(guardianId)
        .set(<String, dynamic>{
      'monitored_users': FieldValue.arrayUnion(<String>[blindUser.blindId]),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Firestore applies the write to its local cache immediately, but the
    // returned Future only resolves once the SERVER acknowledges it. On a slow
    // or dropped connection that ack can take many seconds (or never arrive
    // while offline) — and awaiting it directly is exactly what freezes the
    // link screen on "Linking…" even though the link is already effective
    // locally (Home shows the device linked from cache). So cap the wait: a
    // genuine permission error still surfaces within the window, but a slow
    // ack lets us proceed — the write is durably queued and syncs on its own.
    unawaited(guardianWrite.catchError((_) {})); // don't leak a late ack error
    await guardianWrite.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );

    // Blind side — best effort, fire and forget. Never block linking on it.
    unawaited(
      blindUser.reference.update(<String, dynamic>{
        'linked_guardians': FieldValue.arrayUnion(<String>[guardianId]),
      }).catchError((_) {}),
    );
  }

  /// Removes the link from both `guardians/{guardianId}` (pops from
  /// `monitored_users` and clears the per-guardian label) and
  /// `blind_users/{blindId}` (pops from `linked_guardians`). Failures on the
  /// blind-side write are swallowed — the guardian-side removal is the one
  /// that has to succeed for the unlink to be visible to the user.
  Future<void> unlinkGuardianFromMonitoredUser({
    required String guardianId,
    required String blindId,
  }) async {
    final id = blindId.trim();
    if (id.isEmpty) {
      throw const AppException('Missing user id.');
    }

    final guardianRef =
        _firestore.collection(_guardiansCollection).doc(guardianId);

    // `monitored_users` stores blind_users doc ids, but the id we're handed
    // (from the REST API / dashboard) can differ in casing. arrayRemove is an
    // exact-string match, so resolve the actual stored entries first and
    // remove those — otherwise a casing mismatch leaves the entry in place and
    // the user reappears on the next refresh.
    final snapshot = await guardianRef.get();
    final stored = (snapshot.data()?['monitored_users'] as List<dynamic>? ??
            const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty);
    final toRemove = <String>{
      id,
      ...stored.where(
        (entry) => entry.trim().toLowerCase() == id.toLowerCase(),
      ),
    };

    // Guardian side — use set+merge so a missing doc / missing fields are
    // not fatal. arrayRemove on a missing value is a no-op.
    await guardianRef.set(<String, dynamic>{
      'monitored_users': FieldValue.arrayRemove(toRemove.toList()),
      'monitored_user_labels': <String, dynamic>{
        for (final entry in toRemove) entry: FieldValue.delete(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Blind side — best effort, don't surface errors. Cover every matched id.
    for (final entry in toRemove) {
      try {
        await _firestore
            .collection(_blindUsersCollection)
            .doc(entry)
            .update(<String, dynamic>{
          'linked_guardians': FieldValue.arrayRemove(<String>[guardianId]),
        });
      } catch (_) {}
    }
  }

  /// Writes a per-guardian display label for a linked wearable. Stored as
  /// `monitored_user_labels.{blindId}` on the guardian doc.
  Future<void> setMonitoredUserLabel({
    required String guardianId,
    required String blindId,
    required String label,
  }) async {
    final trimmedLabel = label.trim();
    final trimmedBlindId = blindId.trim();
    if (trimmedBlindId.isEmpty) {
      throw const AppException('Missing blind user id.');
    }
    if (trimmedLabel.isEmpty) {
      throw const AppException('Enter a name.');
    }
    final write = _firestore
        .collection(_guardiansCollection)
        .doc(guardianId)
        .set(<String, dynamic>{
      'monitored_user_labels': <String, dynamic>{trimmedBlindId: trimmedLabel},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Same server-ack caveat as linking: don't let a slow ack freeze the
    // "Save name" dialog — the label is applied to the local cache instantly
    // and syncs on its own.
    unawaited(write.catchError((_) {}));
    await write.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  Future<void> unlinkGuardianFromBlindUser({
    required BlindUserProfile blindUser,
    required String guardianId,
  }) async {
    await blindUser.reference.update(<String, dynamic>{
      'linked_guardians': FieldValue.arrayRemove(<String>[guardianId]),
    });
    try {
      await _firestore
          .collection(_guardiansCollection)
          .doc(guardianId)
          .update(<String, dynamic>{
        'monitored_users':
            FieldValue.arrayRemove(<String>[blindUser.blindId]),
      });
    } catch (_) {}
  }

  // ─── Pairing handshake flow ──────────────────────────────────────────────
  //
  // 1. Blind user opens app → app calls [startPairingHandshake] → gets a
  //    deviceId → displays it as a QR.
  // 2. Guardian (signed in) scans the QR → app calls
  //    [completePairingHandshake] which creates the blind user account and
  //    writes the credentials into the same handshake doc.
  // 3. Blind app's [watchPairingHandshake] stream fires → it signs in with
  //    the delivered credentials.

  /// Creates a fresh, empty handshake doc and returns its id. The blind app
  /// encodes this id into the QR it displays.
  Future<String> startPairingHandshake() async {
    final deviceId = _generateDeviceId();
    final expiresAt = DateTime.now().add(_handshakeTtl);
    await _firestore
        .collection(_pairingHandshakesCollection)
        .doc(deviceId)
        .set(<String, dynamic>{
      'status': 'waiting',
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(expiresAt),
    });
    return deviceId;
  }

  /// Stream the handshake doc so the blind user's app can react when the
  /// guardian fills in the credentials.
  Stream<PairingHandshake?> watchPairingHandshake(String deviceId) {
    return _firestore
        .collection(_pairingHandshakesCollection)
        .doc(deviceId)
        .snapshots()
        .map((snap) => snap.exists ? PairingHandshake.fromSnapshot(snap) : null);
  }

  /// Removes the handshake doc once the blind user is signed in. Best-effort
  /// — failure to delete is not fatal because the doc is short-lived anyway.
  Future<void> deletePairingHandshake(String deviceId) async {
    try {
      await _firestore
          .collection(_pairingHandshakesCollection)
          .doc(deviceId)
          .delete();
    } catch (_) {}
  }

  /// Called by the guardian after scanning the blind user's QR. Creates the
  /// blind user's Firebase Auth account + Firestore profile, links it to
  /// this guardian, and writes the credentials into the handshake doc.
  Future<CreatedBlindCredentials> completePairingHandshake({
    required String deviceId,
    required String guardianId,
    required String blindName,
  }) async {
    final trimmedName = blindName.trim();
    if (trimmedName.isEmpty) {
      throw const AppException('Enter a name for the care recipient.');
    }
    final trimmedDeviceId = deviceId.trim();
    if (trimmedDeviceId.isEmpty) {
      throw const AppException('Invalid pairing QR.');
    }

    final handshakeRef = _firestore
        .collection(_pairingHandshakesCollection)
        .doc(trimmedDeviceId);
    final handshakeSnap = await handshakeRef.get();
    if (!handshakeSnap.exists) {
      throw const AppException(
        'Pairing session not found. Ask them to open the app again.',
      );
    }
    final existing = PairingHandshake.fromSnapshot(handshakeSnap);
    if (existing.isCompleted) {
      throw const AppException('This pairing QR has already been used.');
    }
    if (existing.isExpired) {
      throw const AppException(
        'This pairing QR has expired. Ask them to refresh.',
      );
    }

    final blindId = _generateBlindId();
    final password = _generatePassword();
    final email = _deriveBlindEmail(blindId: blindId, name: trimmedName);

    final secondaryApp = await Firebase.initializeApp(
      name: 'blind-creator-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = fb.FirebaseAuth.instanceFor(app: secondaryApp);
    fb.User? blindUser;

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      blindUser = credential.user;
      if (blindUser == null) {
        throw const AppException('Failed to create blind user account.');
      }

      final blindData = <String, dynamic>{
        'created_at': FieldValue.serverTimestamp(),
        'name': trimmedName,
        'email': email,
        'auth_uid': blindUser.uid,
        'linked_guardians': <String>[guardianId],
      };

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(_blindUsersCollection).doc(blindId),
        blindData,
      );
      batch.update(
        _firestore.collection(_guardiansCollection).doc(guardianId),
        <String, dynamic>{
          'monitored_users': FieldValue.arrayUnion(<String>[blindId]),
        },
      );
      batch.update(handshakeRef, <String, dynamic>{
        'status': 'completed',
        'email': email,
        'password': password,
        'blind_id': blindId,
        'blind_auth_uid': blindUser.uid,
        'guardian_id': guardianId,
        'completed_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return CreatedBlindCredentials(
        email: email,
        password: password,
        blindId: blindId,
        authUid: blindUser.uid,
        pairingToken: trimmedDeviceId,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw AppException(
        error.message ?? 'Unable to create blind user account.',
        code: error.code,
      );
    } catch (error) {
      if (blindUser != null) {
        await blindUser.delete();
      }
      rethrow;
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  String _generateBlindId() {
    final random = Random.secure();
    final suffix = List.generate(6, (_) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      return chars[random.nextInt(chars.length)];
    }).join();
    return 'BLIND-$suffix';
  }

  String _generateDeviceId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      10,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<List<BlindMigrationResult>> migrateBlindUsers({
    String defaultPassword = 'Blind@1234',
  }) async {
    final query = await _firestore.collection(_blindUsersCollection).get();
    final results = <BlindMigrationResult>[];

    for (final snapshot in query.docs) {
      final data = snapshot.data();
      final existingUid = (data['auth_uid'] ?? '').toString().trim();
      if (existingUid.isNotEmpty) {
        continue;
      }

      final blindId = snapshot.id;
      final name = (data['name'] ?? blindId).toString().trim();
      final email = _deriveBlindEmail(
        blindId: blindId,
        name: name,
        rawEmail: data['email']?.toString(),
      );

      final secondaryApp = await Firebase.initializeApp(
        name:
            'blind-migration-$blindId-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = fb.FirebaseAuth.instanceFor(app: secondaryApp);
      fb.User? migratedUser;

      try {
        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: defaultPassword,
        );
        migratedUser = credential.user;
        if (migratedUser == null) {
          throw const AppException('Migration account creation failed.');
        }
        await snapshot.reference.update(<String, dynamic>{
          'auth_uid': migratedUser.uid,
        });
        results.add(
          BlindMigrationResult(
            blindId: blindId,
            name: name,
            email: email,
            password: defaultPassword,
            authUid: migratedUser.uid,
            status: 'created',
          ),
        );
      } on fb.FirebaseAuthException catch (error) {
        results.add(
          BlindMigrationResult(
            blindId: blindId,
            name: name,
            email: email,
            password: defaultPassword,
            authUid: '',
            status: error.message ?? error.code,
          ),
        );
      } catch (error) {
        if (migratedUser != null) {
          await migratedUser.delete();
        }
        results.add(
          BlindMigrationResult(
            blindId: blindId,
            name: name,
            email: email,
            password: defaultPassword,
            authUid: '',
            status: error.toString(),
          ),
        );
      } finally {
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      }
    }

    return results;
  }

  String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(
      8,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _deriveBlindEmail({
    required String blindId,
    required String name,
    String? rawEmail,
  }) {
    final normalizedEmail = rawEmail?.trim().toLowerCase();
    if (normalizedEmail != null && normalizedEmail.contains('@')) {
      return normalizedEmail;
    }

    final slugSource = name.isNotEmpty ? name : blindId;
    final slug = slugSource
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.|\.$'), '');
    final safeSlug = slug.isEmpty ? blindId.toLowerCase() : slug;
    return '$safeSlug.$blindId@guardianeye.blind';
  }
}
