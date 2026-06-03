import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/danismanlik_model.dart';

class DanismanlikService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection('danismanliklar');

  Future<void> create(DanismanlikModel model) async {
    try {
      await _collection.add(model.toMap());
    } catch (e) {
      throw Exception('Danışmanlık oluşturulurken hata: $e');
    }
  }

  Future<void> update(String id, DanismanlikModel model) async {
    try {
      await _collection.doc(id).update(model.toMap());
    } catch (e) {
      throw Exception('Danışmanlık güncellenirken hata: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw Exception('Danışmanlık silinirken hata: $e');
    }
  }

  Future<void> updateDurum(String id, DanismanlikDurum durum) async {
    try {
      await _collection.doc(id).update({'durum': durum.value});
    } catch (e) {
      throw Exception('Durum güncellenirken hata: $e');
    }
  }

  Stream<List<DanismanlikModel>> streamByBirim(String birimId) {
    return _collection
        .where('birimId', isEqualTo: birimId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                DanismanlikModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<DanismanlikModel>> streamAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                DanismanlikModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }
}
