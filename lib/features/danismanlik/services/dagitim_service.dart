import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dagitim_model.dart';

class DagitimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _path(String danismanlikId, String taksitId) =>
      'danismanliklar/$danismanlikId/taksitler/$taksitId/dagitim';

  Future<void> kaydet(String danismanlikId, String taksitId, DagitimModel dagitim) async {
    try {
      await _firestore
          .collection(_path(danismanlikId, taksitId))
          .doc(dagitim.personelId)
          .set(dagitim.toMap());
    } catch (e) {
      debugPrint('Dagitim kaydedilirken hata: $e');
      rethrow;
    }
  }

  Future<void> topluKaydet(String danismanlikId, String taksitId, List<DagitimModel> dagitimlar) async {
    try {
      final batch = _firestore.batch();
      final collRef = _firestore.collection(_path(danismanlikId, taksitId));

      for (final dagitim in dagitimlar) {
        batch.set(collRef.doc(dagitim.personelId), dagitim.toMap());
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Toplu dagitim kaydedilirken hata: $e');
      rethrow;
    }
  }

  Future<List<DagitimModel>> getAll(String danismanlikId, String taksitId) async {
    try {
      final snapshot = await _firestore.collection(_path(danismanlikId, taksitId)).get();
      return snapshot.docs.map((doc) => DagitimModel.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      debugPrint('Dagitimlar getirilirken hata: $e');
      return [];
    }
  }

  Stream<List<DagitimModel>> stream(String danismanlikId, String taksitId) {
    return _firestore
        .collection(_path(danismanlikId, taksitId))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DagitimModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}
