import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/birim_model.dart';

class BirimService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('birimler');

  Future<List<BirimModel>> getAll({bool onlyActive = true}) async {
    Query query = _collection.orderBy('ad');
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return BirimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<BirimModel>> stream({bool onlyActive = true}) {
    Query query = _collection.orderBy('ad');
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BirimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> create(BirimModel model) async {
    await _collection.add(model.toMap());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _collection.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}
