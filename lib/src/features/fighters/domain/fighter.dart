import 'package:cloud_firestore/cloud_firestore.dart';

class Fighter {
  const Fighter({
    required this.uid,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    required this.primaryContactPerson,
    required this.disabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String primaryContactPerson;
  final bool disabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Fighter.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Fighter(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
      primaryContactPerson: data['primaryContactPerson'] as String? ?? '',
      disabled: data['disabled'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
