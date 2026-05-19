import 'package:cloud_firestore/cloud_firestore.dart';

class CheckinRecord {
  const CheckinRecord({
    required this.id,
    required this.fighterId,
    required this.latitude,
    required this.longitude,
    required this.timestampMillis,
    required this.createdAt,
    required this.accuracyMeters,
    required this.label,
  });

  final String id;
  final String fighterId;
  final double latitude;
  final double longitude;
  final int timestampMillis;
  final DateTime? createdAt;
  final double? accuracyMeters;
  final String? label;

  DateTime? get capturedAt {
    if (timestampMillis <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestampMillis);
  }

  factory CheckinRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final location = data['location'];
    final geoPoint = location is GeoPoint ? location : null;
    final timestampRaw = data['timestampMillis'];
    final accuracyRaw = data['accuracyMeters'];

    return CheckinRecord(
      id: doc.id,
      fighterId: data['fighterId'] as String? ?? '',
      latitude: geoPoint?.latitude ?? 0,
      longitude: geoPoint?.longitude ?? 0,
      timestampMillis: (timestampRaw is num) ? timestampRaw.toInt() : 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      accuracyMeters: (accuracyRaw is num) ? accuracyRaw.toDouble() : null,
      label: (data['label'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['label'] as String).trim(),
    );
  }
}
