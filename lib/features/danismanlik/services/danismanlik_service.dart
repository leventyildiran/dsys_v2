import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../models/danismanlik_model.dart';

class DanismanlikService {
  DanismanlikService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'danismanliklar';

  CollectionReference<Map<String, dynamic>> get _collectionRef =>
      _service.collection(_collection);

  Future<void> create(DanismanlikModel model) async {
    try {
      await _collectionRef.add(model.toMap());
    } catch (e) {
      throw Exception('Danışmanlık oluşturulurken hata: $e');
    }
  }

  Future<void> update(String id, DanismanlikModel model) async {
    try {
      await _collectionRef.doc(id).update(model.toMap());
    } catch (e) {
      throw Exception('Danışmanlık güncellenirken hata: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _collectionRef.doc(id).delete();
    } catch (e) {
      throw Exception('Danışmanlık silinirken hata: $e');
    }
  }

  Future<void> updateDurum(String id, DanismanlikDurum durum) async {
    try {
      await _collectionRef.doc(id).update({'durum': durum.value});
    } catch (e) {
      throw Exception('Durum güncellenirken hata: $e');
    }
  }

  Future<DanismanlikModel?> getById(String id) async {
    try {
      final doc = await _collectionRef.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return DanismanlikModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw Exception('Danışmanlık okunurken hata: $e');
    }
  }

  Stream<List<DanismanlikModel>> streamByBirim(String birimId) {
    return _collectionRef
        .where('birimId', isEqualTo: birimId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DanismanlikModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<DanismanlikModel>> streamAll() {
    return _collectionRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DanismanlikModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
