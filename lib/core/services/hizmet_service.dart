import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/hizmet_model.dart';
import 'firestore_service.dart';

class HizmetService {
  HizmetService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _hizmetCollection = 'hizmetler';
  static const _birimCollection = 'birimler';

  CollectionReference<Map<String, dynamic>> get _hizmetlerRef =>
      _service.collection(_hizmetCollection);

  CollectionReference<Map<String, dynamic>> get _birimlerRef =>
      _service.collection(_birimCollection);

  static List<HizmetModel>? _cachedAllHizmetler;
  static DateTime? _lastHizmetlerFetchTime;

  void _invalidateHizmetCache() {
    _cachedAllHizmetler = null;
    _lastHizmetlerFetchTime = null;
  }

  Future<List<HizmetModel>> getAllHizmetler({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedAllHizmetler != null &&
        _lastHizmetlerFetchTime != null) {
      if (DateTime.now().difference(_lastHizmetlerFetchTime!).inMinutes < 60) {
        return _cachedAllHizmetler!;
      }
    }

    final querySnapshot = await _hizmetlerRef.get();
    final list = querySnapshot.docs
        .map((doc) => HizmetModel.fromJson(doc.data(), doc.id))
        .toList();
    list.sort((a, b) {
      final cmp = a.birimAdi.compareTo(b.birimAdi);
      if (cmp != 0) return cmp;
      return a.hizmetAdi.compareTo(b.hizmetAdi);
    });

    _cachedAllHizmetler = list;
    _lastHizmetlerFetchTime = DateTime.now();
    return list;
  }

  Future<List<HizmetModel>> getHizmetlerByBirim(String birimAdi) async {
    final tumHizmetler = await getAllHizmetler();
    final filtered = tumHizmetler.where((h) => h.birimAdi == birimAdi).toList();
    filtered.sort((a, b) => a.hizmetAdi.compareTo(b.hizmetAdi));
    return filtered;
  }

  String _toTurkishLowerCase(String text) {
    return text.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  }

  String _normalizeForCompare(String text) {
    var s = _toTurkishLowerCase(text);
    s = s.replaceAll(RegExp(r'[^a-z0-9ıöüşğç]'), '');
    if (s.endsWith('müdürlüğü')) {
      s = s.substring(0, s.length - 9);
    }
    return s;
  }

  Future<List<String>> getBirimler() async {
    final officialBirims = <String>[];

    try {
      final birimSnapshot = await _birimlerRef
          .where('aktif', isEqualTo: true)
          .get();
      for (var doc in birimSnapshot.docs) {
        final ad = doc.data()['ad'] as String?;
        if (ad != null && ad.isNotEmpty) {
          officialBirims.add(ad);
        }
      }
    } catch (e) {
      debugPrint('Birim listesi okunamadı: $e');
    }

    final birimlerSet = <String>{...officialBirims};

    try {
      final querySnapshot = await _hizmetlerRef.get();
      final batch = _service.batch();
      bool needsUpdate = false;
      int updateCount = 0;

      for (var doc in querySnapshot.docs) {
        final rawBirim = doc.data()['birimAdi'] as String?;
        if (rawBirim != null && rawBirim.isNotEmpty) {
          final matchIndex = officialBirims.indexWhere(
            (ob) => _normalizeForCompare(ob) == _normalizeForCompare(rawBirim),
          );
          if (matchIndex != -1) {
            final officialName = officialBirims[matchIndex];
            if (rawBirim != officialName) {
              batch.update(doc.reference, {'birimAdi': officialName});
              needsUpdate = true;
              updateCount++;
            }
          } else {
            birimlerSet.add(rawBirim);
          }
        }
      }

      if (needsUpdate && updateCount <= 500) {
        await batch.commit();
        debugPrint(
          'Veritabanındaki birim adları düzeltildi ($updateCount adet).',
        );
      }
    } catch (e) {
      debugPrint('Birim güncelleme hatası: $e');
    }

    final birimler = birimlerSet.toList();
    birimler.sort();
    return birimler;
  }

  Future<String> _getNormalizedBirimAdi(String rawBirim) async {
    try {
      final birimSnapshot = await _birimlerRef
          .where('aktif', isEqualTo: true)
          .get();
      for (var doc in birimSnapshot.docs) {
        final ad = doc.data()['ad'] as String?;
        if (ad != null && ad.isNotEmpty) {
          if (_normalizeForCompare(ad) == _normalizeForCompare(rawBirim)) {
            return ad;
          }
        }
      }
    } catch (e) {
      debugPrint('Birim adı normalize edilemedi: $e');
    }
    return rawBirim;
  }

  Future<void> addHizmet(HizmetModel hizmet) async {
    hizmet.birimAdi = await _getNormalizedBirimAdi(hizmet.birimAdi);
    await _hizmetlerRef.add(hizmet.toJson());
    _invalidateHizmetCache();
  }

  Future<void> updateHizmet(HizmetModel hizmet) async {
    hizmet.birimAdi = await _getNormalizedBirimAdi(hizmet.birimAdi);
    await _hizmetlerRef.doc(hizmet.id).update(hizmet.toJson());
    _invalidateHizmetCache();
  }

  Future<void> deleteHizmet(String id) async {
    await _hizmetlerRef.doc(id).delete();
    _invalidateHizmetCache();
  }
}
