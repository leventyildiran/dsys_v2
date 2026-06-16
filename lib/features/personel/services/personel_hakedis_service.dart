import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../models/aylik_hakedis_model.dart';

class PersonelHakedisService {
  PersonelHakedisService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _personelCollection = 'personel';
  static const _hakedisCollection = 'aylikToplamHakedis';

  CollectionReference<Map<String, dynamic>> _hakedisRef(String personelId) =>
      _service.nestedCollection(
        _personelCollection,
        personelId,
        _hakedisCollection,
      );

  Future<AylikHakedisModel?> get(String personelId, String yilAy) async {
    try {
      final doc = await _hakedisRef(personelId).doc(yilAy).get();
      if (!doc.exists || doc.data() == null) return null;
      return AylikHakedisModel.fromMap(yilAy, doc.data()!);
    } catch (e) {
      debugPrint('Aylik hakedis getirilirken hata: $e');
      return null;
    }
  }

  Future<void> kaydet(String personelId, AylikHakedisModel hakedis) async {
    try {
      await _hakedisRef(
        personelId,
      ).doc(hakedis.yilAy).set(hakedis.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aylik hakedis kaydedilirken hata: $e');
      rethrow;
    }
  }

  Future<void> donerSermayeEkle(
    String personelId,
    String yilAy,
    double eklenenTutar,
  ) async {
    try {
      final mevcut = await get(personelId, yilAy);
      final yeniDonerSermaye = (mevcut?.donerSermaye ?? 0.0) + eklenenTutar;
      final yeniToplam = yeniDonerSermaye + (mevcut?.ikinciOgretim ?? 0.0);

      await _hakedisRef(personelId).doc(yilAy).set({
        'donerSermaye': yeniDonerSermaye,
        'ikinciOgretim': mevcut?.ikinciOgretim ?? 0.0,
        'toplam': yeniToplam,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Doner sermaye eklenirken hata: $e');
      rethrow;
    }
  }

  Future<double> toplamAylikGelir(String personelId, String yilAy) async {
    final hakedis = await get(personelId, yilAy);
    return hakedis?.toplam ?? 0.0;
  }
}
