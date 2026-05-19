import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/firebase/firebase_providers.dart';

/// Resolves display names from Firestore for notification templates.
class NotificationContextResolver {
  const NotificationContextResolver(this._firestore);

  final FirebaseFirestore _firestore;

  Future<String> fighterName(String fighterId) async {
    return (await _readDocField(
          collection: FirestoreCollections.users,
          docId: fighterId,
          fields: const ['fullName', 'name', 'displayName', 'full_name'],
        )) ??
        'Fighter';
  }

  Future<String> locationName(String locationId) async {
    return (await _readDocField(
          collection: FirestoreCollections.locations,
          docId: locationId,
          fields: const ['name'],
        )) ??
        'Location';
  }

  Future<String> contactName(String contactId) async {
    return (await _readDocField(
          collection: FirestoreCollections.contacts,
          docId: contactId,
          fields: const ['name'],
        )) ??
        'Contact';
  }

  Future<String?> _readDocField({
    required String collection,
    required String docId,
    required List<String> fields,
  }) async {
    if (docId.trim().isEmpty) {
      return null;
    }
    try {
      final snap = await _firestore.collection(collection).doc(docId.trim()).get();
      final data = snap.data();
      if (data == null) {
        return null;
      }
      for (final field in fields) {
        final value = data[field];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

final notificationContextResolverProvider =
    Provider<NotificationContextResolver>((ref) {
  return NotificationContextResolver(ref.watch(firestoreProvider));
});
