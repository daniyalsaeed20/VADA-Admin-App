import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/whereabouts_entry.dart';

class WhereaboutsRepository {
  const WhereaboutsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(FirestoreCollections.schedules);

  Stream<List<WhereaboutsEntry>> watchWhereabouts() {
    return _schedules.snapshots().map((snapshot) {
      final items = snapshot.docs
          .where((doc) => doc.id != FirestoreCollections.metaDoc)
          .map((doc) => WhereaboutsEntry.fromFirestore(doc))
          .toList();

      items.sort((a, b) {
        final aDate = a.date;
        final bDate = b.date;
        final compareDate = bDate.compareTo(aDate);
        if (compareDate != 0) {
          return compareDate;
        }
        return b.startTime.compareTo(a.startTime);
      });
      return items;
    });
  }

  Future<void> createWhereabouts({
    required String fighterId,
    required String date,
    required String startTime,
    required String endTime,
    required String locationId,
    required String contactId,
    required String notes,
    required String recurrence,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _schedules.add({
      'fighterId': fighterId.trim(),
      'date': date.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'locationId': locationId.trim(),
      'contactId': contactId.trim(),
      'notes': notes.trim(),
      'recurrence': normalizeRecurrence(recurrence),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateWhereabouts({
    required String id,
    required String fighterId,
    required String date,
    required String startTime,
    required String endTime,
    required String locationId,
    required String contactId,
    required String notes,
    required String recurrence,
  }) async {
    await _schedules.doc(id).set({
      'fighterId': fighterId.trim(),
      'date': date.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'locationId': locationId.trim(),
      'contactId': contactId.trim(),
      'notes': notes.trim(),
      'recurrence': normalizeRecurrence(recurrence),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
