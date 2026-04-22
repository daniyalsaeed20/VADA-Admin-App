import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/location_record.dart';

class LocationsRepository {
  const LocationsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _firestore.collection(FirestoreCollections.locations);

  Stream<List<LocationRecord>> watchLocations() {
    return _locations.snapshots().map((snapshot) {
      final locations = snapshot.docs
          .where((doc) => doc.id != FirestoreCollections.metaDoc)
          .map((doc) => LocationRecord.fromFirestore(doc))
          .toList();

      locations.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        if (aDate == null && bDate == null) {
          return a.name.compareTo(b.name);
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return locations;
    });
  }

  Future<void> createLocation({
    required String name,
    required String address,
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _locations.add({
      'name': name.trim(),
      'address': address.trim(),
      'type': type.trim().toLowerCase(),
      'assignedFighterIds': assignedFighterIds,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateLocation({
    required String id,
    required String name,
    required String address,
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    await _locations.doc(id).set({
      'name': name.trim(),
      'address': address.trim(),
      'type': type.trim().toLowerCase(),
      'assignedFighterIds': assignedFighterIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
