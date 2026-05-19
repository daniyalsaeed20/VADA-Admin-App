import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/checkin_record.dart';

class CheckinsRepository {
  const CheckinsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _checkins =>
      _firestore.collection(FirestoreCollections.checkins);

  Stream<List<CheckinRecord>> watchCheckins() {
    return _checkins.snapshots().map((snapshot) {
      final items = snapshot.docs
          .where((doc) => doc.id != FirestoreCollections.metaDoc)
          .map(CheckinRecord.fromFirestore)
          .toList();

      items.sort((a, b) {
        final aDate = a.createdAt ?? a.capturedAt;
        final bDate = b.createdAt ?? b.capturedAt;
        if (aDate == null && bDate == null) {
          return b.id.compareTo(a.id);
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }
}
