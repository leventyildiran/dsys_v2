import 'dart:math';
import '../../../core/turkce_format.dart';
import '../models/beyanname_belge_model.dart';

/// Tekil bir Mizan Hesap Kartı
class MizanHesapSatiri {
  final String hesapKodu;
  final String hesapAdi;
  final double borc;
  final double alacak;
  final double borcKalan;
  final double alacakKalan;
  final int satirNo;

  const MizanHesapSatiri({
    required this.hesapKodu,
    required this.hesapAdi,
    required this.borc,
    required this.alacak,
    required this.borcKalan,
    required this.alacakKalan,
    this.satirNo = 0,
  });

  /// Bakiye (Alacak - Borç)
  double get bakiyeAlacak => alacak - borc;

  /// Bakiye (Borç - Alacak)
  double get bakiyeBorc => borc - alacak;
}

/// Mizan üst bilgi (Header) meta verileri
class MizanMetaVeri {
  final String? muhasebeBirimi;
  final String? kamuIdaresi;
  final String? baslangicTarihi;
  final String? bitisTarihi;
  final bool isYillikKumulatif;

  const MizanMetaVeri({
    this.muhasebeBirimi,
    this.kamuIdaresi,
    this.baslangicTarihi,
    this.bitisTarihi,
    this.isYillikKumulatif = false,
  });
}

/// T.C. Maliye Bakanlığı Muhasebat Genel Müdürlüğü ve genel Geçici Mizan
/// formatlarını %100 kural tabanlı, deterministik, sıfır maliyetle ve
/// anında ayrıştıran uzman servis.
class MizanDeterministikParser {
  // Regex: 3 haneli hesap kodu ve alt hesapları (örn: "600", "600.12", "191.05", "360.03.05")
  static final RegExp _hesapKoduRegex = RegExp(r'^\d{3}(\.\d{2})*$');

  // Regex: Türkçe para formatı (örn: "16.247,44", "0,00", "-500,00")
  static final RegExp _sayiRegex = RegExp(r'^-?(\d{1,3}(\.\d{3})*|\d+),\d{2}$');

  /// Verilen metinden mizan üst bilgilerini (Birim adı, başlangıç/bitiş tarihi) çıkarır.
  static MizanMetaVeri extractMetaVeri(String text) {
    if (text.isEmpty) return const MizanMetaVeri();

    String? muhasebeBirimi;
    String? kamuIdaresi;
    String? baslangicTarihi;
    String? bitisTarihi;

    final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    for (int i = 0; i < min(lines.length, 50); i++) {
      final line = lines[i];
      if (line.contains('Muhasebe Birimi') && i + 1 < lines.length) {
        final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
        if (next != '-' && next.isNotEmpty) muhasebeBirimi = next;
      }
      if (line.contains('Kamu İdaresi') && i + 1 < lines.length) {
        final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
        if (next != '-' && next.isNotEmpty) kamuIdaresi = next;
      }
      if (line.contains('Başlangıç Tarihi') && i + 1 < lines.length) {
        final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
        if (next.isNotEmpty) baslangicTarihi = next;
      }
      if (line.contains('Bitiş Tarihi') && i + 1 < lines.length) {
        final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
        if (next.isNotEmpty) bitisTarihi = next;
      }
    }

    final isYillik = baslangicTarihi != null && baslangicTarihi.startsWith('01.01.');
    return MizanMetaVeri(
      muhasebeBirimi: muhasebeBirimi,
      kamuIdaresi: kamuIdaresi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
      isYillikKumulatif: isYillik,
    );
  }

  /// Muhasebat Geçici Mizan metnindeki tüm hesap kartlarını haritalar.
  /// İki farklı düzene toleranslıdır:
  /// 1. Çok satırlı blok (Syncfusion PDF text extractor çıktısı: Kod -> Ad -> Borç -> Alacak -> BorçKalan -> AlacakKalan -> Kod)
  /// 2. Tek satırlı yatay tablo düzeni
  static Map<String, MizanHesapSatiri> parseHesaplar(String text) {
    final Map<String, MizanHesapSatiri> hesaplar = {};
    if (text.trim().isEmpty) return hesaplar;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. DÜZEN: Standart Muhasebat Çok Satırlı Blok Taraması
    for (int i = 0; i < lines.length - 5; i++) {
      final code1 = lines[i];
      if (!_hesapKoduRegex.hasMatch(code1)) continue;

      final name = lines[i + 1];
      final borcStr = lines[i + 2];
      final alacakStr = lines[i + 3];
      final borcKalanStr = lines[i + 4];
      final alacakKalanStr = lines[i + 5];

      // Kapanış kodu kontrolü (genellikle 6. satırda tekrarlanır)
      String? closingCode;
      if (i + 6 < lines.length) {
        closingCode = lines[i + 6];
      }

      if (_sayiRegex.hasMatch(borcStr) &&
          _sayiRegex.hasMatch(alacakStr) &&
          _sayiRegex.hasMatch(borcKalanStr) &&
          _sayiRegex.hasMatch(alacakKalanStr)) {
        // Blok doğrulandı (kapanış kodu eşleşirse veya bir sonraki hesap başlıyorsa)
        if (closingCode == code1 || _hesapKoduRegex.hasMatch(closingCode ?? '')) {
          final satir = MizanHesapSatiri(
            hesapKodu: code1,
            hesapAdi: name,
            borc: TurkceFormat.parseSayi(borcStr),
            alacak: TurkceFormat.parseSayi(alacakStr),
            borcKalan: TurkceFormat.parseSayi(borcKalanStr),
            alacakKalan: TurkceFormat.parseSayi(alacakKalanStr),
            satirNo: i + 1,
          );

          hesaplar[code1] = satir;
          i += (closingCode == code1) ? 6 : 5;
          continue;
        }
      }
    }

    // 2. DÜZEN: Tek satırlı yatay satırlar (eğer çok satırlı blok bulunamadıysa)
    if (hesaplar.isEmpty) {
      final lineRegex = RegExp(
        r'^(\d{3}(?:\.\d{2})*)\s+(.+?)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)$',
      );
      for (int i = 0; i < lines.length; i++) {
        final m = lineRegex.firstMatch(lines[i]);
        if (m != null) {
          final code = m.group(1)!;
          final name = m.group(2)!;
          final borc = TurkceFormat.parseSayi(m.group(3));
          final alacak = TurkceFormat.parseSayi(m.group(4));
          final borcKalan = TurkceFormat.parseSayi(m.group(5));
          final alacakKalan = TurkceFormat.parseSayi(m.group(6));

          hesaplar[code] = MizanHesapSatiri(
            hesapKodu: code,
            hesapAdi: name,
            borc: borc,
            alacak: alacak,
            borcKalan: borcKalan,
            alacakKalan: alacakKalan,
            satirNo: i + 1,
          );
        }
      }
    }

    return hesaplar;
  }

  /// Birime ait aylık, yıllık ve yardımcı mizan metinlerini analiz ederek
  /// eksiksiz bir `BirimMizanAnalizSonucu` oluşturur.
  static BirimMizanAnalizSonucu analizEt({
    required String birimAdi,
    required String aylikMizanMetni,
    required String yillikMizanMetni,
    String yardimciMizanMetni = '',
    double oncekiAylarHasilat = 0.0,
    List<Map<String, dynamic>> ekTevkifatFaturalari = const [],
  }) {
    final aylikHesaplar = parseHesaplar(aylikMizanMetni);
    final yillikHesaplar = parseHesaplar(yillikMizanMetni);
    final yardimciHesaplar = parseHesaplar(yardimciMizanMetni);

    final bool hasAylik = aylikHesaplar.isNotEmpty;
    final bool hasYillik = yillikHesaplar.isNotEmpty;
    final bool hasYardimci = yardimciHesaplar.isNotEmpty;

    // --- 1. 600 Hasılat & 123 POS Hesabı ---
    double hasilat600Aylik = 0.0;
    double hasilat600Kumulatif = 0.0;

    if (hasYillik && yillikHesaplar.containsKey('600')) {
      final h = yillikHesaplar['600']!;
      hasilat600Kumulatif = h.alacak > 0 ? h.alacak : h.alacakKalan;
    }

    if (hasAylik && aylikHesaplar.containsKey('600')) {
      final h = aylikHesaplar['600']!;
      hasilat600Aylik = h.alacak > 0 ? h.alacak : h.alacakKalan;
    } else if (hasilat600Kumulatif > 0) {
      if (oncekiAylarHasilat > 0) {
        hasilat600Aylik = max(0.0, hasilat600Kumulatif - oncekiAylarHasilat);
      } else {
        hasilat600Aylik = hasilat600Kumulatif;
      }
    }

    // 123 Kredi Kartı / POS
    double krediKarti123 = 0.0;
    if (hasAylik && aylikHesaplar.containsKey('123')) {
      krediKarti123 = aylikHesaplar['123']!.borc;
    } else if (hasYillik && yillikHesaplar.containsKey('123')) {
      krediKarti123 = yillikHesaplar['123']!.borc;
    }

    // --- 2. 391 Hesaplanan KDV (%10 ve %20) ---
    // Öncelikle aylık mizan tercih edilir, yoksa yıllık mizan kullanılır
    final aktifHesaplar = hasAylik ? aylikHesaplar : yillikHesaplar;

    double kdv10 = 0.0;
    double matrah10 = 0.0;
    double kdv20 = 0.0;
    double matrah20 = 0.0;

    // Alt hesap kontrolleri (391.04 = %10, 391.05 = %20)
    if (aktifHesaplar.containsKey('391.04')) {
      kdv10 = aktifHesaplar['391.04']!.alacak;
      matrah10 = double.parse((kdv10 / 0.10).toStringAsFixed(2));
    }
    if (aktifHesaplar.containsKey('391.05')) {
      kdv20 = aktifHesaplar['391.05']!.alacak;
      matrah20 = double.parse((kdv20 / 0.20).toStringAsFixed(2));
    }

    // Eğer alt hesap yoksa ve ana 391 hesabı varsa
    if (kdv10 == 0.0 && kdv20 == 0.0 && aktifHesaplar.containsKey('391')) {
      final ana391 = aktifHesaplar['391']!.alacak;
      // Genel oran %20 kabul edilir
      kdv20 = ana391;
      matrah20 = double.parse((kdv20 / 0.20).toStringAsFixed(2));
    }

    // --- 3. 191 İndirilecek KDV (%10 ve %20) ---
    double ind10 = 0.0;
    double indMatrah10 = 0.0;
    double ind20 = 0.0;
    double indMatrah20 = 0.0;

    if (aktifHesaplar.containsKey('191.04')) {
      ind10 = aktifHesaplar['191.04']!.borc;
      indMatrah10 = double.parse((ind10 / 0.10).toStringAsFixed(2));
    }
    if (aktifHesaplar.containsKey('191.05')) {
      ind20 = aktifHesaplar['191.05']!.borc;
      indMatrah20 = double.parse((ind20 / 0.20).toStringAsFixed(2));
    }
    if (ind10 == 0.0 && ind20 == 0.0 && aktifHesaplar.containsKey('191')) {
      ind20 = aktifHesaplar['191']!.borc;
      indMatrah20 = double.parse((ind20 / 0.20).toStringAsFixed(2));
    }

    // --- 4. 190 Devreden KDV ---
    double devreden190 = 0.0;
    if (aktifHesaplar.containsKey('190')) {
      devreden190 = aktifHesaplar['190']!.borcKalan;
    } else if (yillikHesaplar.containsKey('190')) {
      devreden190 = yillikHesaplar['190']!.borcKalan;
    }

    // --- 5. 360.03.05 Damga Vergisi (Ödemelerden Kesilen) ---
    // Kurumsal Kural: "Toplu mizanda 360.03.05 kodundaki ALACAK KALAN tutarı yazılır. Aylık mizanda ise ALACAK kısmındaki tutar yazılır."
    double damga360 = 0.0;
    if (hasAylik && aylikHesaplar.containsKey('360.03.05') && aylikHesaplar['360.03.05']!.alacak > 0) {
      damga360 = aylikHesaplar['360.03.05']!.alacak;
    } else if (hasYillik && yillikHesaplar.containsKey('360.03.05')) {
      damga360 = yillikHesaplar['360.03.05']!.alacakKalan;
    }
    final damgaMatrah = damga360 > 0 ? double.parse((damga360 / 0.00948).toStringAsFixed(2)) : 0.0;

    // --- 6. 360 Muhtasar (Gelir Vergisi 360.01.01 & Damga Vergisi 360.03.01) ---
    double muhtasarGelir360 = 0.0;
    double muhtasarDamga360 = 0.0;

    if (hasAylik && aylikHesaplar.containsKey('360.01.01')) {
      muhtasarGelir360 = aylikHesaplar['360.01.01']!.alacak;
    }
    if (hasAylik && aylikHesaplar.containsKey('360.03.01')) {
      muhtasarDamga360 = aylikHesaplar['360.03.01']!.alacak;
    }

    // --- 7. Ters Bakiye Denetimleri ---
    final is191TersBakiye = (aktifHesaplar['191']?.alacakKalan ?? 0.0) > 0.01;
    final is391TersBakiye = (aktifHesaplar['391']?.borcKalan ?? 0.0) > 0.01;

    // --- 8. Yardımcı Mizan Bilgileri ---
    double yardimci391 = 0.0;
    double yardimci191 = 0.0;
    double yardimci600 = 0.0;

    if (hasYardimci) {
      yardimci391 = yardimciHesaplar['391']?.alacak ?? 0.0;
      yardimci191 = yardimciHesaplar['191']?.borc ?? 0.0;
      yardimci600 = yardimciHesaplar['600']?.alacak ?? 0.0;
    }

    // Ham JSON kopyası (Denetim servisinin ve AI entegrasyonunun beklediği şema ile birebir uyumlu)
    final hamJson = {
      'birimAdi': birimAdi,
      'analizTarihi': DateTime.now().toIso8601String(),
      'hasilat600Aylik': hasilat600Aylik,
      'hasilat600Kumulatif': hasilat600Kumulatif,
      'krediKarti123': krediKarti123,
      'hesaplananKdvMatrah10': matrah10,
      'hesaplananKdv10': kdv10,
      'hesaplananKdvMatrah20': matrah20,
      'hesaplananKdv20': kdv20,
      'indirilecekKdvMatrah10': indMatrah10,
      'indirilecekKdv10': ind10,
      'indirilecekKdvMatrah20': indMatrah20,
      'indirilecekKdv20': ind20,
      'damgaVergisi360': damga360,
      'damgaMatrah': damgaMatrah,
      'muhtasarGelir360': muhtasarGelir360,
      'muhtasarDamga360': muhtasarDamga360,
      'devredenKdv190': devreden190,
      'is191TersBakiye': is191TersBakiye,
      'is391TersBakiye': is391TersBakiye,
      'yardimciMizanKullanildi': hasYardimci,
      'yardimciMizan391Toplam': yardimci391,
      'yardimciMizan191Toplam': yardimci191,
      'yardimciMizan600Toplam': yardimci600,
      'tevkifatFaturalari': ekTevkifatFaturalari,
      'kaynak': 'MizanDeterministikParser',
    };

    return BirimMizanAnalizSonucu(
      birimAdi: birimAdi,
      analizTarihi: DateTime.now(),
      hasilat600Aylik: hasilat600Aylik,
      hasilat600Kumulatif: hasilat600Kumulatif,
      krediKarti123: krediKarti123,
      hesaplananKdvMatrah10: matrah10,
      hesaplananKdv10: kdv10,
      hesaplananKdvMatrah20: matrah20,
      hesaplananKdv20: kdv20,
      indirilecekKdvMatrah10: indMatrah10,
      indirilecekKdv10: ind10,
      indirilecekKdvMatrah20: indMatrah20,
      indirilecekKdv20: ind20,
      damgaVergisi360: damga360,
      damgaMatrah: damgaMatrah,
      muhtasarGelir360: muhtasarGelir360,
      muhtasarDamga360: muhtasarDamga360,
      devredenKdv190: devreden190,
      tevkifatFaturalari: ekTevkifatFaturalari,
      yardimciMizanKullanildi: hasYardimci,
      yardimciMizan391Toplam: yardimci391,
      yardimciMizan191Toplam: yardimci191,
      yardimciMizan600Toplam: yardimci600,
      aciklama: 'Muhasebat Geçici Mizan kural tabanlı deterministik olarak başarıyla okundu.',
      hamJson: hamJson,
    );
  }
}
