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

  Future<String> createWhereabouts({
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
    final normalizedRecurrence = normalizeRecurrence(recurrence);
    final window = _windowTimestamps(
      date: date,
      startTime: startTime,
      endTime: endTime,
    );
    final doc = await _schedules.add({
      'fighterId': fighterId.trim(),
      'date': date.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      if (window != null) 'startAt': Timestamp.fromDate(window.start),
      if (window != null) 'endAt': Timestamp.fromDate(window.end),
      'locationId': locationId.trim(),
      'contactId': contactId.trim(),
      'notes': notes.trim(),
      'recurrence': normalizedRecurrence,
      'frequency': normalizedRecurrence,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
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
    final normalizedRecurrence = normalizeRecurrence(recurrence);
    final window = _windowTimestamps(
      date: date,
      startTime: startTime,
      endTime: endTime,
    );
    await _schedules.doc(id).set({
      'fighterId': fighterId.trim(),
      'date': date.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      if (window != null) 'startAt': Timestamp.fromDate(window.start),
      if (window != null) 'endAt': Timestamp.fromDate(window.end),
      'locationId': locationId.trim(),
      'contactId': contactId.trim(),
      'notes': notes.trim(),
      'recurrence': normalizedRecurrence,
      'frequency': normalizedRecurrence,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class _TimeWindow {
  const _TimeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_TimeWindow? _windowTimestamps({
  required String date,
  required String startTime,
  required String endTime,
}) {
  final dateParts = date.trim().split('-');
  final startParts = startTime.trim().split(':');
  final endParts = endTime.trim().split(':');
  if (dateParts.length != 3 ||
      startParts.length != 2 ||
      endParts.length != 2) {
    return null;
  }
  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  final startHour = int.tryParse(startParts[0]);
  final startMinute = int.tryParse(startParts[1]);
  final endHour = int.tryParse(endParts[0]);
  final endMinute = int.tryParse(endParts[1]);
  if (year == null ||
      month == null ||
      day == null ||
      startHour == null ||
      startMinute == null ||
      endHour == null ||
      endMinute == null) {
    return null;
  }
  final start = DateTime(year, month, day, startHour, startMinute);
  var end = DateTime(year, month, day, endHour, endMinute);
  if (!end.isAfter(start)) {
    end = end.add(const Duration(days: 1));
  }
  return _TimeWindow(start: start, end: end);
}
