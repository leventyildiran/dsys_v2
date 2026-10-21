import 'dart:math';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_belge_model.dart';
import 'beyanname_denetim_servisi.dart';

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
  // Regex: 3 haneli hesap kodu ve alt hesapları (örn: "600", "600.12", "191.05", "360.03.05", "600.01.001")
  static final RegExp _hesapKoduRegex = RegExp(r'^\d{3}(?:\.\d{1,4})*$');

  // Regex: Türkçe veya standart para formatı (örn: "16.247,44", "0,00", "-500,00", "16247.44", "0")
  static final RegExp _sayiRegex = RegExp(
    r'^-?(?:(?:\d{1,3}(?:\.\d{3})+|\d+),\d{1,2}|(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{1,2}|\d+)$',
  );

  /// Verilen metinden mizan üst bilgilerini (Birim adı, başlangıç/bitiş tarihi) çıkarır.
  static MizanMetaVeri extractMetaVeri(String text) {
    if (text.isEmpty) return const MizanMetaVeri();

    String? muhasebeBirimi;
    String? kamuIdaresi;
    String? baslangicTarihi;
    String? bitisTarihi;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll('|', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < min(lines.length, 60); i++) {
      final line = lines[i];
      if (line.contains('Muhasebe Birimi')) {
        final sameLine = line.split('Muhasebe Birimi').last.replaceFirst(RegExp(r'^[\s:.\-]+'), '').trim();
        if (sameLine.length > 3 && sameLine != '-') {
          muhasebeBirimi = sameLine;
        } else if (i + 1 < lines.length) {
          final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
          if (next != '-' && next.isNotEmpty) muhasebeBirimi = next;
        }
      }
      if (line.contains('Kamu İdaresi')) {
        final sameLine = line.split('Kamu İdaresi').last.replaceFirst(RegExp(r'^[\s:.\-]+'), '').trim();
        if (sameLine.length > 3 && sameLine != '-') {
          kamuIdaresi = sameLine;
        } else if (i + 1 < lines.length) {
          final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
          if (next != '-' && next.isNotEmpty) kamuIdaresi = next;
        }
      }
      if (line.contains('Başlangıç Tarihi')) {
        final dateMatch = RegExp(r'\d{2}[./]\d{2}[./]\d{4}').firstMatch(line);
        if (dateMatch != null) {
          baslangicTarihi = dateMatch.group(0);
        } else if (i + 1 < lines.length) {
          final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
          if (next.isNotEmpty) baslangicTarihi = next;
        }
      }
      if (line.contains('Bitiş Tarihi')) {
        final dateMatch = RegExp(r'\d{2}[./]\d{2}[./]\d{4}').firstMatch(line);
        if (dateMatch != null) {
          bitisTarihi = dateMatch.group(0);
        } else if (i + 1 < lines.length) {
          final next = lines[i + 1].replaceFirst(RegExp(r'^:\s*'), '').trim();
          if (next.isNotEmpty) bitisTarihi = next;
        }
      }
    }

    final isYillik = baslangicTarihi != null &&
        (baslangicTarihi.startsWith('01.01.') || baslangicTarihi.startsWith('01/01/'));
    return MizanMetaVeri(
      muhasebeBirimi: muhasebeBirimi,
      kamuIdaresi: kamuIdaresi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
      isYillikKumulatif: isYillik,
    );
  }

  /// Dosya adı ve metin içeriğinden hangi birime ve hangi belge slotuna ait olduğunu otomatik tahmin eder.
  static ({String? birimAdi, BirimBelgeSlotTuru slotTuru}) otomatikBelgeSiniflandir({
    required String dosyaAdi,
    required String metin,
    required List<String> aktifBirimler,
  }) {
    String cleanStr(String s) => s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    final cleanName = cleanStr(dosyaAdi);
    final meta = extractMetaVeri(metin);

    // 1. Birim Tespiti:
    // A) Dosya adından tam/kısa anahtar veya kanonik eşleşme
    String? bulunanBirim;
    for (final b in aktifBirimler) {
      final cKey = BirimAdlandirma.canonicalKey(b);
      final kisa = BirimAdlandirma.kisaAdGetir(b).toLowerCase();
      final cleanKisa = cleanStr(kisa);
      final isTarimMatch = cKey == 'tadaum' && (cleanName.contains('tarim') || cleanName.contains('tarimsal') || cleanName.contains('tadaum'));
      if (cKey.isNotEmpty &&
          (cleanName.contains(cKey) ||
              cleanName.contains(cleanKisa) ||
              isTarimMatch ||
              BirimAdlandirma.canonicalKey(dosyaAdi) == cKey)) {
        bulunanBirim = b;
        break;
      }
    }

    // B) Mizan meta verisinden (Üst bilgi)
    if (bulunanBirim == null && meta.muhasebeBirimi != null) {
      final metaKey = BirimAdlandirma.canonicalKey(meta.muhasebeBirimi!);
      if (metaKey.isNotEmpty) {
        for (final b in aktifBirimler) {
          if (BirimAdlandirma.canonicalKey(b) == metaKey) {
            bulunanBirim = b;
            break;
          }
        }
      }
    }

    // C) Belge metninden birim adı veya birime özgü anahtar kelimeler
    if (bulunanBirim == null && metin.isNotEmpty) {
      final ilkKisim = metin.length > 3000 ? metin.substring(0, 3000) : metin;
      final cleanMetin = cleanStr(ilkKisim);

      for (final b in aktifBirimler) {
        final kisa = BirimAdlandirma.kisaAdGetir(b);
        final cleanKisa = cleanStr(kisa);
        if (cleanKisa.length >= 3 && cleanMetin.contains(cleanKisa)) {
          bulunanBirim = b;
          break;
        }
      }

      // D) Birime özgü faaliyet anahtar kelimeleri (kurs -> USEM, avans/harcırah -> DTS vb.)
      if (bulunanBirim == null) {
        if (cleanMetin.contains('kurs') ||
            cleanMetin.contains('kursiyer') ||
            cleanMetin.contains('kat hizmetleri') ||
            cleanMetin.contains('sigortacilik') ||
            cleanMetin.contains('sayar') ||
            cleanMetin.contains('surekli egitim')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'usem',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('deri') ||
            cleanMetin.contains('tekstil') ||
            cleanMetin.contains('seramik') ||
            cleanMetin.contains('avans kapatma') ||
            cleanMetin.contains('yolluk')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'dts',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('dis') ||
            cleanMetin.contains('metasoft') ||
            cleanMetin.contains('hekim') ||
            cleanMetin.contains('poliklinik') ||
            cleanMetin.contains('protez')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'dis',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('ubatam') ||
            cleanMetin.contains('bilimsel analiz') ||
            cleanMetin.contains('laboratuvar') ||
            cleanMetin.contains('numune')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'ubatam',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('tomer') ||
            cleanMetin.contains('turkce') ||
            cleanMetin.contains('dil ogretimi')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'tomer',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('tarim') ||
            cleanMetin.contains('ciftlik') ||
            cleanMetin.contains('fidan') ||
            cleanMetin.contains('tadaum')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'tadaum',
            orElse: () => '',
          );
        } else if (cleanMetin.contains('dosim') ||
            cleanMetin.contains('doner sermaye isletme')) {
          bulunanBirim = aktifBirimler.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'dosim',
            orElse: () => '',
          );
        }
        if (bulunanBirim != null && bulunanBirim.isEmpty) bulunanBirim = null;
      }
    }

    // 2. Slot Türü Tespiti:
    BirimBelgeSlotTuru slot = BirimBelgeSlotTuru.aylikMizan;

    // A) Ek Evrak / Fatura / Harcama / Kurs / Yolluk Tespiti
    final isEkEvrak = (cleanName.contains('fatura') ||
            cleanName.contains('tevkifat') ||
            cleanName.contains('earsiv') ||
            cleanName.contains('e-arsiv') ||
            cleanName.contains('efatura') ||
            cleanName.contains('avans') ||
            cleanName.contains('yolluk') ||
            cleanName.contains('harcirah') ||
            cleanName.contains('odeme') ||
            cleanName.contains('bordro') ||
            cleanName.contains('olur') ||
            cleanName.contains('yazi') ||
            cleanName.contains('metasoft') ||
            cleanName.contains('kurs') ||
            cleanName.contains('dekont')) &&
        !cleanName.contains('mizan');

    // B) Yardımcı Defter / Muavin Tespiti (Yazım hatalarına toleranslı: yadimci, deffter, muavin)
    final isYardimci = cleanName.contains('yardimci') ||
        cleanName.contains('yadimci') ||
        cleanName.contains('yardmci') ||
        cleanName.contains('muavin') ||
        cleanName.contains('alt_hesap') ||
        cleanName.contains('alt hesap') ||
        cleanName.contains('deffter') ||
        (cleanName.contains('defter') && !cleanName.contains('gecici') && !cleanName.contains('gecizi'));

    // C) Yıllık Kümülatif Mizan Tespiti (yillik, kumulatif, toplu)
    final isYillik = (cleanName.contains('yillik') ||
            cleanName.contains('kumulatif') ||
            cleanName.contains('toplu')) &&
        !isYardimci;

    // D) Aylık Mizan Tespiti (aylik, gecici, gecizi yazım hatası)
    final isAylik = cleanName.contains('aylik') ||
        cleanName.contains('gecici') ||
        cleanName.contains('gecizi');

    if (isEkEvrak) {
      slot = BirimBelgeSlotTuru.diger;
    } else if (isYardimci) {
      slot = BirimBelgeSlotTuru.yardimciMizan;
    } else if (isYillik) {
      slot = BirimBelgeSlotTuru.yillikMizan;
    } else if (isAylik) {
      slot = BirimBelgeSlotTuru.aylikMizan;
    } else {
      // Dosya adında net ipucu yoksa içerikten hesap kartları ve meta veriye bak
      final hesaplar = parseHesaplar(metin);
      if (hesaplar.isEmpty) {
        slot = BirimBelgeSlotTuru.diger;
      } else if (meta.isYillikKumulatif) {
        slot = BirimBelgeSlotTuru.yillikMizan;
      } else {
        slot = BirimBelgeSlotTuru.aylikMizan;
      }
    }

    return (birimAdi: bulunanBirim, slotTuru: slot);
  }

  /// Muhasebat Geçici Mizan metnindeki tüm hesap kartlarını haritalar.
  /// Üç farklı düzene toleranslıdır:
  /// 1. Excel tablosu (`|` ile ayrılmış satırlar: `ExcelUniversalParser` çıktısı)
  /// 2. Çok satırlı blok (Syncfusion PDF text extractor çıktısı: Kod -> Ad -> Borç -> Alacak -> BorçKalan -> AlacakKalan -> Kod)
  /// 3. Tek satırlı yatay tablo düzeni
  static Map<String, MizanHesapSatiri> parseHesaplar(String text) {
    final Map<String, MizanHesapSatiri> hesaplar = {};
    if (text.trim().isEmpty) return hesaplar;

    final allLines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lines = allLines.length > 6000 ? allLines.sublist(0, 6000) : allLines;

    // 1. DÜZEN: Excel (`|`) Ayracıyla Gelen Satırlar
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('|')) continue;
      final cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.length < 3) continue;

      // İlk veya ikinci hücrede hesap kodu ara (ayrı hücre veya "391.01.04 %10 HESAPLANAN KDV" birleşik hücre)
      String? code;
      String? name;
      int numStartIdx = -1;

      for (int c = 0; c < min(cells.length, 3); c++) {
        if (_hesapKoduRegex.hasMatch(cells[c])) {
          code = cells[c];
          if (c + 1 < cells.length && !_sayiRegex.hasMatch(cells[c + 1])) {
            name = cells[c + 1];
            numStartIdx = c + 2;
          } else {
            name = code;
            numStartIdx = c + 1;
          }
          break;
        }
        final combinedMatch = RegExp(r'^(\d{3}(?:\.\d{1,4})*)\s+(.+)$').firstMatch(cells[c]);
        if (combinedMatch != null && !_sayiRegex.hasMatch(combinedMatch.group(2)!.trim())) {
          code = combinedMatch.group(1)!;
          name = combinedMatch.group(2)!.trim();
          numStartIdx = c + 1;
          break;
        }
      }
      if (code == null || name == null || numStartIdx == -1 || numStartIdx >= cells.length) continue;

      final numCells = <double>[];
      for (int c = numStartIdx; c < cells.length; c++) {
        if (_sayiRegex.hasMatch(cells[c])) {
          numCells.add(TurkceFormat.parseSayi(cells[c]));
        }
      }
      if (numCells.length >= 2) {
        final borc = numCells[0];
        final alacak = numCells[1];
        final borcKalan = numCells.length >= 4 ? numCells[2] : max(0.0, borc - alacak);
        final alacakKalan = numCells.length >= 4 ? numCells[3] : max(0.0, alacak - borc);
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

    // 2. DÜZEN: Standart Muhasebat Çok Satırlı Blok Taraması (PDF)
    if (hesaplar.isEmpty) {
      for (int i = 0; i < lines.length - 5; i++) {
        final code1 = lines[i];
        if (!_hesapKoduRegex.hasMatch(code1)) continue;

        final name = lines[i + 1];
        final borcStr = lines[i + 2];
        final alacakStr = lines[i + 3];
        final borcKalanStr = lines[i + 4];
        final alacakKalanStr = lines[i + 5];

        String? closingCode;
        if (i + 6 < lines.length) {
          closingCode = lines[i + 6];
        }

        if (_sayiRegex.hasMatch(borcStr) &&
            _sayiRegex.hasMatch(alacakStr) &&
            _sayiRegex.hasMatch(borcKalanStr) &&
            _sayiRegex.hasMatch(alacakKalanStr)) {
          if (closingCode == code1 || _hesapKoduRegex.hasMatch(closingCode ?? '') || i + 6 >= lines.length) {
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
    }

    // 3. DÜZEN: Tek satırlı yatay satırlar (eğer çok satırlı blok bulunamadıysa)
    if (hesaplar.isEmpty) {
      final lineRegex = RegExp(
        r'^(\d{3}(?:\.\d{1,4})*)\s+(.+?)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)\s+(-?[\d\.,]+)$',
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

  /// Alt hesaplardan (%10 ve %20) KDV kırılımını çıkarır.
  static ({double kdv10, double kdv20}) _ayristirKdvOranlari(
    Map<String, MizanHesapSatiri> hesaplar,
    String anaKod, {
    required bool isAlacak,
  }) {
    double kdv10 = 0.0;
    double kdv20 = 0.0;

    // En alt (yaprak) alt hesapları bul
    final altKodlar = hesaplar.keys
        .where((k) => k.startsWith('$anaKod.') && k != anaKod)
        .toList();
    final yaprakKodlar = altKodlar
        .where((k) => !altKodlar.any((other) => other != k && other.startsWith('$k.')))
        .toList();

    for (final kod in yaprakKodlar) {
      final satir = hesaplar[kod]!;
      final tutar = isAlacak
          ? (satir.alacak > 0 ? satir.alacak : satir.alacakKalan)
          : (satir.borc > 0 ? satir.borc : satir.borcKalan);
      if (tutar <= 0) continue;

      final adUpper = satir.hesapAdi.toUpperCase();
      final sonParca = kod.split('.').last;

      // %10 KDV ipuçları: .04, .10, .08 veya hesap adında %10 / % 10 / %8
      if (sonParca == '04' ||
          sonParca == '10' ||
          sonParca == '08' ||
          adUpper.contains('%10') ||
          adUpper.contains('% 10') ||
          adUpper.contains('10 KDV') ||
          adUpper.contains('%8')) {
        kdv10 += tutar;
      } else if (sonParca == '05' ||
          sonParca == '20' ||
          sonParca == '18' ||
          adUpper.contains('%20') ||
          adUpper.contains('% 20') ||
          adUpper.contains('20 KDV') ||
          adUpper.contains('%18')) {
        kdv20 += tutar;
      }
    }

    return (
      kdv10: double.parse(kdv10.toStringAsFixed(2)),
      kdv20: double.parse(kdv20.toStringAsFixed(2)),
    );
  }

  /// Ek belge / fatura metninden GİB KDV 2 Tevkifat faturalarını kural tabanlı çıkarır.
  static List<Map<String, dynamic>> parseTevkifatFaturalari(String rawText) {
    if (rawText.trim().isEmpty) return [];
    final sonuclar = <Map<String, dynamic>>[];

    // Çoklu fatura varsa ETTN veya "e-Arşiv Fatura" / "e-Fatura" sınırlarından böl
    final parcalar = <String>[];
    final bolucuRegex = RegExp(
      r'(?=(?:e-ar[şs]iv\s*fatura|e-fatura|fatura\s*no\s*:))',
      caseSensitive: false,
    );
    final adayParcalar = rawText.split(bolucuRegex).where((p) => p.trim().length > 40).toList();
    if (adayParcalar.length > 1) {
      parcalar.addAll(adayParcalar);
    } else {
      parcalar.add(rawText);
    }

    for (final blok in parcalar) {
      final lines = blok
          .split(RegExp(r'\r?\n'))
          .map((l) => l.replaceAll('|', ' ').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      // 1. Satıcı VKN / TCKN Bul (Resmi GİB algoritmasıyla doğrulanmış, Alıcı/Üniversite hariç)
      String vkn = '';
      int vknLineIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // "SAYIN" / "ALICI" / "ÜNİVERSİTE" bloğuna ait VKN'yi atla
        final prevLine = i > 0 ? lines[i - 1].toUpperCase() : '';
        final prev2Line = i > 1 ? lines[i - 2].toUpperCase() : '';
        final isAliciBlogu = prevLine.contains('ÜNİVERSİTE') ||
            prev2Line.contains('ÜNİVERSİTE') ||
            prevLine.contains('UNIVERSITE') ||
            prev2Line.contains('UNIVERSITE') ||
            prevLine.contains('DÖNER SERMAYE') ||
            prev2Line.contains('DÖNER SERMAYE') ||
            prevLine.contains('SAYIN') ||
            prev2Line.contains('SAYIN') ||
            prevLine.contains('ALICI') ||
            line.toUpperCase().contains('ALICI');
        if (isAliciBlogu) continue;

        for (final m in RegExp(r'\b\d{10,11}\b').allMatches(line)) {
          final aday = m.group(0)!;
          if (aday.length == 10 && BeyannameDenetimServisi.dogrulaVkn(aday)) {
            vkn = aday;
            vknLineIndex = i;
            break;
          } else if (aday.length == 11 && BeyannameDenetimServisi.dogrulaTckn(aday)) {
            vkn = aday;
            vknLineIndex = i;
            break;
          }
        }
        if (vkn.isNotEmpty) break;
      }

      // 2. Satıcı (Düzenleyen) Firma / Şahıs Adını Tamamen Dinamik Bul (Üniversite / Alıcı hariç)
      String firmaAdi = '';
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final upper = line.toUpperCase();
        if (upper.contains('ÜNİVERSİTE') ||
            upper.contains('UNIVERSITE') ||
            upper.contains('DÖNER SERMAYE') ||
            upper.contains('DONER SERMAYE') ||
            upper.contains('FAKÜLTE') ||
            upper.contains('REKTÖRLÜK') ||
            upper.startsWith('ALICI') ||
            upper.startsWith('SAYIN')) {
          continue;
        }
        // a) Açık etiket varsa ("SATICI: ...", "UNVANI: ...")
        final etiketMatch = RegExp(
          r'^(?:sat[ıi]c[ıi]|d[üu]zenleyen|firma\s*unvan[ıi]?|unvan[ıi]?|ad[ıi]\s*soyad[ıi])\s*[:.\-]\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(line);
        if (etiketMatch != null && etiketMatch.group(1)!.trim().length > 3) {
          firmaAdi = etiketMatch.group(1)!.trim();
          break;
        }
        // b) Kurumsal şirket eki varsa (herhangi bir sektördeki tüm A.Ş., Ltd. Şti., Koop., Ortaklığı vb.)
        if (line.length > 5 &&
            (upper.contains('A.Ş') ||
                upper.contains('LTD') ||
                upper.contains('ŞTİ') ||
                upper.contains('LİMİTED') ||
                upper.contains('ANONİM') ||
                upper.contains('SAN.') ||
                upper.contains('SANAYİ') ||
                upper.contains('TİC.') ||
                upper.contains('TİCARET') ||
                upper.contains('KOOP') ||
                upper.contains('ORTAKLIĞI'))) {
          firmaAdi = line
              .replaceFirst(RegExp(r'^(?:sat[ıi]c[ıi]|firma|unvan[ıi]?)\s*[:.\-]?\s*', caseSensitive: false), '')
              .trim();
          break;
        }
      }
      // c) Şahıs firması veya şirket eki olmayan özel ünvan ise: Satıcı VKN satırının hemen üstündeki anlamlı satırı al
      if (firmaAdi.isEmpty && vknLineIndex > 0) {
        for (int j = vknLineIndex - 1; j >= max(0, vknLineIndex - 4); j--) {
          final adaySatir = lines[j].trim();
          final upper = adaySatir.toUpperCase();
          if (adaySatir.length > 4 &&
              !upper.contains('E-FATURA') &&
              !upper.contains('E-ARŞİV') &&
              !upper.contains('VERGİ DAİRESİ') &&
              !upper.contains('TEL:') &&
              !upper.contains('ADRES') &&
              !upper.contains('MAHALLESİ') &&
              !upper.contains('CADDESİ') &&
              !upper.contains('SOKAK') &&
              upper != 'SATICI' &&
              upper != 'SATICI:' &&
              !RegExp(r'^\d+$').hasMatch(adaySatir)) {
            firmaAdi = adaySatir;
            break;
          }
        }
      }

      // 3. Tevkifat Oranı Tespiti (9/10, 7/10, 5/10, 4/10, 3/10, 2/10)
      String tevkifatOrani = '9/10';
      double tevkifatKatsayi = 0.9;
      final oranMatch = RegExp(r'\b([234579])\s*/\s*10\b').firstMatch(blok);
      if (oranMatch != null) {
        final pay = int.parse(oranMatch.group(1)!);
        tevkifatOrani = '$pay/10';
        tevkifatKatsayi = pay / 10.0;
      } else {
        final yuzdeTevkifat = RegExp(
          r'tevkifat[^\n\r\d]*(?:%\s*)?(90|70|50|40|30|20)\b',
          caseSensitive: false,
        ).firstMatch(blok);
        if (yuzdeTevkifat != null) {
          final yuzde = int.parse(yuzdeTevkifat.group(1)!);
          final pay = yuzde ~/ 10;
          tevkifatOrani = '$pay/10';
          tevkifatKatsayi = pay / 10.0;
        }
      }

      // 4. Matrah, KDV ve Tevkifat Tutarı Tespiti
      final matrahMatch = RegExp(
        r'(?:mal\s*hizmet\s*toplam\s*tutar[ıi]?|vergi\s*matrah[ıi]|matrah(?:\s*tutar[ıi])?)\s*[:.\-]?\s*([\d.,]+)',
        caseSensitive: false,
      ).firstMatch(blok);
      final kdvMatch = RegExp(
        r'(?:hesaplanan\s*kdv|toplam\s*kdv|kdv\s*tutar[ıi])\s*(?:\(%\s*\d+\))?\s*[:.\-]?\s*([\d.,]+)',
        caseSensitive: false,
      ).firstMatch(blok);
      final tevkifatMatch = RegExp(
        r'(?:hesaplanan\s*kdv\s*tevkifat|tevkifat\s*tutar[ıi]|tevkif\s*edilen\s*kdv)\s*(?:\(\d+/10\))?\s*[:.\-]?\s*([\d.,]+)',
        caseSensitive: false,
      ).firstMatch(blok);

      double matrah = matrahMatch != null ? TurkceFormat.parseSayi(matrahMatch.group(1)) : 0.0;
      double kdv = kdvMatch != null ? TurkceFormat.parseSayi(kdvMatch.group(1)) : 0.0;
      double tevkifat = tevkifatMatch != null ? TurkceFormat.parseSayi(tevkifatMatch.group(1)) : 0.0;

      if (matrah > 0 && kdv == 0) {
        final kdvOranMatch = RegExp(r'kdv\s*(?:oran[ıi])?\s*%?\s*(10|20)\b', caseSensitive: false).firstMatch(blok);
        final oran = kdvOranMatch != null ? int.parse(kdvOranMatch.group(1)!) : 20;
        kdv = double.parse((matrah * (oran / 100.0)).toStringAsFixed(2));
      }
      if (kdv > 0 && tevkifat == 0) {
        tevkifat = double.parse((kdv * tevkifatKatsayi).toStringAsFixed(2));
      }
      if (matrah > 0 && kdv > 0 && tevkifat > 0 && oranMatch == null) {
        // KDV ve Tevkifat tutarından gerçek oranı otomatik bul (örn. 7/10, 5/10)
        final r = ((tevkifat / kdv) * 10).round();
        if (const [2, 3, 4, 5, 7, 9].contains(r)) {
          tevkifatOrani = '$r/10';
        }
      }

      if (matrah > 0 && (firmaAdi.isNotEmpty || vkn.isNotEmpty)) {
        sonuclar.add({
          'firmaAdi': firmaAdi.isNotEmpty ? firmaAdi : 'Düzenleyen Firma',
          'vergiTcNo': vkn,
          'matrahTutari': matrah,
          'kdvTutari': kdv,
          'tevkifatTutari': tevkifat,
          'tevkifatOrani': tevkifatOrani,
        });
      }
    }

    return sonuclar;
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
    var aylikHesaplar = parseHesaplar(aylikMizanMetni);
    var yillikHesaplar = parseHesaplar(yillikMizanMetni);
    final yardimciHesaplar = parseHesaplar(yardimciMizanMetni);

    // Akıllı Slot ve Konsolide Mizan Koruması:
    // 1) Eğer aylık mizan metninin 600 hasılatı birimin yıllık hasılatının 2.5 katından büyükse (örn. 11.8M vs 1.1M),
    //    bu dosya o birimin değil kurumun konsolide (tüm birimler) mizanıdır! Birimin kendi mizanını ezmemelidir.
    final aylikMeta = extractMetaVeri(aylikMizanMetni);
    final yillikMeta = extractMetaVeri(yillikMizanMetni);
    final bKey = BirimAdlandirma.canonicalKey(birimAdi);
    final isSaglikPosBirimi = bKey.contains('dis') || bKey.contains('hastane') || bKey.contains('saglik') || bKey.contains('tip');

    bool isAylikKonsolideMizan = false;
    if (aylikHesaplar.isNotEmpty && yillikHesaplar.isNotEmpty) {
      final hAylik600 = aylikHesaplar['600']?.alacak ?? 0.0;
      final hYillik600 = yillikHesaplar['600']?.alacak ?? 0.0;

      if (hAylik600 > 0 && hYillik600 > 0 && hAylik600 > hYillik600 * 2.5) {
        // Kurum Geneli Konsolide Mizan saptandı (DTS veya diğer birim klasörüne yanlışlıkla atılmış konsolide dosya)
        isAylikKonsolideMizan = true;
        if (!isSaglikPosBirimi) {
          // Sağlık harici birim ise konsolide mizan bu birimin aylık mizanı sayılamaz
          aylikHesaplar = {};
        }
      } else {
        final tersYuklenmis = (aylikMeta.isYillikKumulatif && !yillikMeta.isYillikKumulatif) ||
            (hAylik600 > 0 && hYillik600 > 0 && hAylik600 > hYillik600 * 1.05 && hAylik600 <= hYillik600 * 2.5);
        if (tersYuklenmis) {
          final tmp = aylikHesaplar;
          aylikHesaplar = yillikHesaplar;
          yillikHesaplar = tmp;
        }
      }
    } else if (aylikHesaplar.isNotEmpty && yillikHesaplar.isEmpty && aylikMeta.isYillikKumulatif && oncekiAylarHasilat > 0) {
      // Sadece yıllık mizan Aylık kutusuna yüklendiyse ve önceki aylar biliniyorsa
      yillikHesaplar = aylikHesaplar;
      aylikHesaplar = {};
    }

    final bool hasAylik = aylikHesaplar.isNotEmpty;
    final bool hasYillik = yillikHesaplar.isNotEmpty;
    final bool hasYardimci = yardimciHesaplar.isNotEmpty;

    // --- 1. 600 Hasılat & 123 POS Hesabı ---
    // Net Satışlar: 600 Yurtiçi Satışlar (Alacak) - 610 Satıştan İadeler (Borç) - 611 Satış İskontoları (Borç)
    double hesaplaNetHasilat(Map<String, MizanHesapSatiri> hesaplar) {
      if (!hesaplar.containsKey('600')) return 0.0;
      final h600 = hesaplar['600']!;
      final brut = h600.alacak > 0 ? h600.alacak : h600.alacakKalan;

      double iade = 0.0;
      if (hesaplar.containsKey('610')) {
        final h610 = hesaplar['610']!;
        iade += h610.borc > 0 ? h610.borc : h610.borcKalan;
      }
      if (hesaplar.containsKey('611')) {
        final h611 = hesaplar['611']!;
        iade += h611.borc > 0 ? h611.borc : h611.borcKalan;
      }

      final net = brut - iade;
      return double.parse((net > 0 ? net : 0.0).toStringAsFixed(2));
    }

    double hasilat600Aylik = 0.0;
    double hasilat600Kumulatif = 0.0;

    if (hasYillik && yillikHesaplar.containsKey('600')) {
      hasilat600Kumulatif = hesaplaNetHasilat(yillikHesaplar);
    }

    if (hasAylik && aylikHesaplar.containsKey('600')) {
      hasilat600Aylik = hesaplaNetHasilat(aylikHesaplar);
    } else if (hasilat600Kumulatif > 0) {
      if (oncekiAylarHasilat > 0 && hasilat600Kumulatif >= oncekiAylarHasilat) {
        hasilat600Aylik = double.parse((hasilat600Kumulatif - oncekiAylarHasilat).toStringAsFixed(2));
      } else {
        hasilat600Aylik = hasilat600Kumulatif;
      }
    }

    // Sadece aylık mizan yüklendiyse ve önceki aylar biliniyorsa kümülatifi otomatik tamamla
    if (hasilat600Kumulatif == 0.0 && hasilat600Aylik > 0) {
      hasilat600Kumulatif = double.parse((oncekiAylarHasilat + hasilat600Aylik).toStringAsFixed(2));
    }

    // 123 Kredi Kartı / POS:
    // Üniversite döner sermayesinde sadece hasta kabul / poliklinik yapan sağlık birimlerinde (Ağız ve Diş Sağlığı)
    // POS terminali tahsilatı bulunur. Tasarım, tarımsal, kurs vb. merkezlere konsolide mizandan POS sızması engellenir.
    // Kullanıcı kuralı: Diş Hekimliği kredi kartı tutarı için YILLIK MİZANDAKİ 123 Borç Kalan (bakiye) tutarına bakılır.
    double krediKarti123 = 0.0;
    if (isSaglikPosBirimi) {
      if (hasYillik && yillikHesaplar.containsKey('123') && yillikHesaplar['123']!.borcKalan > 0) {
        krediKarti123 = yillikHesaplar['123']!.borcKalan;
      } else if (hasAylik && aylikHesaplar.containsKey('123')) {
        final posBakiye = aylikHesaplar['123']!.borcKalan;
        krediKarti123 = posBakiye > 0 ? posBakiye : aylikHesaplar['123']!.borc;
      } else if (hasYillik && yillikHesaplar.containsKey('123')) {
        krediKarti123 = yillikHesaplar['123']!.borcKalan;
      }
    }

    // --- 2. 391 Hesaplanan KDV (%10 ve %20) ---
    final aktifHesaplar = hasAylik ? aylikHesaplar : yillikHesaplar;

    var kdv391Kirilim = _ayristirKdvOranlari(aktifHesaplar, '391', isAlacak: true);
    if (kdv391Kirilim.kdv10 == 0.0 && kdv391Kirilim.kdv20 == 0.0 && hasYardimci) {
      kdv391Kirilim = _ayristirKdvOranlari(yardimciHesaplar, '391', isAlacak: true);
    }

    double kdv10 = kdv391Kirilim.kdv10;
    double kdv20 = kdv391Kirilim.kdv20;

    // Alt hesap kırılımı yoksa ve ana 391 hesabı varsa:
    if (kdv10 == 0.0 && kdv20 == 0.0 && aktifHesaplar.containsKey('391')) {
      final ana391 = aktifHesaplar['391']!.alacak > 0
          ? aktifHesaplar['391']!.alacak
          : aktifHesaplar['391']!.alacakKalan;
      if (ana391 > 0) {
        final bKey = BirimAdlandirma.canonicalKey(birimAdi);
        final isEgitimBirimi = bKey.contains('tomer') || bKey.contains('usem');
        final isOran10Uyumlu = hasilat600Aylik > 0 && (ana391 - hasilat600Aylik * 0.10).abs() <= 1.0;

        if (isOran10Uyumlu || (isEgitimBirimi && (hasilat600Aylik == 0 || (ana391 - hasilat600Aylik * 0.20).abs() > 1.0))) {
          kdv10 = ana391;
        } else {
          kdv20 = ana391;
        }
      }
    }

    double matrah10 = kdv10 > 0 ? double.parse((kdv10 / 0.10).toStringAsFixed(2)) : 0.0;
    double matrah20 = kdv20 > 0 ? double.parse((kdv20 / 0.20).toStringAsFixed(2)) : 0.0;

    // Kuruş Yuvarlama Senkronizasyonu: Matrah ile 600 Hasılat arasındaki fark <= 0,50 TL ise 600 Hasılat'a eşitle
    if (hasilat600Aylik > 0) {
      if (matrah20 > 0 && matrah10 == 0 && (matrah20 - hasilat600Aylik).abs() <= 0.50) {
        matrah20 = hasilat600Aylik;
      } else if (matrah10 > 0 && matrah20 == 0 && (matrah10 - hasilat600Aylik).abs() <= 0.50) {
        matrah10 = hasilat600Aylik;
      }
    }

    // Yıllık kümülatif mizan kullanılıyorsa ve aylık net hasılat biliniyorsa:
    // Kümülatif mizan KDV'sinin aylık beyannameye sızmasını engelle (DTS & TADAUM koruması)
    final bool isYillikMizandanOkundu = !hasAylik || isAylikKonsolideMizan;
    if (isYillikMizandanOkundu) {
      if (hasilat600Aylik == 0.0) {
        // Bu ay hiç hasılat yoksa (TADAUM gibi), yıllık kümülatif mizan KDV'si bu aya yazılamaz
        kdv10 = 0.0;
        kdv20 = 0.0;
        matrah10 = 0.0;
        matrah20 = 0.0;
      } else {
        // Bu ayın hasılatı kümülatiften küçükse (DTS: 50.000 TL aylık vs 1.14M TL kümülatif):
        // KDV tutarı kümülatif kalamaz, net aylık hasılata göre normalize edilir
        if (kdv20 > 0 && (kdv20 > hasilat600Aylik || matrah20 > hasilat600Aylik * 1.5)) {
          kdv20 = double.parse((hasilat600Aylik * 0.20).toStringAsFixed(2));
          matrah20 = hasilat600Aylik;
        }
        if (kdv10 > 0 && (kdv10 > hasilat600Aylik || matrah10 > hasilat600Aylik * 1.5)) {
          kdv10 = double.parse((hasilat600Aylik * 0.10).toStringAsFixed(2));
          matrah10 = hasilat600Aylik;
        }
      }
    }

    // --- 3. 191 İndirilecek KDV (%10 ve %20) ---
    var kdv191Kirilim = _ayristirKdvOranlari(aktifHesaplar, '191', isAlacak: false);
    if (kdv191Kirilim.kdv10 == 0.0 && kdv191Kirilim.kdv20 == 0.0 && hasYardimci) {
      kdv191Kirilim = _ayristirKdvOranlari(yardimciHesaplar, '191', isAlacak: false);
    }

    double ind10 = kdv191Kirilim.kdv10;
    double ind20 = kdv191Kirilim.kdv20;

    if (ind10 == 0.0 && ind20 == 0.0 && aktifHesaplar.containsKey('191')) {
      ind20 = aktifHesaplar['191']!.borc > 0
          ? aktifHesaplar['191']!.borc
          : aktifHesaplar['191']!.borcKalan;
    }

    if (isYillikMizandanOkundu) {
      // Yıllık kümülatif 191 tutarı tek bir aya indirilecek KDV olarak yazılamaz
      ind10 = 0.0;
      ind20 = 0.0;
    }

    final double indMatrah10 = ind10 > 0 ? double.parse((ind10 / 0.10).toStringAsFixed(2)) : 0.0;
    final double indMatrah20 = ind20 > 0 ? double.parse((ind20 / 0.20).toStringAsFixed(2)) : 0.0;

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
    } else if (hasAylik && aylikHesaplar.containsKey('360.03')) {
      final ana36003 = aylikHesaplar['360.03']!.alacak > 0
          ? aylikHesaplar['360.03']!.alacak
          : aylikHesaplar['360.03']!.alacakKalan;
      final ucretDamga = aylikHesaplar['360.03.01']?.alacak ?? 0.0;
      if (ana36003 > ucretDamga) {
        damga360 = double.parse((ana36003 - ucretDamga).toStringAsFixed(2));
      }
    } else if (hasYillik && yillikHesaplar.containsKey('360.03')) {
      final ana36003 = yillikHesaplar['360.03']!.alacakKalan;
      final ucretDamga = yillikHesaplar['360.03.01']?.alacakKalan ?? 0.0;
      if (ana36003 > ucretDamga) {
        damga360 = double.parse((ana36003 - ucretDamga).toStringAsFixed(2));
      }
    }
    final damgaMatrah = damga360 > 0 ? double.parse((damga360 / 0.00948).toStringAsFixed(2)) : 0.0;

    // --- 6. 360 Muhtasar (Gelir Vergisi 360.01.01 & Damga Vergisi 360.03.01) ---
    double muhtasarGelir360 = 0.0;
    double muhtasarDamga360 = 0.0;

    if (aktifHesaplar.containsKey('360.01.01')) {
      muhtasarGelir360 = aktifHesaplar['360.01.01']!.alacak;
    }
    if (aktifHesaplar.containsKey('360.03.01')) {
      muhtasarDamga360 = aktifHesaplar['360.03.01']!.alacak;
    }

    // --- 7. Ters Bakiye Denetimleri ---
    final is191TersBakiye = (aktifHesaplar['191']?.alacakKalan ?? 0.0) > 0.01;
    final is391TersBakiye = (aktifHesaplar['391']?.borcKalan ?? 0.0) > 0.01;
    final is600TersBakiye = (aktifHesaplar['600']?.borcKalan ?? 0.0) > 0.01;

    // --- 8. Yardımcı Mizan Bilgileri ---
    double yardimci391 = 0.0;
    double yardimci191 = 0.0;
    double yardimci600 = 0.0;

    if (hasYardimci) {
      yardimci391 = yardimciHesaplar['391']?.alacak ?? (kdv391Kirilim.kdv10 + kdv391Kirilim.kdv20);
      yardimci191 = yardimciHesaplar['191']?.borc ?? (kdv191Kirilim.kdv10 + kdv191Kirilim.kdv20);
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
      'is600TersBakiye': is600TersBakiye,
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

