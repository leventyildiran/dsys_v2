import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firma_model.dart';
import 'firestore_service.dart';

class FirmaService {
  FirmaService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'firmalar';

  CollectionReference<Map<String, dynamic>> get _firmalarRef =>
      _service.collection(_collection);

  static List<FirmaModel>? _cachedFirmalar;
  static DateTime? _lastFetchTime;

  Future<List<FirmaModel>> getAllFirmalar({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFirmalar != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 60) {
        return _cachedFirmalar!;
      }
    }

    final querySnapshot = await _firmalarRef.get();
    final list = querySnapshot.docs
        .map((doc) => FirmaModel.fromJson(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => a.firmaAdi.compareTo(b.firmaAdi));

    _cachedFirmalar = list;
    _lastFetchTime = DateTime.now();
    return list;
  }

  void _invalidateCache() {
    _cachedFirmalar = null;
    _lastFetchTime = null;
  }

  Future<void> addFirma(FirmaModel firma) async {
    await _firmalarRef.add(firma.toJson());
    _invalidateCache();
  }

  Future<void> updateFirma(FirmaModel firma) async {
    await _firmalarRef.doc(firma.id).update(firma.toJson());
    _invalidateCache();
  }

  Future<void> deleteFirma(String id) async {
    await _firmalarRef.doc(id).delete();
    _invalidateCache();
  }

  static String _temizleVkn(String? v) =>
      (v ?? '').replaceAll(RegExp(r'\D'), '');

  static String _normalizeFirmaAdi(String s) {
    return s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'[.,\-_/\\()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Firmanın kayıtlı olup olmadığını VKN veya tam ada göre kontrol eder.
  Future<FirmaModel?> firmaBul({required String firmaAdi, String? vergiNo}) async {
    final firmalar = await getAllFirmalar();
    final vClean = _temizleVkn(vergiNo);
    final fNorm = _normalizeFirmaAdi(firmaAdi);

    for (final f in firmalar) {
      final fVClean = _temizleVkn(f.vergiNo);
      // 1. VKN ile tam eşleşme (en güvenilir kimlik)
      if (vClean.length >= 10 && fVClean.length >= 10 && fVClean == vClean) {
        return f;
      }
      // 2. Normalize edilmiş firma unvanı ile eşleşme
      if (fNorm.isNotEmpty && _normalizeFirmaAdi(f.firmaAdi) == fNorm) {
        return f;
      }
    }
    return null;
  }

  /// Firma sistemde kayıtlı mı?
  Future<bool> firmaMevcutMu({required String firmaAdi, String? vergiNo}) async {
    return (await firmaBul(firmaAdi: firmaAdi, vergiNo: vergiNo)) != null;
  }

  /// Firmayı ekler veya mevcutsa eksik alanlarını (adres, vergi dairesi) tamamlar.
  Future<bool> kaydetVeyaGuncelle(FirmaModel yeniFirma) async {
    final mevcut = await firmaBul(
      firmaAdi: yeniFirma.firmaAdi,
      vergiNo: yeniFirma.vergiNo,
    );

    if (mevcut == null) {
      await addFirma(yeniFirma);
      return true; // Yeni eklendi
    }

    // Mevcut firma varsa ama yeni veride adres/vd dolu olup eskide boşsa güncelle
    bool degisti = false;
    if (mevcut.adres.trim().isEmpty && yeniFirma.adres.trim().isNotEmpty) {
      mevcut.adres = yeniFirma.adres.trim();
      degisti = true;
    }
    if (mevcut.vergiDairesi.trim().isEmpty && yeniFirma.vergiDairesi.trim().isNotEmpty) {
      mevcut.vergiDairesi = yeniFirma.vergiDairesi.trim();
      degisti = true;
    }
    if (mevcut.vergiNo.trim().isEmpty && yeniFirma.vergiNo.trim().isNotEmpty) {
      mevcut.vergiNo = yeniFirma.vergiNo.trim();
      degisti = true;
    }

    if (degisti && mevcut.id.isNotEmpty) {
      await updateFirma(mevcut);
    }
    return false; // Zaten mevcuttu
  }
}

