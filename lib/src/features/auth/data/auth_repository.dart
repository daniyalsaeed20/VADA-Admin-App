import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const Duration _adminCacheTtl = Duration(minutes: 5);
  String? _cachedAdminUid;
  bool? _cachedIsAdmin;
  DateTime? _cachedAdminCheckedAt;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    _clearAdminCache();
    await _auth.signOut();
  }

  Future<bool> isAdmin(String uid) async {
    if (_cachedAdminUid == uid &&
        _cachedIsAdmin != null &&
        _cachedAdminCheckedAt != null &&
        DateTime.now().difference(_cachedAdminCheckedAt!) < _adminCacheTtl) {
      return _cachedIsAdmin!;
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    final role = snapshot.data()?['role'];
    final isAdmin = role == 'admin';
    _cachedAdminUid = uid;
    _cachedIsAdmin = isAdmin;
    _cachedAdminCheckedAt = DateTime.now();
    return isAdmin;
  }

  void _clearAdminCache() {
    _cachedAdminUid = null;
    _cachedIsAdmin = null;
    _cachedAdminCheckedAt = null;
  }
}
