import 'dart:math';
import '../../../core/turkce_format.dart';
import 'mizan_deterministik_parser.dart';

/// 360 Ödenecek Vergi ve Fonlar (360.03 Damga, 360.04 KDV 2, 360.01 Muhtasar) için
/// **Aylık Mizan + Yıllık Kümülatif Mizan + Yardımcı Defter (Muavin)** 3'lü Çapraz Çözümleme Motoru.
///
/// Özellikle **DÖSİM** gibi konsolide beyanname ödemelerinin (`Borç > 0`) ve diğer birimlerden
/// (`Diş Hekimliği`, `UBATAM`, `TÖMER`, `USEM`, `DTS`, `TADAUM`) gelen vergi tahakkuklarının
/// tek mizanda toplandığı birimlerde:
/// 1. **Yardımcı Defter (Muavin / Alt Hesap):** Yevmiye/fiş açıklamalarından ve alt hesaplardan
///    diğer birimlerin vergilerini ve vergi dairesi beyanname ödemelerini (`Borç > 0`) satır satır
///    ayıklayarak yalnızca DÖSİM'in öz vergisini çıkarır.
/// 2. **Aylık Mizan İç Mahsubu:** Ebeveyn (`360.03`) ve kardeş alt hesaplardaki `Borç` (beyanname ödeme)
///    hareketlerini `Alacak` tahakkuklarıyla mahsup eder; yaprak hesap filtresiyle çift sayımı önler.
/// 3. **Aylık ∩ Yıllık Mizan Çapraz Mutabakatı:** Yıllık kümülatif mizandaki dönem sonu net ödenmemiş
///    `Alacak Bakiyesi (Alacak Kalan)` ile Aylık Mizanı çapraz kontrol ederek ödenmiş geçmiş ay
///    beyannamelerinin cari aya sızmasını kesin olarak engeller.
class Mizan360CaprazCozumleyici {
  static final RegExp _hesapKoduBaslangicRegex = RegExp(r'^(\d{3}(?:\.\d{1,4})*)\b');
  static final RegExp _tarihRegex = RegExp(r'\b\d{2}[./]\d{2}[./]\d{4}\b');
  static final RegExp _paraTokenRegex = RegExp(
    r'^-?(?:(?:\d{1,3}(?:\.\d{3})+|\d+),\d{1,2}|(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{1,2})$',
  );

  /// DÖSİM mizanında veya yardımcı defterinde bir satırın / alt hesabın başka bir birime
  /// ait olup olmadığını tespit eder.
  static bool isDigerBirimMetni(String metin, {required bool isDosim}) {
    if (!isDosim) return false;
    // "HAKEDİŞ" kelimesinin içindeki "DİŞ" hecesinin Diş Hekimliği sanılmasını önle
    final u = metin
        .toUpperCase()
        .replaceAll('HAKEDİŞ', 'HAKEDIS')
        .replaceAll('KARDEŞ', 'KARDES');
    final hasDisBirim = RegExp(r'(?:^|[\s(\-.,/])DİŞ(?:$|[\s)\-.,/])').hasMatch(u) ||
        u.contains('DİŞ HEK') ||
        u.contains('DIS HEK') ||
        u.contains('AĞIZ VE DİŞ') ||
        u.contains('AGIZ VE DIS');
    return hasDisBirim ||
        u.contains('UBATAM') ||
        u.contains('BİLİMSEL TEKNOLOJİ') ||
        u.contains('TÖMER') ||
        u.contains('TOMER') ||
        u.contains('TÜRKÇE ÖĞRETİM') ||
        u.contains('USEM') ||
        u.contains('SÜREKLİ EĞİTİM') ||
        u.contains('SUREKLI EGITIM') ||
        u.contains('DTS') ||
        u.contains('DERİ TEKSTİL') ||
        u.contains('DERI TEKSTIL') ||
        u.contains('TADAUM') ||
        u.contains('TARIMSAL') ||
        u.contains('DİĞER BİRİM') ||
        u.contains('DIGER BIRIM') ||
        u.contains('BİRİMLERDEN') ||
        u.contains('BIRIMLERDEN') ||
        u.contains('BİRİMLER') ||
        u.contains('BIRIMLER');
  }

  /// Muavin (Yardımcı Defter) satırının devir, önceki ay veya beyanname mahsubu olup olmadığını kontrol eder.
  static bool _isDevirVeyaBeyannameTahakkukTransferi(String lineUpper) {
    return lineUpper.contains('DEVREDEN') ||
        lineUpper.contains('GEÇEN AY') ||
        lineUpper.contains('GECEN AY') ||
        lineUpper.contains('ÖNCEKİ AY') ||
        lineUpper.contains('ONCEKI AY') ||
        lineUpper.contains('KONSOLİDE') ||
        lineUpper.contains('KONSOLIDE') ||
        lineUpper.contains('BİRİM AKTARIM') ||
        lineUpper.contains('BIRIM AKTARIM') ||
        lineUpper.contains('BİRİMLERDEN') ||
        lineUpper.contains('BIRIMLERDEN') ||
        lineUpper.contains('AKTARILAN') ||
        lineUpper.contains('MAHSUPLAŞMA') ||
        lineUpper.contains('MAHSUPLASMA') ||
        lineUpper.contains('BEYANNAME AKTARIM') ||
        lineUpper.contains('BEYANNAME DEVİR');
  }

  /// 360 hesap satırından net ödenmemiş vergi yükümlülüğünü (`Alacak Kalan`) okur.
  static double oku360NetBakiye(
    MizanHesapSatiri s, {
    required bool isYillik,
    required bool isDosim,
  }) {
    if (s.borc > 0) {
      if (s.alacakKalan > 0) {
        return s.alacakKalan;
      }
      // Borç >= Alacak ise (hesap ödenip sıfırlanmışsa veya DÖSİM/Yıllık mizanda kapanmışsa) bakiye 0'dır!
      if (isYillik || isDosim || (s.borc - s.alacak).abs() < 1.0) {
        return 0.0;
      }
    }
    return (!isYillik)
        ? (s.alacakKalan > 0 ? s.alacakKalan : s.alacak)
        : (s.alacakKalan > 0 ? s.alacakKalan : (s.borc == 0 ? s.alacak : 0.0));
  }

  /// Yardımcı Defter (Muavin Defteri) metnindeki yevmiye/fiş hareket satırlarını tarayarak
  /// `360.03` Damga Vergisi, `360.04` KDV 2 ve `360.01` Muhtasar tutarlarını satır bazında ayrıştırır.
  static ({
    bool muavinHareketBulundu,
    double toplamDamga,
    double ihaleKararPulu,
    double ihaleSozlesme,
    bool kdv2HareketBulundu,
    double kdv2Tevkifat,
    bool muhtasarHareketBulundu,
    double muhtasarGelir,
    double muhtasarDamga,
  }) cozumleYardimciDefterMuavinHareketleri(
    String yardimciMetin, {
    required bool isDosim,
    int? filtreAy,
  }) {
    if (yardimciMetin.trim().isEmpty) {
      return (
        muavinHareketBulundu: false,
        toplamDamga: 0.0,
        ihaleKararPulu: 0.0,
        ihaleSozlesme: 0.0,
        kdv2HareketBulundu: false,
        kdv2Tevkifat: 0.0,
        muhtasarHareketBulundu: false,
        muhtasarGelir: 0.0,
        muhtasarDamga: 0.0,
      );
    }

    final lines = yardimciMetin
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String aktifKod = '';
    String aktifHesapAdi = '';
    bool damgaHareketGoruldu = false;
    bool kdv2HareketGoruldu = false;
    bool muhtasarHareketGoruldu = false;

    double netDamga = 0.0;
    double netKararPulu = 0.0;
    double netSozlesme = 0.0;
    double netKdv2 = 0.0;
    double netMuhtasarGelir = 0.0;
    double netMuhtasarDamga = 0.0;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final rawLine = lines[lineIdx];
      final lineUpper = rawLine.toUpperCase();

      // 1. Toplam / Özet / Başlık satırlarını atla
      if (lineUpper.contains('GENEL TOPLAM') ||
          lineUpper.contains('SAYFA TOPLAMI') ||
          lineUpper.contains('NAKLİ YEKÜN') ||
          lineUpper.contains('NAKLI YEKUN') ||
          lineUpper.startsWith('TOPLAM') ||
          lineUpper.startsWith('ARA TOPLAM') ||
          RegExp(r'\|\s*TOPLAM\s*\|').hasMatch(lineUpper)) {
        continue;
      }

      // 2. Satırda 360 hesap kodu geçiyor mu kontrol et
      final kodMatch = RegExp(r'\b(360(?:\.\d{1,4})+)\b').firstMatch(rawLine);
      if (kodMatch != null && (rawLine.contains('Hesap Kodu:') || rawLine.contains('360.') || rawLine.toUpperCase().contains('TOPLAMI') || rawLine.toUpperCase().contains('KALANI'))) {
        aktifKod = kodMatch.group(1)!;
        aktifHesapAdi = rawLine;
      } else {
        // Yalnızca gerçek bir başka hesap kodu başlığı ise (örn: "Hesap Kodu: 500" veya "102.01 Bankalar")
        // Fiş/yevmiye no ("713"), sayfa no ("185 / 297") veya tutar ("979,01") gibi satırları hesap kodu sanma!
        final baskaHesapMatch = RegExp(r'(?:Hesap Kodu:\s*)?^([1-9]\d{2}(?:\.\d{1,4})+)\s+([A-ZÇĞİÖŞÜa-zçğıöşü]+)').firstMatch(rawLine.replaceAll('|', ' ').trim());
        if (baskaHesapMatch != null) {
          final bKod = baskaHesapMatch.group(1)!;
          if (!bKod.startsWith('360')) {
            aktifKod = '';
            aktifHesapAdi = '';
            continue;
          }
        }
      }

      if (aktifKod.isEmpty) continue;

      final normKod = aktifKod.replaceAll(RegExp(r'\.0+'), '.');
      final isDamga0305Hesabi = (aktifKod.startsWith('360.03') || normKod.startsWith('360.3')) &&
          aktifKod != '360.03.01' &&
          normKod != '360.3.1' &&
          !aktifKod.startsWith('360.03.01.') &&
          !normKod.startsWith('360.3.1.');
      final isKdv2Hesabi = aktifKod.startsWith('360.04') ||
          normKod.startsWith('360.4') ||
          aktifHesapAdi.toUpperCase().contains('TEVKİFAT') ||
          aktifHesapAdi.toUpperCase().contains('SORUMLU SIFATIYLA');
      final isMuhtasarGelirHesabi = aktifKod == '360.01' ||
          normKod == '360.1' ||
          aktifKod.startsWith('360.01.') ||
          normKod.startsWith('360.1.') ||
          aktifHesapAdi.toUpperCase().contains('GELİR VERGİSİ') ||
          aktifHesapAdi.toUpperCase().contains('G.V.');
      final isMuhtasarDamgaHesabi = aktifKod == '360.03.01' ||
          normKod == '360.3.1' ||
          aktifKod.startsWith('360.03.01.') ||
          normKod.startsWith('360.3.1.');

      if (!isDamga0305Hesabi && !isKdv2Hesabi && !isMuhtasarGelirHesabi && !isMuhtasarDamgaHesabi) {
        continue;
      }

      // 3. Bu satır bir Muavin (Yevmiye / Fiş) hareket satırı mı?
      final tarihMatch = _tarihRegex.firstMatch(rawLine);
      final hasTarih = tarihMatch != null;
      final hasHareketIpucu = hasTarih ||
          lineUpper.contains('YEV') ||
          lineUpper.contains('FİŞ') ||
          lineUpper.contains('FIS') ||
          lineUpper.contains('MİF') ||
          lineUpper.contains('MIF') ||
          lineUpper.contains('TAHAKKUK') ||
          lineUpper.contains('KESİNTİ') ||
          lineUpper.contains('KESINTI') ||
          lineUpper.contains('FATURA') ||
          lineUpper.contains('ALIMI') ||
          lineUpper.contains('BEYANNAME');

      final startsWithCode = _hesapKoduBaslangicRegex.hasMatch(rawLine.replaceAll('|', ' ').trim());
      if (startsWithCode && !hasTarih && !lineUpper.contains('YEV') && !lineUpper.contains('FİŞ')) {
        continue;
      }
      if (!hasHareketIpucu) continue;

      // İlgili hareketin açıklamasını bul (aynı satırda veya sonraki satırda "Açıklama: ...")
      String aciklamaMetni = rawLine;
      for (int nextIdx = lineIdx + 1; nextIdx < min(lines.length, lineIdx + 12); nextIdx++) {
        final nLine = lines[nextIdx];
        if (nLine.toUpperCase().startsWith('AÇIKLAMA:') || nLine.toUpperCase().startsWith('ACIKLAMA:')) {
          aciklamaMetni += ' ' + nLine;
          break;
        }
        if (_tarihRegex.hasMatch(nLine) || nLine.contains('Hesap Kodu:')) break;
      }

      // Tarih ay filtresi (Eğer yıllık yardımcı defter ise sadece seçili aya ait hareketleri al, örn: .09.2026)
      if (filtreAy != null && hasTarih) {
        final tStr = tarihMatch.group(0)!;
        final tParts = tStr.split(RegExp(r'[./]'));
        if (tParts.length >= 2) {
          final rowAy = int.tryParse(tParts[1]);
          if (rowAy != null && rowAy != filtreAy) {
            continue;
          }
        }
      }

      // 4. Satırdaki parasal tutarları çıkar (tek satır veya çok satırlı PDF bloğu)
      final tokens = rawLine
          .replaceAll('|', ' ')
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final paraList = <double>[];
      for (final tok in tokens) {
        if (_tarihRegex.hasMatch(tok)) continue;
        if (_hesapKoduBaslangicRegex.hasMatch(tok) && tok.contains('.')) {
          if (!tok.contains(',') && RegExp(r'^\d{3}\.\d{2}').hasMatch(tok)) continue;
        }
        if (_paraTokenRegex.hasMatch(tok)) {
          paraList.add(TurkceFormat.parseSayi(tok));
        }
      }

      // PDF dikey sütun çıktısı desteği: Eğer aynı satırda para tutarları çıkmadıysa,
      // bu işlem bloğunun sonraki satırlarından (en fazla 12 satır) tutarları ve açıklamayı topla:
      if (paraList.length < 2 && hasTarih) {
        for (int nextIdx = lineIdx + 1; nextIdx < min(lines.length, lineIdx + 12); nextIdx++) {
          final nLine = lines[nextIdx].trim();
          if (_tarihRegex.hasMatch(nLine) ||
              nLine.contains('Hesap Kodu:') ||
              nLine.contains('Toplamı :') ||
              nLine.contains('Kalanı :')) {
            break;
          }
          if (nLine.toUpperCase().startsWith('AÇIKLAMA:') || nLine.toUpperCase().startsWith('ACIKLAMA:')) {
            if (!aciklamaMetni.contains(nLine)) {
              aciklamaMetni += ' ' + nLine;
            }
            continue;
          }
          // Para formatındaki sayıları yakala (Türkçe formatında virgüllü: 0,00 veya 608,28)
          if (RegExp(r'^-?(?:\d{1,3}(?:\.\d{3})*|\d+),\d{2}$').hasMatch(nLine)) {
            paraList.add(TurkceFormat.parseSayi(nLine));
          }
        }
      }

      final aciklamaUpper = aciklamaMetni.toUpperCase();

      if (paraList.length < 2) continue;

      double borc = 0.0;
      double alacak = 0.0;
      if (paraList.length >= 4) {
        borc = paraList[paraList.length - 4];
        alacak = paraList[paraList.length - 3];
      } else if (paraList.length == 3) {
        borc = paraList[0];
        alacak = paraList[1];
      } else {
        borc = paraList[0];
        alacak = paraList[1];
      }

      if (isDamga0305Hesabi) damgaHareketGoruldu = true;
      if (isKdv2Hesabi) kdv2HareketGoruldu = true;
      if (isMuhtasarGelirHesabi || isMuhtasarDamgaHesabi) muhtasarHareketGoruldu = true;

      // 5. DÖSİM Filtresi: Diğer birimlere ait satırları ve aktarma/beyanname ödeme satırlarını ayıkla!
      final isDigerBirim = isDigerBirimMetni(aciklamaMetni, isDosim: isDosim) ||
          isDigerBirimMetni(aktifHesapAdi, isDosim: isDosim) ||
          _isDevirVeyaBeyannameTahakkukTransferi(aciklamaUpper);

      if (isDigerBirim) {
        continue;
      }

      // Beyanname ödemeleri (Borç > 0)
      if (aciklamaUpper.contains('BEYANNAME') || aciklamaUpper.contains('VERGİ DAİRESİ') || aciklamaUpper.contains('VERGI DAIRESI')) {
        continue;
      }

      // 6. Alacak > 0 (Yeni öz vergi tahakkuku)
      if (alacak > 0 && borc == 0) {
        if (isDamga0305Hesabi) {
          if (aktifKod == '360.03.02' ||
              normKod == '360.3.2' ||
              aktifKod.startsWith('360.03.02.') ||
              aciklamaUpper.contains('KARAR PULU') ||
              aciklamaUpper.contains('İHALE KARAR')) {
            netKararPulu += alacak;
          } else if (aktifKod == '360.03.03' ||
              normKod == '360.3.3' ||
              aktifKod.startsWith('360.03.03.') ||
              aciklamaUpper.contains('SÖZLEŞME') ||
              aciklamaUpper.contains('SOZLESME') ||
              aciklamaUpper.contains('MUKAVELE')) {
            netSozlesme += alacak;
          } else {
            netDamga += alacak;
          }
        } else if (isKdv2Hesabi) {
          netKdv2 += alacak;
        } else if (isMuhtasarGelirHesabi) {
          netMuhtasarGelir += alacak;
        } else if (isMuhtasarDamgaHesabi) {
          netMuhtasarDamga += alacak;
        }
      }
    }

    return (
      muavinHareketBulundu: damgaHareketGoruldu,
      toplamDamga: double.parse(netDamga.toStringAsFixed(2)),
      ihaleKararPulu: double.parse(netKararPulu.toStringAsFixed(2)),
      ihaleSozlesme: double.parse(netSozlesme.toStringAsFixed(2)),
      kdv2HareketBulundu: kdv2HareketGoruldu,
      kdv2Tevkifat: double.parse(netKdv2.toStringAsFixed(2)),
      muhtasarHareketBulundu: muhtasarHareketGoruldu,
      muhtasarGelir: double.parse(netMuhtasarGelir.toStringAsFixed(2)),
      muhtasarDamga: double.parse(netMuhtasarDamga.toStringAsFixed(2)),
    );
  }

  /// Tek bir mizan haritasından (`aylik`, `yardimci` veya `yillik`) `360.03` Damga Vergisi
  /// detaylarını (yaprak hesap filtresi, diğer birim filtresi ve ebeveyn/kardeş Borç mahsubu ile) çıkarır.
  static ({
    bool hesapBulundu,
    bool borcHareketiVar,
    double toplamDamga,
    double ihaleKararPulu,
    double ihaleSozlesme,
  }) bulMizanDamga360Detayli(
    Map<String, MizanHesapSatiri> hesapMap, {
    required bool isYillik,
    required bool isDosim,
  }) {
    if (hesapMap.isEmpty) {
      return (
        hesapBulundu: false,
        borcHareketiVar: false,
        toplamDamga: 0.0,
        ihaleKararPulu: 0.0,
        ihaleSozlesme: 0.0,
      );
    }

    double kararPulu = 0.0;
    double sozlesmeDamga = 0.0;
    double altToplam = 0.0;
    double kardesTersBorcKalan = 0.0;
    bool altHesapBulundu = false;
    bool borcHareketiVar = false;

    // Ebeveyn 360.03 bilgisini önceden kontrol et (ebeveyn bazda Borç beyanname ödemesi yapılmış olabilir)
    MizanHesapSatiri? ana36003Satir;
    double ucretDamgaNet = 0.0;
    for (final entry in hesapMap.entries) {
      final k = entry.key;
      final norm = k.replaceAll(RegExp(r'\.0+'), '.');
      if (k == '360.03' || norm == '360.3') {
        ana36003Satir = entry.value;
        if (ana36003Satir.borc > 0) borcHareketiVar = true;
      } else if (k == '360.03.01' || norm == '360.3.1') {
        ucretDamgaNet = oku360NetBakiye(entry.value, isYillik: isYillik, isDosim: isDosim);
      }
    }

    // A) 360.03 altındaki YAPRAK hesapları tara (Ücret damgası .01 hariç)
    for (final entry in hesapMap.entries) {
      final kod = entry.key;
      final norm = kod.replaceAll(RegExp(r'\.0+'), '.');
      if ((kod.startsWith('360.03.') || norm.startsWith('360.3.')) &&
          norm != '360.3.1' &&
          kod != '360.03.01' &&
          !norm.startsWith('360.3.1.') &&
          !kod.startsWith('360.03.01.')) {
        final altVar = hesapMap.keys.any((other) => other != kod && other.startsWith('$kod.'));
        if (altVar) continue;

        altHesapBulundu = true;
        final s = entry.value;
        if (s.borc > 0) borcHareketiVar = true;

        if (isDigerBirimMetni(s.hesapAdi, isDosim: isDosim)) continue;

        // Eğer kardeş bir 360.03.xx alt hesabında beyanname ödemesinden kaynaklı Borç Kalan (Borç > Alacak) varsa:
        if (s.borcKalan > 0 && s.alacakKalan == 0) {
          kardesTersBorcKalan += s.borcKalan;
          continue;
        }

        final val = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
        if (val <= 0) continue;

        final adUpper = s.hesapAdi.toUpperCase();
        if (kod == '360.03.02' ||
            norm == '360.3.2' ||
            kod.startsWith('360.03.02.') ||
            norm.startsWith('360.3.2.') ||
            adUpper.contains('KARAR PULU') ||
            adUpper.contains('İHALE KARAR') ||
            adUpper.contains('IHALE KARAR')) {
          kararPulu += val;
        } else if (kod == '360.03.03' ||
            norm == '360.3.3' ||
            kod.startsWith('360.03.03.') ||
            norm.startsWith('360.3.3.') ||
            adUpper.contains('SÖZLEŞME') ||
            adUpper.contains('SOZLESME') ||
            adUpper.contains('MUKAVELE')) {
          sozlesmeDamga += val;
        } else {
          altToplam += val;
        }
      }
    }

    if (altHesapBulundu) {
      // Kardeş alt hesaba yazılmış beyanname ödemesi (Borç Kalan) varsa mahsup et
      if (kardesTersBorcKalan > 0 && altToplam > 0) {
        altToplam = max(0.0, altToplam - kardesTersBorcKalan);
      }
      // Ebeveyn 360.03 hesabında Borç (beyanname ödemesi) varsa ve ebeveynin net Alacak Kalan'ı
      // alt hesap toplamından küçükse (ödeme üst hesaba veya farklı alt hesaba işlenmişse), ebeveyn net bakiye ile sınırla!
      if (ana36003Satir != null && ana36003Satir.borc > 0) {
        final anaNet = max(
          0.0,
          oku360NetBakiye(ana36003Satir, isYillik: isYillik, isDosim: isDosim) - ucretDamgaNet,
        );
        final toplamAlt = altToplam + kararPulu + sozlesmeDamga;
        if (toplamAlt > anaNet + 0.05) {
          final kalanAna = max(0.0, anaNet - kararPulu - sozlesmeDamga);
          altToplam = min(altToplam, kalanAna);
        }
      }

      return (
        hesapBulundu: true,
        borcHareketiVar: borcHareketiVar,
        toplamDamga: double.parse(altToplam.toStringAsFixed(2)),
        ihaleKararPulu: double.parse(kararPulu.toStringAsFixed(2)),
        ihaleSozlesme: double.parse(sozlesmeDamga.toStringAsFixed(2)),
      );
    }

    // B) Sadece Ana 360.03 hesabı varsa: Ücret damgası (360.03.01) düşülerek
    if (ana36003Satir != null) {
      final anaTutar = oku360NetBakiye(ana36003Satir, isYillik: isYillik, isDosim: isDosim);
      final net = max(0.0, anaTutar - ucretDamgaNet);
      return (
        hesapBulundu: true,
        borcHareketiVar: borcHareketiVar,
        toplamDamga: double.parse(net.toStringAsFixed(2)),
        ihaleKararPulu: 0.0,
        ihaleSozlesme: 0.0,
      );
    }

    // C) Hesap adı ile tarama: 360 altındaki adı "DAMGA" içeren ve "ÜCRET/MAAŞ/BORDRO" içermeyen YAPRAK hesaplar
    double adlaBulunan = 0.0;
    bool adlaHesapGoruldu = false;
    for (final entry in hesapMap.entries) {
      final k = entry.key;
      if (k.startsWith('360') && k != '360') {
        final altVar = hesapMap.keys.any((other) => other != k && other.startsWith('$k.'));
        if (altVar) continue;

        final ad = entry.value.hesapAdi.toUpperCase();
        if (ad.contains('DAMGA') &&
            !ad.contains('ÜCRET') &&
            !ad.contains('UCRET') &&
            !ad.contains('MAAŞ') &&
            !ad.contains('MAAS') &&
            !ad.contains('BORDRO')) {
          adlaHesapGoruldu = true;
          final s = entry.value;
          if (s.borc > 0) borcHareketiVar = true;
          if (isDigerBirimMetni(s.hesapAdi, isDosim: isDosim)) continue;

          final val = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
          if (val <= 0) continue;
          if (ad.contains('KARAR PULU') || ad.contains('İHALE KARAR') || ad.contains('IHALE KARAR')) {
            kararPulu += val;
          } else if (ad.contains('SÖZLEŞME') || ad.contains('SOZLESME')) {
            sozlesmeDamga += val;
          } else {
            adlaBulunan += val;
          }
        }
      }
    }

    if (adlaHesapGoruldu) {
      return (
        hesapBulundu: true,
        borcHareketiVar: borcHareketiVar,
        toplamDamga: double.parse(adlaBulunan.toStringAsFixed(2)),
        ihaleKararPulu: double.parse(kararPulu.toStringAsFixed(2)),
        ihaleSozlesme: double.parse(sozlesmeDamga.toStringAsFixed(2)),
      );
    }

    return (
      hesapBulundu: false,
      borcHareketiVar: false,
      toplamDamga: 0.0,
      ihaleKararPulu: 0.0,
      ihaleSozlesme: 0.0,
    );
  }

  /// **Aylık Mizan + Yıllık Mizan + Yardımcı Defter (Muavin)** 3'lü kaynaklarını birlikte
  /// değerlendirerek nihai Damga Vergisi (`360.03.05`), İhale Karar Pulu (`360.03.02`) ve
  /// İhale Sözleşme Damga Vergisini (`360.03.03`) hesaplar.
  static ({double toplamDamga, double ihaleKararPulu, double ihaleSozlesme}) cozumleCaprazDamga360({
    required Map<String, MizanHesapSatiri> aylikHesaplar,
    required Map<String, MizanHesapSatiri> yillikHesaplar,
    required Map<String, MizanHesapSatiri> yardimciHesaplar,
    required String yardimciMizanMetni,
    required bool isAylikKutuKumulatif,
    required bool isDosim,
  }) {
    final hasAylik = aylikHesaplar.isNotEmpty;
    final hasYillik = yillikHesaplar.isNotEmpty;
    final hasYardimci = yardimciHesaplar.isNotEmpty || yardimciMizanMetni.trim().isNotEmpty;

    // 1. YARDIMCI DEFTER (MUAVİN HAREKET SATIRLARI) KONTROLÜ:
    // Eğer Yardımcı Defter / Muavin içinde fiş/yevmiye hareket satırları varsa,
    // özellikle DÖSİM'de diğer birimlerin tahakkukları ve beyanname ödemeleri (Borç)
    // satır bazında ayıklandığı için EN YÜKSEK ÖNCELİĞE sahiptir!
    final muavin = cozumleYardimciDefterMuavinHareketleri(
      yardimciMizanMetni,
      isDosim: isDosim,
    );

    final aylikDetay = hasAylik
        ? bulMizanDamga360Detayli(aylikHesaplar, isYillik: isAylikKutuKumulatif, isDosim: isDosim)
        : (hesapBulundu: false, borcHareketiVar: false, toplamDamga: 0.0, ihaleKararPulu: 0.0, ihaleSozlesme: 0.0);

    final yardimciDetay = yardimciHesaplar.isNotEmpty
        ? bulMizanDamga360Detayli(yardimciHesaplar, isYillik: false, isDosim: isDosim)
        : (hesapBulundu: false, borcHareketiVar: false, toplamDamga: 0.0, ihaleKararPulu: 0.0, ihaleSozlesme: 0.0);

    final yillikDetay = hasYillik
        ? bulMizanDamga360Detayli(yillikHesaplar, isYillik: true, isDosim: isDosim)
        : (hesapBulundu: false, borcHareketiVar: false, toplamDamga: 0.0, ihaleKararPulu: 0.0, ihaleSozlesme: 0.0);

    // Eğer Muavin yevmiye satırları bulunduysa (ve DÖSİM ise veya Aylık Mizan yoksa):
    if (muavin.muavinHareketBulundu && (isDosim || !aylikDetay.hesapBulundu)) {
      var mDamga = muavin.toplamDamga;
      // Yıllık Mizan varsa ve Yıllık net Alacak Kalan daha küçükse dönem sonu bakiye tavanını uygula
      if (yillikDetay.hesapBulundu && yillikDetay.borcHareketiVar && yillikDetay.toplamDamga < mDamga) {
        mDamga = yillikDetay.toplamDamga;
      }
      return (
        toplamDamga: mDamga,
        ihaleKararPulu: muavin.ihaleKararPulu > 0 ? muavin.ihaleKararPulu : aylikDetay.ihaleKararPulu,
        ihaleSozlesme: muavin.ihaleSozlesme > 0 ? muavin.ihaleSozlesme : aylikDetay.ihaleSozlesme,
      );
    }

    // 2. ALT HESAP YARDIMCI MİZANI ÖNCELİĞİ (Özellikle DÖSİM için):
    // Eğer Yardımcı Mizan'da 360.03 alt hesapları varsa ve DÖSİM'de diğer birimlerin alt hesaplarını
    // filtreleyerek Aylık Mizan'daki konsolide toplamdan daha düşük/temiz bir sonuç ürettiyse,
    // Yardımcı Mizan'ı Aylık Mizan'a önceliklendir!
    if (hasYardimci && yardimciDetay.hesapBulundu) {
      if (isDosim || !aylikDetay.hesapBulundu || (aylikDetay.toplamDamga == 0.0 && yardimciDetay.toplamDamga > 0)) {
        var yDamga = yardimciDetay.toplamDamga;
        if (yillikDetay.hesapBulundu && yillikDetay.borcHareketiVar && yillikDetay.toplamDamga < yDamga) {
          yDamga = yillikDetay.toplamDamga;
        }
        return (
          toplamDamga: yDamga,
          ihaleKararPulu: yardimciDetay.ihaleKararPulu > 0 ? yardimciDetay.ihaleKararPulu : aylikDetay.ihaleKararPulu,
          ihaleSozlesme: yardimciDetay.ihaleSozlesme > 0 ? yardimciDetay.ihaleSozlesme : aylikDetay.ihaleSozlesme,
        );
      }
    }

    // 3. AYLIK MİZAN ∩ YILLIK KÜMÜLATİF MİZAN ÇAPRAZ MUTABAKATI:
    if (aylikDetay.hesapBulundu) {
      double nihaiDamga = aylikDetay.toplamDamga;
      double nihaiKararPulu = aylikDetay.ihaleKararPulu;
      double nihaiSozlesme = aylikDetay.ihaleSozlesme;

      if (yillikDetay.hesapBulundu) {
        // A) Eğer Yıllık Mizan'da 360.03 hesabında Borç (beyanname ödemesi) hareketi varsa ve
        //    dönem sonu net ödenmemiş Yıllık Alacak Bakiyesi (alacakKalan), Aylık Mizan'dan küçükse:
        //    Aylık Mizan'da mahsup edilmemiş/kümülatif tutar vardır; dönem sonu net bakiye (Yıllık Alacak Kalan) esas alınır!
        if (yillikDetay.borcHareketiVar && yillikDetay.toplamDamga < nihaiDamga) {
          nihaiDamga = yillikDetay.toplamDamga;
        }
        // B) Eğer Aylık Mizan'da geçen ayın büyük beyanname ödemesi (Borç > Alacak) nedeniyle
        //    Aylık Alacak Kalan 0 çıkmışsa, fakat Yıllık Mizan'da geçmiş ay Alacak + bu ay Borç birbirini
        //    kapatıp cari ayın net ödenmemiş Alacak Kalan bakiyesini (> 0) bırakmışsa:
        //    Yıllık Mizan'daki dönem sonu net Alacak Kalan bakiyesini al!
        else if (nihaiDamga == 0.0 && aylikDetay.borcHareketiVar && yillikDetay.toplamDamga > 0) {
          nihaiDamga = yillikDetay.toplamDamga;
        }

        if (nihaiKararPulu == 0.0 && yillikDetay.ihaleKararPulu > 0) {
          nihaiKararPulu = yillikDetay.ihaleKararPulu;
        }
        if (nihaiSozlesme == 0.0 && yillikDetay.ihaleSozlesme > 0) {
          nihaiSozlesme = yillikDetay.ihaleSozlesme;
        }
      }

      return (
        toplamDamga: nihaiDamga,
        ihaleKararPulu: nihaiKararPulu,
        ihaleSozlesme: nihaiSozlesme,
      );
    }

    // 4. Sadece Yıllık Mizan varsa:
    if (yillikDetay.hesapBulundu) {
      return (
        toplamDamga: yillikDetay.toplamDamga,
        ihaleKararPulu: yillikDetay.ihaleKararPulu,
        ihaleSozlesme: yillikDetay.ihaleSozlesme,
      );
    }

    return (toplamDamga: 0.0, ihaleKararPulu: 0.0, ihaleSozlesme: 0.0);
  }

  /// **Aylık Mizan + Yıllık Mizan + Yardımcı Defter (Muavin)** kaynaklarını birlikte
  /// değerlendirerek Muhtasar Gelir Vergisi (`360.01` / `360.01.01`) ve Muhtasar Ücret Damga Vergisini (`360.03.01`) hesaplar.
  static ({double muhtasarGelir, double muhtasarDamga}) cozumleCaprazMuhtasar({
    required Map<String, MizanHesapSatiri> aylikHesaplar,
    required Map<String, MizanHesapSatiri> yillikHesaplar,
    required Map<String, MizanHesapSatiri> yardimciHesaplar,
    required String yardimciMizanMetni,
    required bool isAylikKutuKumulatif,
    required bool isDosim,
    int? filtreAy,
  }) {
    // 1. Muavin (Yardımcı Defter) satır hareketleri kontrolü:
    final muavin = cozumleYardimciDefterMuavinHareketleri(
      yardimciMizanMetni,
      isDosim: isDosim,
      filtreAy: filtreAy,
    );

    if (muavin.muhtasarHareketBulundu && isDosim) {
      return (
        muhtasarGelir: muavin.muhtasarGelir,
        muhtasarDamga: muavin.muhtasarDamga,
      );
    }

    // 2. Mizan hesap satırlarından okuma:
    double bulGelir(Map<String, MizanHesapSatiri> hMap, {required bool isYillik}) {
      if (hMap.isEmpty) return 0.0;
      for (final key in hMap.keys) {
        final norm = key.replaceAll(RegExp(r'\.0+'), '.');
        if (norm == '360.1.1' || key == '360.01.01') {
          final altVar = hMap.keys.any((o) => o != key && o.startsWith('$key.'));
          if (!altVar) {
            final s = hMap[key]!;
            final v = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
            if (v > 0) return v;
          }
        }
      }
      double toplam = 0.0;
      for (final entry in hMap.entries) {
        final k = entry.key;
        final norm = k.replaceAll(RegExp(r'\.0+'), '.');
        final ad = entry.value.hesapAdi.toUpperCase();
        if (isDigerBirimMetni(entry.value.hesapAdi, isDosim: isDosim)) continue;
        if ((k.startsWith('360.01') || norm.startsWith('360.1') || ad.contains('GELİR VERGİSİ') || ad.contains('G.V.')) &&
            !ad.contains('DAMGA')) {
          final altVar = hMap.keys.any((o) => o != k && o.startsWith('$k.'));
          if (!altVar) {
            final s = entry.value;
            final v = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
            toplam += v;
          }
        }
      }
      return double.parse(toplam.toStringAsFixed(2));
    }

    double bulDamga(Map<String, MizanHesapSatiri> hMap, {required bool isYillik}) {
      if (hMap.isEmpty) return 0.0;
      for (final key in hMap.keys) {
        final norm = key.replaceAll(RegExp(r'\.0+'), '.');
        if (norm == '360.3.1' || key == '360.03.01') {
          final altVar = hMap.keys.any((o) => o != key && o.startsWith('$key.'));
          if (!altVar) {
            final s = hMap[key]!;
            final v = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
            if (v > 0) return v;
          }
        }
      }
      double toplam = 0.0;
      for (final entry in hMap.entries) {
        final k = entry.key;
        if (k.startsWith('360') && k != '360') {
          final altVar = hMap.keys.any((o) => o != k && o.startsWith('$k.'));
          if (altVar) continue;
          if (isDigerBirimMetni(entry.value.hesapAdi, isDosim: isDosim)) continue;
          final ad = entry.value.hesapAdi.toUpperCase();
          if (ad.contains('DAMGA') &&
              (ad.contains('ÜCRET') || ad.contains('UCRET') || ad.contains('MAAŞ') || ad.contains('MAAS') || ad.contains('BORDRO'))) {
            final s = entry.value;
            final v = oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);
            if (v > 0) toplam += v;
          }
        }
      }
      return double.parse(toplam.toStringAsFixed(2));
    }

    double gv = 0.0;
    double dv = 0.0;
    if (aylikHesaplar.isNotEmpty) {
      gv = bulGelir(aylikHesaplar, isYillik: isAylikKutuKumulatif);
      dv = bulDamga(aylikHesaplar, isYillik: isAylikKutuKumulatif);
    }
    if (gv == 0.0 && yardimciHesaplar.isNotEmpty) {
      gv = bulGelir(yardimciHesaplar, isYillik: false);
    }
    if (dv == 0.0 && yardimciHesaplar.isNotEmpty) {
      dv = bulDamga(yardimciHesaplar, isYillik: false);
    }
    if (gv == 0.0 && yillikHesaplar.isNotEmpty) {
      gv = bulGelir(yillikHesaplar, isYillik: true);
    }
    if (dv == 0.0 && yillikHesaplar.isNotEmpty) {
      dv = bulDamga(yillikHesaplar, isYillik: true);
    }

    return (muhtasarGelir: gv, muhtasarDamga: dv);
  }
}
