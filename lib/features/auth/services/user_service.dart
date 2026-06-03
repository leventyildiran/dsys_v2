import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../core/services/firestore_service.dart';

class UserService {
  UserService({FirestoreService? firestoreService})
      : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _service.usersCollection;

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(uid, doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers({bool onlyActive = true}) async {
    try {
      Query<Map<String, dynamic>> query = _usersRef;
      if (onlyActive) {
        query = query.where('aktif', isEqualTo: true);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _usersRef.doc(user.uid).set(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _usersRef.doc(uid).update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deactivateUser(String uid) async {
    await updateUser(uid, {'aktif': false});
  }

  Stream<List<UserModel>> usersStream({bool onlyActive = true}) {
    Query<Map<String, dynamic>> query = _usersRef;
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
