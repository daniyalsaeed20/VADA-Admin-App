import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_collections.dart';
import '../../core/firebase/firebase_providers.dart';

final bootstrapServiceProvider = Provider<BootstrapService>((ref) {
  return BootstrapService(ref.watch(firestoreProvider));
});

final bootstrapCollectionsProvider = FutureProvider<void>((ref) async {
  await ref.watch(bootstrapServiceProvider).ensureBaseCollections();
});

class BootstrapService {
  BootstrapService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> ensureBaseCollections() async {
    final now = FieldValue.serverTimestamp();
    final collections = [
      FirestoreCollections.contacts,
      FirestoreCollections.locations,
      FirestoreCollections.schedules,
      FirestoreCollections.checkins,
      FirestoreCollections.notifications,
      FirestoreCollections.scheduleRequests,
    ];

    for (final collection in collections) {
      await _firestore
          .collection(collection)
          .doc(FirestoreCollections.metaDoc)
          .set({
        'initializedAt': now,
        'source': 'admin_web_m1',
      }, SetOptions(merge: true));
    }
  }
}
