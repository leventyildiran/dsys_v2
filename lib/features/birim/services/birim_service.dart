import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../models/birim_model.dart';

class BirimService {
  BirimService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'birimler';

  CollectionReference<Map<String, dynamic>> get _collectionRef =>
      _service.collection(_collection);

  Future<List<BirimModel>> getAll({bool onlyActive = true}) async {
    Query<Map<String, dynamic>> query = _collectionRef.orderBy('ad');
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => BirimModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<BirimModel>> stream({bool onlyActive = true}) {
    Query<Map<String, dynamic>> query = _collectionRef.orderBy('ad');
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => BirimModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> create(BirimModel model) async {
    await _collectionRef.add(model.toMap());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _collectionRef.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _collectionRef.doc(id).delete();
  }
}
