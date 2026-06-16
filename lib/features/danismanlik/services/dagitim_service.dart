import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../models/dagitim_model.dart';

class DagitimService {
  DagitimService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _danismanlikCollection = 'danismanliklar';
  static const _taksitCollection = 'taksitler';
  static const _dagitimCollection = 'dagitimlar';

  CollectionReference<Map<String, dynamic>> _dagitimRef(
    String danismanlikId,
    String taksitId,
  ) => _service
      .nestedCollection(
        _danismanlikCollection,
        danismanlikId,
        _taksitCollection,
      )
      .doc(taksitId)
      .collection(_dagitimCollection);

  Future<void> kaydet(
    String danismanlikId,
    String taksitId,
    DagitimModel dagitim,
  ) async {
    try {
      await _dagitimRef(
        danismanlikId,
        taksitId,
      ).doc(dagitim.personelId).set(dagitim.toMap());
    } catch (e) {
      debugPrint('Dagitim kaydedilirken hata: $e');
      rethrow;
    }
  }

  Future<void> topluKaydet(
    String danismanlikId,
    String taksitId,
    List<DagitimModel> dagitimlar,
  ) async {
    try {
      final batch = _service.batch();
      final collRef = _dagitimRef(danismanlikId, taksitId);

      for (final dagitim in dagitimlar) {
        batch.set(collRef.doc(dagitim.personelId), dagitim.toMap());
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Toplu dagitim kaydedilirken hata: $e');
      rethrow;
    }
  }

  Future<List<DagitimModel>> getAll(
    String danismanlikId,
    String taksitId,
  ) async {
    try {
      final snapshot = await _dagitimRef(danismanlikId, taksitId).get();
      return snapshot.docs
          .map((doc) => DagitimModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Dagitimlar getirilirken hata: $e');
      return [];
    }
  }

  Stream<List<DagitimModel>> stream(String danismanlikId, String taksitId) {
    return _dagitimRef(danismanlikId, taksitId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => DagitimModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }
}
