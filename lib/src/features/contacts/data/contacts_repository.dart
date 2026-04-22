import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../domain/contact.dart';

class ContactsRepository {
  const ContactsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _contacts =>
      _firestore.collection(FirestoreCollections.contacts);

  Stream<List<Contact>> watchContacts() {
    return _contacts.snapshots().map((snapshot) {
      final contacts = snapshot.docs
          .where((doc) => doc.id != FirestoreCollections.metaDoc)
          .map((doc) => Contact.fromFirestore(doc))
          .toList();

      contacts.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        if (aDate == null && bDate == null) {
          return a.name.compareTo(b.name);
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      return contacts;
    });
  }

  Future<void> createContact({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String role,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _contacts.add({
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      'role': role.trim().toLowerCase(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> updateContact({
    required String id,
    required String name,
    required String phone,
    required String email,
    required String address,
    required String role,
  }) async {
    await _contacts.doc(id).set({
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'address': address.trim(),
      'role': role.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
