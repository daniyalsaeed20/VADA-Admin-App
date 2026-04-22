import 'package:cloud_firestore/cloud_firestore.dart';

class WhereaboutsEntry {
  const WhereaboutsEntry({
    required this.id,
    required this.fighterId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.locationId,
    required this.contactId,
    required this.notes,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fighterId;
  final String date;
  final String startTime;
  final String endTime;
  final String locationId;
  final String contactId;
  final String notes;
  final String recurrence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WhereaboutsEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return WhereaboutsEntry(
      id: doc.id,
      fighterId: _readString(data, const [
        'fighterId',
        'athleteId',
        'userId',
        'uid',
      ]),
      date: _readDateString(data, const ['date', 'scheduleDate']),
      startTime: _readString(data, const ['startTime', 'fromTime', 'start']),
      endTime: _readString(data, const ['endTime', 'toTime', 'end']),
      locationId: _readString(data, const [
        'locationId',
        'selectedLocation',
        'location',
      ]),
      contactId: _readString(data, const [
        'contactId',
        'selectedContact',
        'contact',
      ]),
      notes: _readString(data, const ['notes', 'comment', 'remarks']),
      recurrence: normalizeRecurrence(
        _readString(data, const ['recurrence', 'frequency', 'repeat']),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

String normalizeRecurrence(String? rawValue) {
  final value = rawValue?.trim().toLowerCase() ?? '';
  switch (value) {
    case 'daily':
      return 'daily';
    case 'weekly':
      return 'weekly';
    case 'monthly':
      return 'monthly';
    default:
      return 'daily';
  }
}

String _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    if (value is String) {
      return value.trim();
    }
    if (value is DocumentReference) {
      return value.id;
    }
    return value.toString().trim();
  }
  return '';
}

String _readDateString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    if (value is String) {
      return value.trim();
    }
    if (value is Timestamp) {
      final dt = value.toDate();
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '${dt.year}-$month-$day';
    }
    return value.toString().trim();
  }
  return '';
}
