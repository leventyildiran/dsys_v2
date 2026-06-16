import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/sablon_model.dart';
import 'firestore_service.dart';

class SablonService {
  SablonService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'sistemSablonlari';
  final Reference _storageRef = FirebaseStorage.instance.ref().child(
    'templates',
  );

  CollectionReference<Map<String, dynamic>> get _sablonlarRef =>
      _service.collection(_collection);

  Future<List<SablonModel>> getAllSablonlar() async {
    final querySnapshot = await _sablonlarRef
        .orderBy('eklenmeTarihi', descending: true)
        .get();
    return querySnapshot.docs
        .map((doc) => SablonModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> addSablon(
    String sablonAdi,
    String tur,
    String fileName,
    Uint8List fileBytes, {
    String? birimId,
    String? birimAd,
  }) async {
    try {
      final String safeFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final fileRef = _storageRef.child(safeFileName);

      final uploadTask = fileRef.putData(fileBytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final dosyaUzantisi = fileName.contains('.')
          ? '.${fileName.split('.').last}'
          : '';

      final sablon = SablonModel(
        id: '',
        sablonAdi: sablonAdi,
        dosyaUzantisi: dosyaUzantisi,
        dosyaUrl: downloadUrl,
        tur: tur,
        eklenmeTarihi: DateTime.now(),
        birimId: birimId,
        birimAd: birimAd,
      );

      await _sablonlarRef.add(sablon.toJson());
    } catch (e) {
      debugPrint('[SablonService.addSablon] Hata: $e');
      rethrow;
    }
  }

  Future<void> deleteSablon(SablonModel sablon) async {
    try {
      if (sablon.dosyaUrl.isNotEmpty) {
        final ref = FirebaseStorage.instance.refFromURL(sablon.dosyaUrl);
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Storage silinirken hata (belki dosya zaten yok): $e');
    }

    await _sablonlarRef.doc(sablon.id).delete();
  }

  Future<void> addTextSablon(
    String sablonAdi,
    String tur,
    String deltaJson, {
    String? birimId,
    String? birimAd,
  }) async {
    try {
      final sablon = SablonModel(
        id: '',
        sablonAdi: sablonAdi,
        dosyaUzantisi: '.txt',
        dosyaUrl: deltaJson,
        tur: tur,
        eklenmeTarihi: DateTime.now(),
        birimId: birimId,
        birimAd: birimAd,
      );
      await _sablonlarRef.add(sablon.toJson());
    } catch (e) {
      debugPrint('[SablonService.addTextSablon] Hata: $e');
      rethrow;
    }
  }

  Future<void> updateSablonText(
    String id,
    String sablonAdi,
    String tur,
    String deltaJson, {
    String? birimId,
    String? birimAd,
  }) async {
    try {
      await _sablonlarRef.doc(id).update({
        'sablonAdi': sablonAdi,
        'tur': tur,
        'dosyaUrl': deltaJson,
        'birimId': birimId,
        'birimAd': birimAd,
      });
    } catch (e) {
      debugPrint('[SablonService.updateSablonText] Hata: $e');
      rethrow;
    }
  }
}
