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
      });
      return doc.id;
    } catch (e) {
      throw Exception('Fatura geçici arşive kaydedilirken hata: $e');
    }
  }

  /// Mevcut yıldan önceki yıllardaki kayıt sayılarını döndürür.
  Future<FaturaTemizlikUyarisi> eskiArsivOzetiniGetir() async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final eskiYillar = <FaturaArsivYilOzet>[];
    var toplam = 0;

    for (var yil = suAn - 6; yil < suAn; yil++) {
      final snap = await _yilKoleksiyonu(yil).count().get();
      final adet = snap.count ?? 0;
      if (adet > 0) {
        eskiYillar.add(FaturaArsivYilOzet(yil: yil, adet: adet));
        toplam += adet;
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
    final snap = await _yilKoleksiyonu(yil).get();
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
  Future<int> mevcutYilArsivSayisi() async {
    final snap = await _yilKoleksiyonu(
      FaturaArsivUtil.suAnkiYil(),
    ).count().get();
    return snap.count ?? 0;
  }

  /// Yıl bazında arşiv sayıları (mevcut + eski).
  Future<Map<int, int>> tumYilSayilari() async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final map = <int, int>{};
    for (var yil = suAn - 6; yil <= suAn; yil++) {
      final snap = await _yilKoleksiyonu(yil).count().get();
      final adet = snap.count ?? 0;
      if (adet > 0) map[yil] = adet;
    }
    return map;
  }

  /// Tarih ve metin ile geçici arşivde arama yapar.
  Future<List<FaturaArsivKayit>> araFaturalar(
    FaturaArsivAramaFiltre filtre,
  ) async {
    final suAn = FaturaArsivUtil.suAnkiYil();
    final yillar = filtre.yil != null
        ? [filtre.yil!]
        : [for (var y = suAn - 6; y <= suAn; y++) y];

    final tum = <FaturaArsivKayit>[];
    for (final yil in yillar) {
      final snap = await _yilKoleksiyonu(yil).get();
      if (snap.docs.isEmpty) continue;
      for (final doc in snap.docs) {
        tum.add(
          FaturaArsivKayit.fromMap({'firestoreId': doc.id, ...doc.data()}),
        );
      }
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
