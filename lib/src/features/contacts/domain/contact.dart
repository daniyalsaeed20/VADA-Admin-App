import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/domain/address_fields.dart';

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.stateCounty,
    required this.postalCode,
    required this.country,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String stateCounty;
  final String postalCode;
  final String country;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressFields get addressFields => AddressFields(
        address: address,
        city: city,
        stateCounty: stateCounty,
        postalCode: postalCode,
        country: country,
      );

  String get formattedAddress => addressFields.formatted;

  factory Contact.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final address = AddressFields.fromMap(data);
    return Contact(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: address.address,
      city: address.city,
      stateCounty: address.stateCounty,
      postalCode: address.postalCode,
      country: address.country,
      role: normalizeContactRole(data['role'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

String normalizeContactRole(String? rawRole) {
  final value = rawRole?.trim().toLowerCase() ?? '';
  switch (value) {
    case 'trainer':
      return 'trainer';
    case 'manager':
      return 'manager';
    case 'promoter':
    case 'promotor':
      return 'promoter';
    default:
      return 'other';
  }
}
