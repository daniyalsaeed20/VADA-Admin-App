import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMessageTemplate {
  const AdminMessageTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String title;
  final String body;
  final DateTime? updatedAt;

  factory AdminMessageTemplate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminMessageTemplate(
      id: doc.id,
      name: (data['name'] as String? ?? '').trim(),
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

