import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../../firebase_options.dart';
import '../domain/fighter.dart';
import '../domain/testing_window.dart';

class FightersRepository {
  const FightersRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _whereaboutsProfiles =>
      _firestore.collection(FirestoreCollections.whereaboutsProfiles);

  Stream<List<Fighter>> watchFighters() {
    return _users.where('role', isEqualTo: AppRoles.fighter).snapshots().map((
      snapshot,
    ) {
      final fighters =
          snapshot.docs.map((doc) => Fighter.fromFirestore(doc)).toList();

      fighters.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return fighters;
    });
  }

  /// Standing daily testing windows from [whereaboutsProfiles].
  /// Keyed by fighter UID (`doc.id` and/or `fighterId` field).
  Stream<Map<String, TestingWindow>> watchTestingWindows() {
    return _whereaboutsProfiles.snapshots().map((snapshot) {
      final windows = <String, TestingWindow>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final window = TestingWindow.tryParse(data);
        if (window == null) continue;

        windows[doc.id] = window;
        final fighterId = (data['fighterId'] as String?)?.trim() ?? '';
        if (fighterId.isNotEmpty) {
          windows[fighterId] = window;
        }
      }
      return windows;
    });
  }

  Future<void> createFighter({
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phone,
    required String email,
    required String address,
    required String city,
    required String stateCounty,
    required String postalCode,
    required String country,
    required String primaryContactPerson,
    required String password,
    bool disabled = false,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final timestamp = FieldValue.serverTimestamp();

    // Use a temporary secondary app so creating fighter credentials does not
    // replace the currently signed-in admin session.
    final app = await Firebase.initializeApp(
      name: 'fighter-create-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: app);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = credential.user!.uid;

      await _users.doc(uid).set({
        'role': AppRoles.fighter,
        'fullName': fullName.trim(),
        'dateOfBirth': dateOfBirth.trim(),
        'gender': gender.trim(),
        'phone': phone.trim(),
        'email': normalizedEmail,
        'address': address.trim(),
        'city': city.trim(),
        'stateCounty': stateCounty.trim(),
        'postalCode': postalCode.trim(),
        'country': country.trim(),
        'primaryContactPerson': primaryContactPerson.trim(),
        'disabled': disabled,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });
    } finally {
      await app.delete();
    }
  }

  Future<void> updateFighter({
    required String uid,
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phone,
    required String email,
    required String address,
    required String city,
    required String stateCounty,
    required String postalCode,
    required String country,
    required String primaryContactPerson,
    required bool disabled,
  }) async {
    await _users.doc(uid).set({
      'fullName': fullName.trim(),
      'dateOfBirth': dateOfBirth.trim(),
      'gender': gender.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      'city': city.trim(),
      'stateCounty': stateCounty.trim(),
      'postalCode': postalCode.trim(),
      'country': country.trim(),
      'primaryContactPerson': primaryContactPerson.trim(),
      'disabled': disabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setFighterAccess({
    required String uid,
    required bool disabled,
  }) async {
    await _users.doc(uid).update({
      'disabled': disabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
