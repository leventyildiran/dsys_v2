import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_request_model.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class UserRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  // Submit a registration request (no auth needed)
  Future<void> submitRequest(UserRequestModel request) async {
    await _firestore.collection('pendingRequests').add(request.toMap());
  }

  // Stream pending requests for admin view
  Stream<List<UserRequestModel>> streamPendingRequests() {
    return _firestore
        .collection('pendingRequests')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => UserRequestModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Approve a request: create Firebase Auth user, create UserModel, set approved, remove request
  UserRole _mapLegacyRole(String roleStr) {
    switch (roleStr) {
      case 'admin':
      case 'super_admin':
        return UserRole.superAdmin;
      case 'editor':
      case 'yk_sekreteri':
        return UserRole.ykSekreteri;
      case 'birim_muduru':
        return UserRole.birimMuduru;
      default:
        return UserRole.fromString(roleStr);
    }
  }

  Future<void> approveRequest(String docId) async {
    final doc = await _firestore.collection('pendingRequests').doc(docId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final email = data['email'] as String;
    final roleStr = data['role'] as String;

    // Create Firebase Auth user via Admin SDK placeholder (needs server side).
    // Here we just assume the user is created and we get a uid.
    // In real app use Firebase Functions or admin SDK.
    final uid = email; // placeholder uid; replace with real uid after creation.

    final user = UserModel(
      uid: uid,
      displayName: data['name'] as String? ?? email,
      email: email,
      role: _mapLegacyRole(roleStr),
      aktif: true,
    );
    await _userService.createUser(user);
    await _firestore.collection('pendingRequests').doc(docId).delete();
  }
}
