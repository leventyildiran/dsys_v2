import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../models/birim_model.dart';

class BirimService {
  BirimService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'birimler';

  CollectionReference<Map<String, dynamic>> get _collectionRef =>
      _service.collection(_collection);

  Future<List<BirimModel>> getAll({bool onlyActive = true}) async {
    List<BirimModel> fromDb = [];
    try {
      Query<Map<String, dynamic>> query = _collectionRef.orderBy('ad');
      if (onlyActive) {
        query = query.where('aktif', isEqualTo: true);
      }

      final snapshot = await query.get();
      fromDb = snapshot.docs
          .map((doc) => BirimModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      // Çevrimdışı veya Firestore bağlantı hatası durumunda devam et
    }

    return _mergeAndDeduplicate(fromDb);
  }

  Stream<List<BirimModel>> stream({bool onlyActive = true}) {
    Query<Map<String, dynamic>> query = _collectionRef.orderBy('ad');
    if (onlyActive) {
      query = query.where('aktif', isEqualTo: true);
    }

    return query.snapshots().map(
      (snapshot) {
        final fromDb = snapshot.docs
            .map((doc) => BirimModel.fromMap(doc.id, doc.data()))
            .toList();
        return _mergeAndDeduplicate(fromDb);
      },
    );
  }

  List<BirimModel> _mergeAndDeduplicate(List<BirimModel> fromDb) {
    final Map<String, BirimModel> canonicalMap = {};

    // 1. DB'deki birimleri ekle
    for (final b in fromDb) {
      final rawName = b.ad.isNotEmpty ? b.ad : b.kisaAd;
      final key = BirimAdlandirma.canonicalKey(rawName);
      final stdAd = BirimAdlandirma.tamAdGetir(rawName);
      final stdKisaAd = BirimAdlandirma.kisaAdGetir(b.kisaAd.isNotEmpty ? b.kisaAd : rawName);
      canonicalMap[key] = b.copyWith(ad: stdAd, kisaAd: stdKisaAd);
    }

    // 2. Varsayılan resmi birimleri eksikse ekle, varsa resmi tam ad ve eksik alanları birleştir
    for (final def in BirimModel.varsayilanBirimler) {
      final key = BirimAdlandirma.canonicalKey(def.ad);
      if (!canonicalMap.containsKey(key)) {
        canonicalMap[key] = def;
      } else {
        final existing = canonicalMap[key]!;
        canonicalMap[key] = existing.copyWith(
          ad: def.ad, // Daima resmi tam adı koru
          kisaAd: def.kisaAd,
          iban: (existing.iban != null && existing.iban!.isNotEmpty) ? existing.iban : def.iban,
          vkn: (existing.vkn != null && existing.vkn!.isNotEmpty) ? existing.vkn : def.vkn,
          hesapAdi: (existing.hesapAdi != null && existing.hesapAdi!.isNotEmpty) ? existing.hesapAdi : def.hesapAdi,
        );
      }
    }

    final result = canonicalMap.values.toList();
    result.sort((a, b) => a.ad.compareTo(b.ad));
    return result;
  }

  Future<void> create(BirimModel model) async {
    await _collectionRef.add(model.toMap());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _collectionRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _collectionRef.doc(id).delete();
  }
}
