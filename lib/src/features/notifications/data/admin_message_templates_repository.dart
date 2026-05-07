import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/admin_message_template.dart';

class AdminMessageTemplatesRepository {
  const AdminMessageTemplatesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection(FirestoreCollections.adminMessageTemplates);

  Stream<List<AdminMessageTemplate>> watchTemplates({int limit = 100}) {
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) => d.id != FirestoreCollections.metaDoc)
              .map(AdminMessageTemplate.fromFirestore)
              .toList(),
        );
  }

  Future<String> create({
    required String name,
    required String title,
    required String body,
  }) async {
    final doc = await _col.add({
      'name': name.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update({
    required String id,
    required String name,
    required String title,
    required String body,
  }) async {
    await _col.doc(id).set({
      'name': name.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete({required String id}) async {
    await _col.doc(id).delete();
  }
}

