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

  /// Tüm personelleri getirir (Firebase Fatura Dostu / Sıfır Maliyet Mimarisi):
  /// 1. Varsa bellekteki önbellekten döner (0 Read).
  /// 2. 1.219 kişilik üniversite rehberini yerel asset'ten anında yükler (0 Read, 0 Maliyet!).
  /// 3. Firestore'dan SADECE sonradan elle eklenmiş özel personelleri çeker (where kaynak == 'manuel').
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

    // 1. Adım: Önce 1.219 kişilik ana üniversite rehberini YEREL ASSET'TEN yükle (0 Firestore Read!)
    try {
      final jsonStr = await rootBundle.loadString('assets/data/usak_personeller.json');
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      list = decoded.map((e) {
        final m = e as Map<String, dynamic>;
        final id = m['id'] as String? ?? '';
        return PersonelModel.fromMap(id, m);
      }).toList();
      debugPrint('[PersonelService] Yerel rehberden ${list.length} personel sıfır maliyetle yüklendi.');
    } catch (e) {
      debugPrint('[PersonelService] Yerel asset okuma hatası: $e');
    }

    // 2. Adım: Firestore'dan sadece kullanıcıların sonradan elle eklediği kayıtları çek (Kota dostu kısıtlı sorgu)
    try {
      final snapshot = await _personelRef.where('kaynak', isEqualTo: 'manuel').get();
      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          final p = PersonelModel.fromMap(doc.id, doc.data());
          // Listede yoksa ekle
          if (!list.any((item) => item.id == p.id)) {
            list.add(p);
          }
        }
        debugPrint('[PersonelService] Firestore\'dan ${snapshot.docs.length} adet manuel personel senkronize edildi.');
      }
    } catch (e) {
      debugPrint('[PersonelService] Firestore manuel personel okuma uyarısı: $e');
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
