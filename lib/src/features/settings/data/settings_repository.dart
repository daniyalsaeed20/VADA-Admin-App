import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/notification_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _notificationSettingsDoc =>
      _firestore
          .collection(FirestoreCollections.settings)
          .doc('notifications');

  Stream<NotificationSettings> watchNotificationSettings() {
    return _notificationSettingsDoc.snapshots().map((doc) {
      if (!doc.exists) return NotificationSettings.defaults();
      return NotificationSettings.fromFirestore(doc);
    });
  }

  Future<NotificationSettings> getNotificationSettings() async {
    final doc = await _notificationSettingsDoc.get();
    if (!doc.exists) return NotificationSettings.defaults();
    return NotificationSettings.fromFirestore(doc);
  }

  Future<void> updateNotificationSettings(NotificationSettings next) async {
    await _notificationSettingsDoc.set(next.toFirestore(), SetOptions(merge: true));
  }
}

