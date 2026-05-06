import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/admin_message_request.dart';

class NotificationsRepository {
  const NotificationsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  Stream<List<AdminMessageRequest>> watchAdminMessages({int limit = 50}) {
    return _notifications
        .where('type', isEqualTo: 'admin_message')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AdminMessageRequest.fromFirestore).toList());
  }

  Future<void> createAdminMessage({
    required String title,
    required String body,
    required String target, // broadcast | user
    String? targetUserId,
    Map<String, String>? data,
    required String createdBy,
  }) async {
    final payload = <String, dynamic>{
      'type': 'admin_message',
      'title': title.trim(),
      'body': body.trim(),
      'target': target.trim(),
      'targetUserId': (targetUserId ?? '').trim(),
      'data': data ?? <String, String>{},
      'status': 'pending',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _notifications.add(payload);
  }

  Future<void> createScheduleUpdate({
    required String title,
    required String body,
    required String fighterId,
    required String scheduleId,
    required String createdBy,
  }) async {
    final payload = <String, dynamic>{
      'type': 'schedule_update',
      'title': title.trim(),
      'body': body.trim(),
      'target': 'user',
      'targetUserId': fighterId.trim(),
      'data': <String, String>{
        'screen': 'whereabouts',
        'scheduleId': scheduleId,
      },
      'status': 'pending',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _notifications.add(payload);
  }
}

