import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/taksit_model.dart';

class TaksitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _path(String danismanlikId) => 'danismanliklar/$danismanlikId/taksitler';

  Future<void> create(String danismanlikId, TaksitModel model) async {
    try {
      await _firestore.collection(_path(danismanlikId)).add(model.toMap());
    } catch (e) {
      debugPrint('Taksit oluşturulurken hata: $e');
      rethrow;
    }
  }

  Future<void> update(String danismanlikId, String taksitId, TaksitModel model) async {
    try {
      await _firestore.collection(_path(danismanlikId)).doc(taksitId).update(model.toMap());
    } catch (e) {
      debugPrint('Taksit güncellenirken hata: $e');
      rethrow;
    }
  }

  Future<void> delete(String danismanlikId, String taksitId) async {
    try {
      await _firestore.collection(_path(danismanlikId)).doc(taksitId).delete();
    } catch (e) {
      debugPrint('Taksit silinirken hata: $e');
      rethrow;
    }
  }

  Future<void> updateDurum(String danismanlikId, String taksitId, TaksitDurum durum) async {
    try {
      await _firestore.collection(_path(danismanlikId)).doc(taksitId).update({'durum': durum.value});
    } catch (e) {
      debugPrint('Taksit durumu güncellenirken hata: $e');
      rethrow;
    }
  }

  Stream<List<TaksitModel>> streamTaksitler(String danismanlikId) {
    return _firestore
        .collection(_path(danismanlikId))
        .orderBy('ayNo')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaksitModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}
