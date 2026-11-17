import 'package:cloud_firestore/cloud_firestore.dart';

import '../../locations/domain/location_lookup.dart';

class WhereaboutsEntry {
  const WhereaboutsEntry({
    required this.id,
    required this.fighterId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.locationId,
    required this.locationName,
    required this.contactId,
    required this.notes,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
    this.pickedCoordinates,
    this.seriesId,
    this.seriesWeekdays = const [],
    this.seriesStartDate,
    this.seriesEndDate,
    this.seriesMonths,
  });

  final String id;
  final String fighterId;
  final String date;
  final String startTime;
  final String endTime;
  final String locationId;
  final String locationName;
  final String contactId;
  final String notes;
  final String recurrence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Set when the fighter picked their own location on the map in the mobile
  /// app instead of a location from the directory.
  final MapCoordinates? pickedCoordinates;

  bool get isOwnLocation => pickedCoordinates != null;

  /// Shared by every entry the mobile app created in one repeating
  /// submission; null for single entries.
  final String? seriesId;

  /// Weekly series only: [DateTime.weekday] values (1 = Mon … 7 = Sun).
  final List<int> seriesWeekdays;

  /// First date of the series range ("YYYY-MM-DD").
  final String? seriesStartDate;

  /// Daily/weekly series only: last date of the range ("YYYY-MM-DD").
  final String? seriesEndDate;

  /// Monthly series only: number of months covered.
  final int? seriesMonths;

  bool get isInSeries => seriesId != null;

  /// Sortable "YYYY-MM-DD HH:mm" key used to find later entries in a series.
  String get sortKey => '$date $startTime';

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
      ]),
      locationName: _readString(data, const [
        'locationName',
        'location',
        'proposedLocationText',
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
      pickedCoordinates: data['locationSource'] == 'custom'
          ? readPickedCoordinates(data)
          : null,
      seriesId: _nonEmpty(_readString(data, const ['seriesId'])),
      seriesWeekdays: (data['seriesWeekdays'] is List)
          ? (data['seriesWeekdays'] as List)
                .whereType<num>()
                .map((n) => n.toInt())
                .where((n) => n >= 1 && n <= 7)
                .toList()
          : const [],
      seriesStartDate: _nonEmpty(
        _readDateString(data, const ['seriesStartDate']),
      ),
      seriesEndDate: _nonEmpty(_readDateString(data, const ['seriesEndDate'])),
      seriesMonths: (data['seriesMonths'] as num?)?.toInt(),
    );
  }
}

String resolveLocationDisplay(
  WhereaboutsEntry entry,
  Map<String, String> locationNamesById,
) {
  if (entry.locationName.trim().isNotEmpty) {
    return entry.locationName.trim();
  }
  final fromId = locationNamesById[entry.locationId];
  if (fromId != null && fromId.trim().isNotEmpty) {
    return fromId.trim();
  }
  return entry.locationId;
}

String? _nonEmpty(String value) => value.isEmpty ? null : value;

/// Normalizes the stored repeat value. `none` is written by the mobile app for
/// single (non-repeating) entries; empty/unknown legacy values stay `daily`.
String normalizeRecurrence(String? rawValue) {
  final value = rawValue?.trim().toLowerCase() ?? '';
  switch (value) {
    case 'none':
      return 'none';
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

/// Human-readable repeat value, e.g. for notifications.
String recurrenceDisplay(String? rawValue) {
  switch (normalizeRecurrence(rawValue)) {
    case 'none':
      return 'Only once';
    case 'weekly':
      return 'Weekly';
    case 'monthly':
      return 'Monthly';
    default:
      return 'Daily';
  }
}

const _weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One-line description of the series an entry belongs to, e.g.
/// "Weekly · Tue, Thu · 2026-12-01 to 2026-12-31". Empty for single entries.
String seriesSummary(WhereaboutsEntry entry) {
  if (!entry.isInSeries) return '';
  final parts = <String>[recurrenceDisplay(entry.recurrence)];
  switch (normalizeRecurrence(entry.recurrence)) {
    case 'weekly':
      final days = [...entry.seriesWeekdays]..sort();
      if (days.isNotEmpty) {
        parts.add(days.map((d) => _weekdayShortNames[d - 1]).join(', '));
      }
    case 'monthly':
      final day = entry.seriesStartDate?.split('-').last;
      if (day != null) parts.add('day ${int.tryParse(day) ?? day}');
      final months = entry.seriesMonths;
      if (months != null) {
        parts.add('$months ${months == 1 ? 'month' : 'months'}');
      }
  }
  final start = entry.seriesStartDate;
  final end = entry.seriesEndDate;
  if (start != null && end != null) {
    parts.add('$start to $end');
  } else if (start != null) {
    parts.add('from $start');
  }
  return parts.join(' · ');
}
