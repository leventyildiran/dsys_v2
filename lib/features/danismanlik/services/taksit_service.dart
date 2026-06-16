import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../models/taksit_model.dart';

class TaksitService {
  TaksitService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _danismanlikCollection = 'danismanliklar';
  static const _taksitCollection = 'taksitler';

  CollectionReference<Map<String, dynamic>> _taksitRef(String danismanlikId) =>
      _service.nestedCollection(
        _danismanlikCollection,
        danismanlikId,
        _taksitCollection,
      );

  Future<void> create(String danismanlikId, TaksitModel model) async {
    try {
      await _taksitRef(danismanlikId).add(model.toMap());
    } catch (e) {
      debugPrint('Taksit oluşturulurken hata: $e');
      rethrow;
    }
  }

  Future<void> update(
    String danismanlikId,
    String taksitId,
    TaksitModel model,
  ) async {
    try {
      await _taksitRef(danismanlikId).doc(taksitId).update(model.toMap());
    } catch (e) {
      debugPrint('Taksit güncellenirken hata: $e');
      rethrow;
    }
  }

  Future<void> delete(String danismanlikId, String taksitId) async {
    try {
      await _taksitRef(danismanlikId).doc(taksitId).delete();
    } catch (e) {
      debugPrint('Taksit silinirken hata: $e');
      rethrow;
    }
  }

  Future<void> updateDurum(
    String danismanlikId,
    String taksitId,
    TaksitDurum durum,
  ) async {
    try {
      await _taksitRef(
        danismanlikId,
      ).doc(taksitId).update({'durum': durum.value});
    } catch (e) {
      debugPrint('Taksit durumu güncellenirken hata: $e');
      rethrow;
    }
  }

  Stream<List<TaksitModel>> streamTaksitler(String danismanlikId) {
    return _taksitRef(danismanlikId)
        .orderBy('ayNo')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaksitModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<TaksitModel?> getById(String danismanlikId, String taksitId) async {
    try {
      final doc = await _taksitRef(danismanlikId).doc(taksitId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TaksitModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('Taksit getirilirken hata: $e');
      return null;
    }
  }

  /// Tüm danışmanlıklardaki taksitleri dinler (konsolide takip).
  Stream<List<({String danismanlikId, TaksitModel taksit})>>
  streamTumTaksitler() {
    return _service.firestore
        .collectionGroup(_taksitCollection)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final danismanlikId = doc.reference.parent.parent?.id ?? '';
            return (
              danismanlikId: danismanlikId,
              taksit: TaksitModel.fromMap(doc.id, doc.data()),
            );
          }).toList()..sort((a, b) => a.taksit.ayNo.compareTo(b.taksit.ayNo));
        });
  }
}
