import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleChangeRequestType {
  newLocation('new_location', 'New / testing location'),
  timeChange('time_change', 'Time change'),
  scheduleUpdate('schedule_update', 'Schedule update');

  const ScheduleChangeRequestType(this.value, this.label);
  final String value;
  final String label;

  static ScheduleChangeRequestType? fromValue(String? raw) {
    final v = raw?.trim() ?? '';
    for (final type in ScheduleChangeRequestType.values) {
      if (type.value == v) {
        return type;
      }
    }
    return null;
  }
}

enum ScheduleChangeRequestStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const ScheduleChangeRequestStatus(this.value, this.label);
  final String value;
  final String label;

  static ScheduleChangeRequestStatus? fromValue(String? raw) {
    final v = raw?.trim() ?? '';
    for (final status in ScheduleChangeRequestStatus.values) {
      if (status.value == v) {
        return status;
      }
    }
    return null;
  }

  bool get isPending => this == ScheduleChangeRequestStatus.pending;
}

class ScheduleChangeRequest {
  const ScheduleChangeRequest({
    required this.id,
    required this.fighterId,
    required this.requestType,
    required this.status,
    required this.scheduleId,
    required this.currentSnapshot,
    required this.requestedChanges,
    required this.notes,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
    required this.reviewedBy,
  });

  final String id;
  final String fighterId;
  final ScheduleChangeRequestType? requestType;
  final ScheduleChangeRequestStatus? status;
  final String? scheduleId;
  final Map<String, dynamic> currentSnapshot;
  final Map<String, dynamic> requestedChanges;
  final String notes;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  bool get isPending => status == ScheduleChangeRequestStatus.pending;

  String get requestTypeLabel =>
      requestType?.label ?? (requestedChanges.isEmpty ? 'Unknown' : 'Request');

  String get statusLabel => status?.label ?? 'Unknown';

  String get notesPreview {
    final text = notes.trim();
    if (text.isEmpty) {
      return '—';
    }
    if (text.length <= 80) {
      return text;
    }
    return '${text.substring(0, 80)}…';
  }

  /// Requested changes first, then current snapshot, for list/dashboard previews.
  String get changeSummary => summarizeScheduleChangeFields(
        requestedChanges,
        fallbackSnapshot: currentSnapshot,
      );

  String? schedulePreviewFromSnapshot() {
    final summary = changeSummary.trim();
    if (summary.isNotEmpty) {
      return summary;
    }
    final snapshot = currentSnapshot;
    if (snapshot.isEmpty) {
      return null;
    }
    final date = readScheduleField(snapshot, const ['date', 'scheduleDate']);
    final location = readScheduleField(snapshot, const [
      'locationName',
      'location',
    ]);
    if (date.isEmpty && location.isEmpty) {
      return null;
    }
    if (date.isEmpty) {
      return location;
    }
    if (location.isEmpty) {
      return date;
    }
    return '$date • $location';
  }

  factory ScheduleChangeRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ScheduleChangeRequest(
      id: doc.id,
      fighterId: data['fighterId'] as String? ?? '',
      requestType: ScheduleChangeRequestType.fromValue(
        data['requestType'] as String?,
      ),
      status: ScheduleChangeRequestStatus.fromValue(data['status'] as String?),
      scheduleId: _optionalString(data['scheduleId']),
      currentSnapshot: _asMap(data['currentSnapshot']),
      requestedChanges: _asMap(data['requestedChanges']),
      notes: data['notes'] as String? ?? '',
      adminNotes: _optionalString(data['adminNotes']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: _optionalString(data['reviewedBy']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String? _optionalString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String readScheduleField(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      if (keys.contains('date') || keys.contains('scheduleDate')) {
        final month = dt.month.toString().padLeft(2, '0');
        final day = dt.day.toString().padLeft(2, '0');
        return '${dt.year}-$month-$day';
      }
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }
  return '';
}

String formatTimestampField(dynamic value) {
  if (value is Timestamp) {
    final dt = value.toDate().toLocal();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return '—';
}

/// Human-readable summary of requested schedule fields for lists and dashboard.
String summarizeScheduleChangeFields(
  Map<String, dynamic> changes, {
  Map<String, dynamic>? fallbackSnapshot,
}) {
  String field(List<String> keys) {
    final fromChanges = readScheduleField(changes, keys);
    if (fromChanges.isNotEmpty) {
      return fromChanges;
    }
    if (fallbackSnapshot != null) {
      return readScheduleField(fallbackSnapshot, keys);
    }
    return '';
  }

  final date = field(const ['date', 'scheduleDate']);
  final start = field(const ['startTime', 'fromTime']);
  final end = field(const ['endTime', 'toTime']);
  var location = readScheduleField(changes, const [
    'locationName',
    'location',
    'newLocationName',
    'proposedLocationText',
  ]);
  if (location.isEmpty && fallbackSnapshot != null) {
    location = readScheduleField(fallbackSnapshot, const [
      'locationName',
      'location',
    ]);
  }
  final addr = readScheduleField(changes, const [
    'locationAddress',
    'siteAddress',
    'newLocationAddress',
  ]);
  if (location.isNotEmpty && addr.isNotEmpty && location != addr) {
    location = '$location\n$addr';
  } else if (location.isEmpty && addr.isNotEmpty) {
    location = addr;
  }

  final parts = <String>[];
  if (date.isNotEmpty) {
    var line = date;
    if (start.isNotEmpty || end.isNotEmpty) {
      final startLabel = start.isEmpty ? '?' : start;
      final endLabel = end.isEmpty ? '?' : end;
      line = '$line • $startLabel–$endLabel';
    }
    parts.add(line);
  } else if (start.isNotEmpty || end.isNotEmpty) {
    parts.add('${start.isEmpty ? "?" : start}–${end.isEmpty ? "?" : end}');
  }
  if (location.isNotEmpty) {
    parts.add(location);
  }
  return parts.join('\n');
}

bool hasScheduleApplyFields(Map<String, dynamic> changes) {
  const keys = [
    'date',
    'scheduleDate',
    'startTime',
    'endTime',
    'startAt',
    'endAt',
    'locationId',
    'locationName',
    'proposedLocationText',
    'locationAddress',
    'siteAddress',
    'newLocationName',
    'newLocationAddress',
    'contactId',
    'contactName',
    'notes',
  ];
  for (final key in keys) {
    final value = changes[key];
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return true;
  }
  return false;
}
