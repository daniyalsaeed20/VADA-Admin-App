import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../whereabouts/domain/whereabouts_entry.dart';
import '../domain/schedule_change_request.dart';

/// Builds a Firestore merge patch for `schedules/{id}` from approved `requestedChanges`.
class ScheduleApplyMapper {
  const ScheduleApplyMapper(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>> buildPatch({
    required Map<String, dynamic> requestedChanges,
    required String fighterId,
    required WhereaboutsEntry existing,
  }) async {
    final patch = <String, dynamic>{
      'fighterId': fighterId.trim().isEmpty ? existing.fighterId : fighterId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final date = _extractDate(requestedChanges);
    _putString(patch, 'date', date);
    _putString(patch, 'scheduleDate', date);

    final startTime = _extractTimeString(
      requestedChanges,
      const ['startTime', 'fromTime', 'start'],
      const ['startAt'],
    );
    _putString(patch, 'startTime', startTime);

    final endTime = _extractTimeString(
      requestedChanges,
      const ['endTime', 'toTime', 'end'],
      const ['endAt'],
    );
    _putString(patch, 'endTime', endTime);

    _putTimestamp(patch, 'startAt', requestedChanges['startAt']);
    _putTimestamp(patch, 'endAt', requestedChanges['endAt']);

    // If only timestamps were sent, ensure string times exist for admin web.
    if (!patch.containsKey('startTime') && patch['startAt'] is Timestamp) {
      _putString(
        patch,
        'startTime',
        DateFormat('HH:mm').format((patch['startAt'] as Timestamp).toDate().toLocal()),
      );
    }
    if (!patch.containsKey('endTime') && patch['endAt'] is Timestamp) {
      _putString(
        patch,
        'endTime',
        DateFormat('HH:mm').format((patch['endAt'] as Timestamp).toDate().toLocal()),
      );
    }

    final locationId = readScheduleField(requestedChanges, const [
      'locationId',
      'selectedLocation',
    ]);
    _putString(patch, 'locationId', locationId);

    final locationName = await _resolveLocationName(
      locationId: locationId,
      requestedChanges: requestedChanges,
    );
    _putString(patch, 'locationName', locationName);

    final proposedText = readScheduleField(requestedChanges, const [
      'proposedLocationText',
    ]);
    _putString(patch, 'proposedLocationText', proposedText);

    final contactId = readScheduleField(requestedChanges, const [
      'contactId',
      'selectedContact',
    ]);
    _putString(patch, 'contactId', contactId);

    final contactName = readScheduleField(requestedChanges, const [
      'contactName',
      'contact',
    ]);
    if (contactName.isNotEmpty) {
      _putString(patch, 'contactName', contactName);
    } else if (contactId.isNotEmpty) {
      final resolved = await _readLocationOrContactName(
        collection: FirestoreCollections.contacts,
        docId: contactId,
      );
      _putString(patch, 'contactName', resolved);
    }

    final notes = readScheduleField(requestedChanges, const [
      'notes',
      'comment',
      'remarks',
    ]);
    _putString(patch, 'notes', notes);

    final recurrence = readScheduleField(requestedChanges, const [
      'recurrence',
      'frequency',
      'repeat',
    ]);
    if (recurrence.isNotEmpty) {
      patch['recurrence'] = normalizeRecurrence(recurrence);
    }

    patch.removeWhere((key, value) => value == null);
    return patch;
  }

  Future<String> _resolveLocationName({
    required String locationId,
    required Map<String, dynamic> requestedChanges,
  }) async {
    final direct = readScheduleField(requestedChanges, const [
      'locationName',
      'location',
    ]);
    if (direct.isNotEmpty) {
      return direct;
    }
    if (locationId.isNotEmpty) {
      final fromDirectory = await _readLocationOrContactName(
        collection: FirestoreCollections.locations,
        docId: locationId,
      );
      if (fromDirectory.isNotEmpty) {
        return fromDirectory;
      }
    }
    return readScheduleField(requestedChanges, const ['proposedLocationText']);
  }

  Future<String> _readLocationOrContactName({
    required String collection,
    required String docId,
  }) async {
    if (docId.trim().isEmpty) {
      return '';
    }
    try {
      final snap =
          await _firestore.collection(collection).doc(docId.trim()).get();
      final name = snap.data()?['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  String? _extractDate(Map<String, dynamic> data) {
    final direct = readScheduleField(data, const ['date', 'scheduleDate']);
    if (direct.isNotEmpty) {
      return direct;
    }
    for (final key in const ['startAt', 'date']) {
      final value = data[key];
      if (value is Timestamp) {
        return DateFormat('yyyy-MM-dd').format(value.toDate().toLocal());
      }
    }
    return null;
  }

  String? _extractTimeString(
    Map<String, dynamic> data,
    List<String> stringKeys,
    List<String> timestampKeys,
  ) {
    final direct = readScheduleField(data, stringKeys);
    if (direct.isNotEmpty) {
      return direct;
    }
    for (final key in timestampKeys) {
      final value = data[key];
      if (value is Timestamp) {
        return DateFormat('HH:mm').format(value.toDate().toLocal());
      }
    }
    return null;
  }

  void _putString(Map<String, dynamic> patch, String key, String? value) {
    if (value == null || value.trim().isEmpty) {
      return;
    }
    patch[key] = value.trim();
  }

  void _putTimestamp(Map<String, dynamic> patch, String key, dynamic value) {
    if (value is Timestamp) {
      patch[key] = value;
    }
  }
}
