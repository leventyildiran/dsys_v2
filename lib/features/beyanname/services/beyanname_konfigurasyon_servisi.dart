import 'package:flutter/foundation.dart';

import '../../../core/services/firestore_service.dart';
import '../models/beyanname_konfigurasyonu.dart';

/// Kurum bazlı beyanname yapılandırmasını Firestore'da okur/yazar.
///
/// Veri `beyannameKonfigurasyonu/genel` dokümanında saklanır ve
/// [FirestoreService] üzerinden aktif üniversite (tenant) kapsamına yazılır;
/// böylece her kurum kendi yapılandırmasını görür (çok-kurumlu mimari).
///
/// Tasarım ilkeleri:
/// - Kayıt yoksa veya okuma hata verirse **varsayılan** yapılandırma döner;
///   böylece sistem her zaman çalışır (offline / ilk kurulum güvenliği).
/// - `merge: true` ile yazılır; ileride yeni alan eklemek eski kaydı bozmaz.
class BeyannameKonfigurasyonServisi {
  BeyannameKonfigurasyonServisi({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;

  static const String _collection = 'beyannameKonfigurasyonu';

  /// Aktif kurumun yapılandırma dokümanı (tek doküman).
  static const String _docId = 'genel';

  /// Aktif kurumun beyanname yapılandırmasını getirir.
  ///
  /// Kayıt yoksa ya da hata oluşursa [BeyannameKonfigurasyonu.varsayilan] döner.
  Future<BeyannameKonfigurasyonu> getir() async {
    try {
      final doc = await _service.get(_collection, _docId);
      final data = doc.data();
      if (doc.exists && data != null && data.isNotEmpty) {
        return BeyannameKonfigurasyonu.fromMap(
          Map<String, dynamic>.from(data),
        );
      }
    } catch (e) {
      debugPrint('Beyanname konfigürasyonu okunamadı: $e');
    }
    return BeyannameKonfigurasyonu.varsayilan;
  }

  /// Yapılandırmayı kaydeder (merge).
  ///
  /// Hata durumunda yeniden fırlatır; çağıran katman kullanıcıya gösterir.
  Future<void> kaydet(BeyannameKonfigurasyonu konfig) async {
    try {
      await _service.set(_collection, _docId, konfig.toMap(), merge: true);
    } catch (e) {
      debugPrint('Beyanname konfigürasyonu kaydedilemedi: $e');
      rethrow;
    }
  }

  /// Kuruma özel kaydı siler; sistem tekrar varsayılan yapılandırmaya döner.
  Future<void> varsayilanaDon() async {
    try {
      await _service.docRef(_collection, _docId).delete();
    } catch (e) {
      debugPrint('Beyanname konfigürasyonu sıfırlanamadı: $e');
      rethrow;
    }
  }
}
