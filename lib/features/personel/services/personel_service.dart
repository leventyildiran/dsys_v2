import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/services/firestore_service.dart';
import '../models/personel_model.dart';

class PersonelService {
  PersonelService({FirestoreService? firestoreService})
      : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'personel';

  static List<PersonelModel>? _cachedList;

  CollectionReference<Map<String, dynamic>> get _personelRef =>
      _service.collection(_collection);

  /// Tüm personelleri getirir.
  /// 1. Varsa önbellekten döner.
  /// 2. Firestore'dan yükler.
  /// 3. Firestore boşsa veya hata verirse yerel 'assets/data/usak_personeller.json' yedeğinden yükler.
  Future<List<PersonelModel>> getAll({
    bool forceRefresh = false,
    bool sadeceAktif = true,
  }) async {
    if (!forceRefresh && _cachedList != null && _cachedList!.isNotEmpty) {
      return sadeceAktif
          ? _cachedList!.where((p) => p.aktif).toList()
          : _cachedList!;
    }

    List<PersonelModel> list = [];

    // 1. Adım: Firestore'dan çekmeyi dene
    try {
      final snapshot = await _personelRef.get();
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs
            .map((doc) => PersonelModel.fromMap(doc.id, doc.data()))
            .toList();
      }
    } catch (e) {
      debugPrint('[PersonelService.getAll] Firestore okuma hatası: $e');
    }

    // 2. Adım: Firestore boşsa veya erişilemezse yerel asset'ten yükle
    if (list.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/usak_personeller.json');
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        list = decoded.map((e) {
          final m = e as Map<String, dynamic>;
          final id = m['id'] as String? ?? '';
          return PersonelModel.fromMap(id, m);
        }).toList();
        debugPrint('[PersonelService] Yerel rehber yedeğinden ${list.length} personel yüklendi.');
      } catch (e) {
        debugPrint('[PersonelService] Yerel asset yükleme hatası: $e');
      }
    }

    // Sıralama (Ad Soyad'a göre Türkçe alfabetik)
    list.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
    _cachedList = list;

    return sadeceAktif ? list.where((p) => p.aktif).toList() : list;
  }

  /// Türkçe karakter uyumlu normalize arama
  static String normalizeMetin(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  static String _normalize(String s) => normalizeMetin(s);

  /// Akıllı Personel Arama: Ad, unvan, birim veya e-posta bazında
  Future<List<PersonelModel>> search(
    String query, {
    String? birimAdi,
    int limit = 30,
  }) async {
    final list = await getAll();
    final q = _normalize(query);

    if (q.isEmpty && (birimAdi == null || birimAdi.isEmpty)) {
      return list.take(limit).toList();
    }

    final bNorm = birimAdi != null ? _normalize(birimAdi) : '';

    final filtered = list.where((p) {
      final adNorm = _normalize(p.adSoyad);
      final unvanNorm = _normalize(p.unvan);
      final birimNorm = _normalize(p.birimAdi ?? '');
      final epostaNorm = _normalize(p.eposta ?? '');

      final queryMatches = q.isEmpty ||
          adNorm.contains(q) ||
          unvanNorm.contains(q) ||
          birimNorm.contains(q) ||
          epostaNorm.contains(q);

      if (!queryMatches) return false;

      if (bNorm.isNotEmpty) {
        // İlgili birimdeyse veya birim belirtilmemişse
        return birimNorm.contains(bNorm) || bNorm.contains(birimNorm);
      }

      return true;
    }).toList();

    return filtered.take(limit).toList();
  }

  /// Belirtilen isimde personel varsa getirir, yoksa yeni oluşturup kaydeder.
  Future<PersonelModel> getOrAdd({
    required String adSoyad,
    String? birimAdi,
    String? unvan,
  }) async {
    final cleanAd = adSoyad.trim();
    if (cleanAd.isEmpty) {
      throw ArgumentError('Personel adı boş olamaz.');
    }

    final norm = _normalize(cleanAd);
    final all = await getAll();

    // Tam eşleşme ara
    final existing = all.cast<PersonelModel?>().firstWhere(
          (p) => _normalize(p!.adSoyad) == norm,
          orElse: () => null,
        );

    if (existing != null) {
      return existing;
    }

    // Yoksa yeni oluştur
    final yeni = PersonelModel(
      id: 'manuel_${DateTime.now().millisecondsSinceEpoch}',
      adSoyad: cleanAd,
      unvan: unvan ?? '',
      birimAdi: birimAdi,
      kaynak: 'manuel',
      aktif: true,
    );

    return add(yeni);
  }

  Future<PersonelModel> add(PersonelModel personel) async {
    final doc = personel.id.isNotEmpty
        ? _personelRef.doc(personel.id)
        : _personelRef.doc();
    final data = personel.toMap();
    data['id'] = doc.id;
    await doc.set(data);

    final saved = PersonelModel.fromMap(doc.id, data);
    _cachedList = [saved, ...?_cachedList];
    return saved;
  }

  Future<void> update(PersonelModel personel) async {
    await _personelRef
        .doc(personel.id)
        .set(personel.toMap(), SetOptions(merge: true));

    if (_cachedList != null) {
      final idx = _cachedList!.indexWhere((p) => p.id == personel.id);
      if (idx != -1) {
        _cachedList![idx] = personel;
      }
    }
  }

  Future<void> delete(String id) async {
    await _personelRef.doc(id).delete();
    _cachedList?.removeWhere((p) => p.id == id);
  }
}
