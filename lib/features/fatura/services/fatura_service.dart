import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import '../models/fatura_arsiv_util.dart';
import '../models/fatura_model.dart';

class FaturaService {
  FaturaService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _koleksiyon = 'faturalar_gecici';
  static const _kayitlar = 'kayitlar';

  CollectionReference<Map<String, dynamic>> _yilKoleksiyonu(int yil) =>
      _service.nestedCollection(_koleksiyon, '$yil', _kayitlar);

  /// Onaylanan faturayı geçici yıllık arşive kaydeder.
  Future<String> saveFatura(FaturaModel fatura) async {
    try {
      final kayitYili = FaturaArsivUtil.kayitYili(fatura.tarih);
      final doc = await _yilKoleksiyonu(kayitYili).add({
        ...fatura.toMap(),
        'kayitYili': kayitYili,
        'geciciArsiv': true,
        'sistemeKayitTarihi': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return doc.id;
    } catch (e) {
      throw Exception('Fatura kaydedilirken hata: $e');
    }
  }

  /// Çoklu faturaları tek seferde Firestore batch ile yüksek hızda kaydeder.
  Future<List<String>> saveBatchFaturalar(List<FaturaModel> faturalar) async {
    if (faturalar.isEmpty) return [];
    try {
      final ids = <String>[];
      // Firestore batch en fazla 500 işlem destekler
      const batchLimit = 400;
      for (var i = 0; i < faturalar.length; i += batchLimit) {
        final chunk = faturalar.skip(i).take(batchLimit).toList();
        final batch = _service.batch();
        for (final fatura in chunk) {
          final kayitYili = FaturaArsivUtil.kayitYili(fatura.tarih);
          final docRef = _yilKoleksiyonu(kayitYili).doc();
          batch.set(docRef, {
            ...fatura.toMap(),
            'kayitYili': kayitYili,
            'geciciArsiv': true,
            'sistemeKayitTarihi': FieldValue.serverTimestamp(),
          });
          ids.add(docRef.id);
        }
        await batch.commit().timeout(const Duration(seconds: 15));
      }
      return ids;
    } catch (e) {
      throw Exception('Toplu fatura kaydedilirken hata: $e');
    }
  }

  /// Yıl bazında arşiv sayıları (mevcut + eski) - PARALEL HIZLI SORGULAMA
  Future<Map<int, int>> tumYilSayilari() async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final yillar = [for (var y = suAn - 5; y <= suAn; y++) y];
    final map = <int, int>{};

    final futures = yillar.map((yil) async {
      try {
        final snap = await _yilKoleksiyonu(yil)
            .count()
            .get()
            .timeout(const Duration(seconds: 4));
        final adet = snap.count ?? 0;
        return MapEntry(yil, adet);
      } catch (_) {
        return MapEntry(yil, 0);
      }
    });

    final entries = await Future.wait(futures);
    for (final e in entries) {
      if (e.value > 0) map[e.key] = e.value;
    }
    return map;
  }

  /// Mevcut yıldan önceki yıllardaki kayıt sayılarını döndürür.
  Future<FaturaTemizlikUyarisi> eskiArsivOzetiniGetir({
    Map<int, int>? cacheYilSayilari,
  }) async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final yilSayilari = cacheYilSayilari ?? await tumYilSayilari();
    final eskiYillar = <FaturaArsivYilOzet>[];
    var toplam = 0;

    for (final entry in yilSayilari.entries) {
      if (entry.key < suAn && entry.value > 0) {
        eskiYillar.add(FaturaArsivYilOzet(yil: entry.key, adet: entry.value));
        toplam += entry.value;
      }
    }

    eskiYillar.sort((a, b) => a.yil.compareTo(b.yil));
    return FaturaTemizlikUyarisi(
      eskiYillar: eskiYillar,
      toplamEskiKayit: toplam,
    );
  }

  /// Belirtilen yılın tüm arşiv kayıtlarını getirir.
  Future<List<Map<String, dynamic>>> yilArsiviniGetir(int yil) async {
    final snap = await _yilKoleksiyonu(yil)
        .get()
        .timeout(const Duration(seconds: 8));
    return snap.docs.map((d) => {'firestoreId': d.id, ...d.data()}).toList();
  }

  /// Mevcut yıldan önceki tüm arşiv kayıtlarını yıl bazında gruplar.
  Future<Map<int, List<Map<String, dynamic>>>>
  eskiArsivKayitlariniGetir() async {
    final ozet = await eskiArsivOzetiniGetir();
    final map = <int, List<Map<String, dynamic>>>{};
    for (final y in ozet.eskiYillar) {
      map[y.yil] = await yilArsiviniGetir(y.yil);
    }
    return map;
  }

  /// Belirtilen yılın tüm geçici arşiv kayıtlarını siler.
  Future<int> silYilArsivi(int yil) async {
    final col = _yilKoleksiyonu(yil);
    var silinen = 0;

    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;

      final batch = _service.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      silinen += snap.docs.length;
    }

    return silinen;
  }

  /// Mevcut yıldan önceki tüm geçici arşivi temizler.
  Future<int> silTumEskiArsiv() async {
    final ozet = await eskiArsivOzetiniGetir();
    var toplam = 0;
    for (final y in ozet.eskiYillar) {
      toplam += await silYilArsivi(y.yil);
    }
    return toplam;
  }

  /// Mevcut yıl arşivindeki kayıt sayısı.
  Future<int> mevcutYilArsivSayisi({Map<int, int>? cacheYilSayilari}) async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    if (cacheYilSayilari != null) {
      return cacheYilSayilari[suAn] ?? 0;
    }
    try {
      final snap = await _yilKoleksiyonu(suAn)
          .count()
          .get()
          .timeout(const Duration(seconds: 4));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Tarih ve metin ile geçici arşivde arama yapar (PARALEL HIZLI SORGULAMA).
  Future<List<FaturaArsivKayit>> araFaturalar(
    FaturaArsivAramaFiltre filtre,
  ) async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final yillar = filtre.yil != null
        ? [filtre.yil!]
        : [for (var y = suAn - 3; y <= suAn; y++) y];

    final tum = <FaturaArsivKayit>[];
    final futures = yillar.map((yil) async {
      try {
        final snap = await _yilKoleksiyonu(yil)
            .orderBy('sistemeKayitTarihi', descending: true)
            .limit(200)
            .get()
            .timeout(const Duration(seconds: 6));
        return snap.docs
            .map(
              (doc) => FaturaArsivKayit.fromMap({
                'firestoreId': doc.id,
                ...doc.data(),
              }),
            )
            .toList();
      } catch (_) {
        try {
          final snap = await _yilKoleksiyonu(yil)
              .limit(200)
              .get()
              .timeout(const Duration(seconds: 6));
          return snap.docs
              .map(
                (doc) => FaturaArsivKayit.fromMap({
                  'firestoreId': doc.id,
                  ...doc.data(),
                }),
              )
              .toList();
        } catch (_) {
          return <FaturaArsivKayit>[];
        }
      }
    });

    final lists = await Future.wait(futures);
    for (final l in lists) {
      tum.addAll(l);
    }

    final q = filtre.metin.trim().toLowerCase();
    final sonuc = tum.where((k) {
      if (!FaturaArsivUtil.tarihAraliginda(
        k.fatura.tarih,
        filtre.baslangicTarihi,
        filtre.bitisTarihi,
      )) {
        return false;
      }
      if (q.isEmpty) return true;
      return _metinEslesir(k, q);
    }).toList();

    sonuc.sort((a, b) {
      final da = FaturaArsivUtil.tarihParse(a.fatura.tarih);
      final db = FaturaArsivUtil.tarihParse(b.fatura.tarih);
      if (da != null && db != null) return db.compareTo(da);
      return b.kayitYili.compareTo(a.kayitYili);
    });
    return sonuc;
  }

  bool _metinEslesir(FaturaArsivKayit k, String q) {
    final f = k.fatura;
    final alanlar = [
      f.firmaAdi,
      f.adres,
      f.vergiDairesi,
      f.vergiNo,
      f.tarih,
      f.irsaliyeTarihi,
      f.irsaliyeNo,
      f.melbesNo,
      f.numuneNo,
      f.numuneAciklamasi,
      f.hesapAdi ?? '',
      f.iban ?? '',
      f.kalemler.toString(),
    ];
    final birlesik = alanlar.join(' ').toLowerCase();
    return birlesik.contains(q);
  }
}
