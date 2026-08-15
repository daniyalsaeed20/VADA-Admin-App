import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/domain/address_fields.dart';

class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.stateCounty,
    required this.postalCode,
    required this.country,
    required this.type,
    required this.assignedFighterIds,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String stateCounty;
  final String postalCode;
  final String country;
  final String type;
  final List<String> assignedFighterIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  AddressFields get addressFields => AddressFields(
        address: address,
        city: city,
        stateCounty: stateCounty,
        postalCode: postalCode,
        country: country,
      );

  String get formattedAddress => addressFields.formatted;

  factory LocationRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final address = AddressFields.fromMap(data);
    final geoPoint = data['geoPoint'];
    return LocationRecord(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: address.address,
      city: address.city,
      stateCounty: address.stateCounty,
      postalCode: address.postalCode,
      country: address.country,
      type: data['type'] as String? ?? 'testing',
      assignedFighterIds: (data['assignedFighterIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      latitude: geoPoint is GeoPoint ? geoPoint.latitude : null,
      longitude: geoPoint is GeoPoint ? geoPoint.longitude : null,
    );
  }
}
