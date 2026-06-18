import 'package:flutter/foundation.dart';
import '../models/sistem_ayarlari_model.dart';
import 'firestore_service.dart';

class SistemAyarlariService {
  SistemAyarlariService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'sistemAyarlari';
  final String _docId = 'sistem_genel';

  Future<SistemAyarlariModel> getAyarlar() async {
    try {
      final doc = await _service.get(_collection, _docId);
      if (doc.exists && doc.data() != null) {
        return SistemAyarlariModel.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('Ayarlar okunamadı: $e');
    }
    return SistemAyarlariModel.empty();
  }

  Future<void> saveAyarlar(SistemAyarlariModel ayarlar) async {
    try {
      await _service.set(_collection, _docId, ayarlar.toJson(), merge: true);
    } catch (e) {
      debugPrint('Ayarlar kaydedilemedi: $e');
      rethrow;
    }
  }
}
