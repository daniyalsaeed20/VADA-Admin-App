import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Contact.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Contact(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      address: data['address'] as String? ?? '',
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
