import 'package:cloud_firestore/cloud_firestore.dart';

import 'fatura_model.dart';

/// Fatura geçici arşivi için yıl hesaplama ve saklama kuralları.
class FaturaArsivUtil {
  FaturaArsivUtil._();

  /// Geçici arşivde tutulacak süre (takvim yılı bazında).
  static const int saklamaYilSayisi = 1;

  /// Yıl başı temizlik uyarısı gösterilecek aylar (Ocak–Mart).
  static const List<int> temizlikUyarisiAylari = [1, 2, 3];

  static int suAnkiYil() => DateTime.now().year;

  static bool yilBasiTemizlikDonemi() =>
      temizlikUyarisiAylari.contains(DateTime.now().month);

  /// Fatura tarihinden kayıt yılını çıkarır; bulamazsa bugünün yılı.
  static int kayitYili(String tarih) {
    final t = tarih.trim();
    if (t.isEmpty) return suAnkiYil();

    final tr = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(t);
    if (tr != null) return int.parse(tr.group(3)!);

    final us = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(t);
    if (us != null) {
      var y = us.group(3)!;
      if (y.length == 2) y = '20$y';
      return int.parse(y);
    }

    final y4 = RegExp(r'(20\d{2})').firstMatch(t);
    if (y4 != null) return int.parse(y4.group(1)!);

    return suAnkiYil();
  }

  /// Mevcut yıldan önceki yıllar arşivden silinmeli.
  static bool silinmeli(int kayitYili) => kayitYili < suAnkiYil();

  /// dd.MM.yyyy veya benzeri metinden tarih üretir.
  static DateTime? tarihParse(String tarih) {
    final t = tarih.trim();
    if (t.isEmpty) return null;

    final tr = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(t);
    if (tr != null) {
      return DateTime(
        int.parse(tr.group(3)!),
        int.parse(tr.group(2)!),
        int.parse(tr.group(1)!),
      );
    }

    final us = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(t);
    if (us != null) {
      var y = us.group(3)!;
      if (y.length == 2) y = '20$y';
      return DateTime(int.parse(y), int.parse(us.group(2)!), int.parse(us.group(1)!));
    }

    return null;
  }

  /// [bas] / [bit] dahil aralık kontrolü (yalnızca gün).
  static bool tarihAraliginda(String tarih, DateTime? bas, DateTime? bit) {
    if (bas == null && bit == null) return true;
    final d = tarihParse(tarih);
    if (d == null) return false;
    final gun = DateTime(d.year, d.month, d.day);
    if (bas != null) {
      final b = DateTime(bas.year, bas.month, bas.day);
      if (gun.isBefore(b)) return false;
    }
    if (bit != null) {
      final e = DateTime(bit.year, bit.month, bit.day);
      if (gun.isAfter(e)) return false;
    }
    return true;
  }
}

/// Arşiv arama filtresi.
class FaturaArsivAramaFiltre {
  const FaturaArsivAramaFiltre({
    this.yil,
    this.baslangicTarihi,
    this.bitisTarihi,
    this.metin = '',
  });

  final int? yil;
  final DateTime? baslangicTarihi;
  final DateTime? bitisTarihi;
  final String metin;
}

/// Arşivde bulunan tek kayıt.
class FaturaArsivKayit {
  const FaturaArsivKayit({
    required this.firestoreId,
    required this.kayitYili,
    required this.fatura,
    this.sistemeKayitTarihi,
  });

  final String firestoreId;
  final int kayitYili;
  final FaturaModel fatura;
  final DateTime? sistemeKayitTarihi;

  factory FaturaArsivKayit.fromMap(Map<String, dynamic> map) {
    final ts = map['sistemeKayitTarihi'];
    DateTime? kayitTarihi;
    if (ts != null) {
      if (ts is Timestamp) {
        kayitTarihi = ts.toDate();
      } else if (ts is String) {
        kayitTarihi = DateTime.tryParse(ts);
      }
    }
    final yil =
        map['kayitYili'] as int? ?? FaturaArsivUtil.kayitYili(map['tarih']?.toString() ?? '');
    return FaturaArsivKayit(
      firestoreId: map['firestoreId']?.toString() ?? '',
      kayitYili: yil,
      fatura: FaturaModel.fromJson(map),
      sistemeKayitTarihi: kayitTarihi,
    );
  }
}

/// Yıl bazında arşiv özeti.
class FaturaArsivYilOzet {
  final int yil;
  final int adet;

  const FaturaArsivYilOzet({required this.yil, required this.adet});
}

/// Yıl başı temizlik uyarısı için özet.
class FaturaTemizlikUyarisi {
  final List<FaturaArsivYilOzet> eskiYillar;
  final int toplamEskiKayit;

  const FaturaTemizlikUyarisi({
    required this.eskiYillar,
    required this.toplamEskiKayit,
  });

  bool get gosterilmeli => toplamEskiKayit > 0;
}
