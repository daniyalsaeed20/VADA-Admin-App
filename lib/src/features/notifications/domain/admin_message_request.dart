import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMessageRequest {
  const AdminMessageRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
    required this.targetUserId,
    required this.data,
    required this.status,
    required this.createdAt,
    required this.sentAt,
    required this.errorMessage,
  });

  final String id;
  final String title;
  final String body;
  final String target; // broadcast | user
  final String? targetUserId;
  final Map<String, String> data;
  final String status; // pending | sent | failed
  final DateTime? createdAt;
  final DateTime? sentAt;
  final String? errorMessage;

  factory AdminMessageRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminMessageRequest(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      target: (data['target'] as String? ?? 'broadcast').trim(),
      targetUserId: (data['targetUserId'] as String?)?.trim(),
      data: (data['data'] as Map<String, dynamic>? ?? const <String, dynamic>{})
          .map((k, v) => MapEntry(k, v.toString())),
      status: (data['status'] as String? ?? 'pending').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      errorMessage: (data['errorMessage'] as String?)?.trim(),
    );
  }
}

