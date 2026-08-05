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

  Future<String> createLocation({
    required String name,
    required String address,
    String city = '',
    String stateCounty = '',
    String postalCode = '',
    String country = '',
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = await _locations.add({
      'name': name.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'stateCounty': stateCounty.trim(),
      'postalCode': postalCode.trim(),
      'country': country.trim(),
      'type': type.trim().toLowerCase(),
      'assignedFighterIds': assignedFighterIds,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  Future<void> ensureFighterAssignedToLocation({
    required String locationId,
    required String fighterId,
  }) async {
    final id = locationId.trim();
    final fighter = fighterId.trim();
    if (id.isEmpty || fighter.isEmpty) {
      return;
    }

    final snap = await _locations.doc(id).get();
    if (!snap.exists) {
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    final current = (data['assignedFighterIds'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    if (current.contains(fighter)) {
      return;
    }

    await _locations.doc(id).set({
      'assignedFighterIds': [...current, fighter],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<LocationRecord?> getLocation(String locationId) async {
    if (locationId.trim().isEmpty) {
      return null;
    }
    final doc = await _locations.doc(locationId.trim()).get();
    if (!doc.exists) {
      return null;
    }
    return LocationRecord.fromFirestore(doc);
  }

  Future<void> updateLocation({
    required String id,
    required String name,
    required String address,
    required String city,
    required String stateCounty,
    required String postalCode,
    required String country,
    required String type,
    required List<String> assignedFighterIds,
  }) async {
    await _locations.doc(id).set({
      'name': name.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'stateCounty': stateCounty.trim(),
      'postalCode': postalCode.trim(),
      'country': country.trim(),
      'type': type.trim().toLowerCase(),
      'assignedFighterIds': assignedFighterIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
