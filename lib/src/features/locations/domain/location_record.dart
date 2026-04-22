import 'package:cloud_firestore/cloud_firestore.dart';

class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.assignedFighterIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final String type;
  final List<String> assignedFighterIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory LocationRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return LocationRecord(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      type: data['type'] as String? ?? 'testing',
      assignedFighterIds: (data['assignedFighterIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
