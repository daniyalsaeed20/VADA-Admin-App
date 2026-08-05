import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/domain/address_fields.dart';

class Fighter {
  const Fighter({
    required this.uid,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.stateCounty,
    required this.postalCode,
    required this.country,
    required this.primaryContactPerson,
    required this.disabled,
    required this.createdAt,
    required this.updatedAt,
    this.testingWindowStart = '',
    this.testingWindowEnd = '',
  });

  final String uid;
  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String stateCounty;
  final String postalCode;
  final String country;
  final String primaryContactPerson;
  final bool disabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Daily 60-minute testing collection window start (`HH:mm`).
  final String testingWindowStart;

  /// Daily 60-minute testing collection window end (`HH:mm`).
  final String testingWindowEnd;

  AddressFields get addressFields => AddressFields(
        address: address,
        city: city,
        stateCounty: stateCounty,
        postalCode: postalCode,
        country: country,
      );

  String get formattedAddress => addressFields.formatted;

  String get formattedTestingWindow {
    final start = testingWindowStart.trim();
    final end = testingWindowEnd.trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start – $end';
  }

  Fighter copyWith({
    String? testingWindowStart,
    String? testingWindowEnd,
  }) {
    return Fighter(
      uid: uid,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      phone: phone,
      email: email,
      address: address,
      city: city,
      stateCounty: stateCounty,
      postalCode: postalCode,
      country: country,
      primaryContactPerson: primaryContactPerson,
      disabled: disabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
      testingWindowStart: testingWindowStart ?? this.testingWindowStart,
      testingWindowEnd: testingWindowEnd ?? this.testingWindowEnd,
    );
  }

  factory Fighter.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final address = AddressFields.fromMap(data);
    return Fighter(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: address.address,
      city: address.city,
      stateCounty: address.stateCounty,
      postalCode: address.postalCode,
      country: address.country,
      primaryContactPerson: data['primaryContactPerson'] as String? ?? '',
      disabled: data['disabled'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
