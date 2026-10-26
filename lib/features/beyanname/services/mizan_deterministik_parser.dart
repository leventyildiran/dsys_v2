import 'dart:math';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_belge_model.dart';
import 'beyanname_denetim_servisi.dart';
import 'mizan_360_capraz_cozumleyici.dart';

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

  /// Alt hesaplardan (%1, %10 ve %20) KDV kırılımını çıkarır.
  static ({double kdv1, double kdv10, double kdv20}) _ayristirKdvOranlari(
    Map<String, MizanHesapSatiri> hesaplar,
    String anaKod, {
    required bool isAlacak,
  }) {
    double kdv1 = 0.0;
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
      // %1 KDV ipuçları: .01, .1 veya hesap adında %1 / % 1 / 1 KDV (ancak %10 ve %18 hariç)
      else if (sonParca == '01' ||
          sonParca == '1' ||
          ((adUpper.contains('%1') || adUpper.contains('% 1')) &&
              !adUpper.contains('%10') &&
              !adUpper.contains('%18')) ||
          adUpper.contains('1 KDV')) {
        kdv1 += tutar;
      }
    }

    return (
      kdv1: double.parse(kdv1.toStringAsFixed(2)),
      kdv10: double.parse(kdv10.toStringAsFixed(2)),
      kdv20: double.parse(kdv20.toStringAsFixed(2)),
    );
  }

  static bool _isAliciSatiri(String line) {
    final u = line.toUpperCase();
    return u.contains('ÜNİVERSİTE') ||
        u.contains('UNIVERSITE') ||
        u.contains('DÖNER SERMAYE') ||
        u.contains('DONER SERMAYE') ||
        u.contains('FAKÜLTE') ||
        u.contains('REKTÖRLÜK') ||
        u.startsWith('ALICI') ||
        u.startsWith('SAYIN');
  }

  /// Tek bir fatura metin bloğundan satıcı, vergi no, matrah ve tevkifatı çıkarır.
  static Map<String, dynamic>? _parseTekilTevkifatBlok(String blok) {
    final lines = blok
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll('|', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    // 1. Satıcı VKN / TCKN Bul (Resmi GİB algoritmasıyla doğrulanmış, Alıcı/Üniversite hariç)
    String vkn = '';
    int vknLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
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

    // 1b. Eğer algoritma ile eşleşmediyse ama satırda açık VKN / TCKN etiketi varsa
    if (vkn.isEmpty) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final prevLine = i > 0 ? lines[i - 1].toUpperCase() : '';
        final isAlici = prevLine.contains('ALICI') ||
            prevLine.contains('SAYIN') ||
            line.toUpperCase().contains('ALICI') ||
            _isAliciSatiri(line);
        if (isAlici) continue;

        final vknEtiket = RegExp(
          r'(?:vergi\s*(?:kimlik\s*)?no|vkn|tckn)\s*[:.\-]?\s*(\d{10,11})\b',
          caseSensitive: false,
        ).firstMatch(line);
        if (vknEtiket != null) {
          vkn = vknEtiket.group(1)!;
          vknLineIndex = i;
          break;
        }
      }
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
      // b) Kurumsal şirket eki varsa (herhangi bir sektördeki tüm A.Ş., Ltd. Şti., Koop., Ortaklığı, Medikal vb.)
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
              upper.contains('MEDİKAL') ||
              upper.contains('DENTAL') ||
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

    // 3. Fatura No ve Tarih tespiti
    String faturaNo = '';
    final fNoMatch = RegExp(
      r'(?:fatura\s*(?:no|numaras[ıi]|s[ıi]ra\s*no)\s*[:.\-]?\s*|ettn\s*[:.\-]?\s*)([A-Z0-9\-]{8,36})',
      caseSensitive: false,
    ).firstMatch(blok);
    if (fNoMatch != null) {
      faturaNo = fNoMatch.group(1)!.trim();
    } else {
      final gibMatch = RegExp(r'\b([A-Z]{3}\d{13})\b').firstMatch(blok);
      if (gibMatch != null) {
        faturaNo = gibMatch.group(1)!;
      }
    }

    String faturaTarihi = '';
    final tarihMatch = RegExp(
      r'(?:fatura\s*tarihi?|d[üu]zenleme\s*tarihi?|tarih)\s*[:.\-]?\s*(\d{1,2}[./]\d{1,2}[./]\d{2,4})',
      caseSensitive: false,
    ).firstMatch(blok);
    if (tarihMatch != null) {
      faturaTarihi = tarihMatch.group(1)!;
    }

    // 4. Çoklu Tevkifat Oranı Kırılımı Kontrolü (Aynı faturada 3 farklı tevkifat oranı / KDV oranı varsa)
    if (firmaAdi.isNotEmpty || vkn.isNotEmpty) {
      final cokluKirilimlar = _ayristirFaturaIciCokluTevkifatSatirlari(
        blok,
        lines: lines,
        firmaAdi: firmaAdi.isNotEmpty ? firmaAdi : 'Düzenleyen Firma',
        vkn: vkn,
        faturaNo: faturaNo,
        faturaTarihi: faturaTarihi,
      );
      if (cokluKirilimlar.length > 1) {
        return {
          ...cokluKirilimlar.first,
          '_altTevkifatKirilimlari': cokluKirilimlar,
        };
      } else if (cokluKirilimlar.length == 1) {
        return cokluKirilimlar.first;
      }
    }

    // 5. Tekil Tevkifat Oranı Tespiti (10/10, 9/10, 7/10, 5/10, 4/10, 3/10, 2/10)
    String tevkifatOrani = '9/10';
    double tevkifatKatsayi = 0.9;
    final oranMatch = RegExp(r'\b(10|[234579])\s*/\s*10\b').firstMatch(blok);
    if (oranMatch != null) {
      final pay = int.parse(oranMatch.group(1)!);
      tevkifatOrani = '$pay/10';
      tevkifatKatsayi = pay / 10.0;
    } else {
      final yuzdeTevkifat = RegExp(
        r'tevkifat[^\n\r\d]*(?:%\s*)?(100|90|70|50|40|30|20)\b',
        caseSensitive: false,
      ).firstMatch(blok);
      if (yuzdeTevkifat != null) {
        final yuzde = int.parse(yuzdeTevkifat.group(1)!);
        final pay = yuzde ~/ 10;
        tevkifatOrani = '$pay/10';
        tevkifatKatsayi = pay / 10.0;
      }
    }

    // 6. Açık KDV Oranı (%10, %20, %1, %8) Tespiti
    int? acikKdvOrani;
    final kdvEtiketOranMatch = RegExp(
      r'(?:hesaplanan\s*kdv|toplam\s*kdv|kdv\s*(?:oran[ıi]|tutar[ıi])?)\s*\(?%?\s*(1|8|10|18|20)\)?\b',
      caseSensitive: false,
    ).firstMatch(blok);
    if (kdvEtiketOranMatch != null) {
      acikKdvOrani = int.tryParse(kdvEtiketOranMatch.group(1)!);
    } else {
      final genelYuzdeMatch = RegExp(r'%\s*(10|20|1|8|18)\b').firstMatch(blok);
      if (genelYuzdeMatch != null) {
        acikKdvOrani = int.tryParse(genelYuzdeMatch.group(1)!);
      }
    }

    // 7. Matrah, KDV ve Tevkifat Tutarı Tespiti
    final matrahMatch = RegExp(
      r'(?:mal\s*hizmet\s*toplam\s*tutar[ıi]?|vergi\s*matrah[ıi]|matrah(?:\s*tutar[ıi])?)\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(blok);
    final kdvMatch = RegExp(
      r'(?:hesaplanan\s*kdv|toplam\s*kdv|kdv\s*tutar[ıi])\s*(?:\(%\s*\d+\))?\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(blok);
    final tevkifatMatch = RegExp(
      r'(?:hesaplanan\s*kdv\s*tevkifat|tevkifat\s*tutar[ıi]|tevkif\s*edilen\s*kdv|kdv\s*tevkifat)\s*(?:\(\d+/10\))?\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(blok);

    double matrah = matrahMatch != null ? TurkceFormat.parseSayi(matrahMatch.group(1)) : 0.0;
    double kdv = kdvMatch != null ? TurkceFormat.parseSayi(kdvMatch.group(1)) : 0.0;
    double tevkifat = tevkifatMatch != null ? TurkceFormat.parseSayi(tevkifatMatch.group(1)) : 0.0;

    if (matrah == 0) {
      final araToplamMatch = RegExp(
        r'(?:ara\s*toplam|toplam\s*tutar)\s*[:.\-]?\s*([\d.,]+)',
        caseSensitive: false,
      ).firstMatch(blok);
      if (araToplamMatch != null) {
        matrah = TurkceFormat.parseSayi(araToplamMatch.group(1));
      }
    }

    if (matrah > 0 && kdv == 0) {
      final oran = acikKdvOrani ?? 20;
      kdv = double.parse((matrah * (oran / 100.0)).toStringAsFixed(2));
    }
    if (kdv > 0 && tevkifat == 0) {
      tevkifat = double.parse((kdv * tevkifatKatsayi).toStringAsFixed(2));
    }
    if (matrah > 0 && kdv > 0 && tevkifat > 0 && oranMatch == null) {
      final r = ((tevkifat / kdv) * 10).round();
      if (const [2, 3, 4, 5, 7, 9, 10].contains(r)) {
        tevkifatOrani = '$r/10';
      }
    }

    final int kdvOrani = BirimMizanAnalizSonucu.cozumleKdvOrani(
      hamKdvOrani: acikKdvOrani,
      matrah: matrah,
      kdv: kdv,
    );

    if (matrah > 0 && (firmaAdi.isNotEmpty || vkn.isNotEmpty)) {
      return {
        'firmaAdi': firmaAdi.isNotEmpty ? firmaAdi : 'Düzenleyen Firma',
        'vergiTcNo': vkn,
        'faturaNo': faturaNo,
        'faturaTarihi': faturaTarihi,
        'matrahTutari': matrah,
        'kdvOrani': kdvOrani,
        'kdvTutari': kdv,
        'tevkifatTutari': tevkifat,
        'tevkifatOrani': tevkifatOrani,
      };
    }
    return null;
  }

  /// Tek bir fatura içinde birden fazla tevkifat oranı (örn: 9/10, 7/10, 5/10) veya
  /// farklı KDV oranları (%10, %20) satırları bulunduğunda her bir kırılımı ayrı ayrı çıkarır.
  static List<Map<String, dynamic>> _ayristirFaturaIciCokluTevkifatSatirlari(
    String blok, {
    required List<String> lines,
    required String firmaAdi,
    required String vkn,
    required String faturaNo,
    required String faturaTarihi,
  }) {
    final bulunanSatirlar = <Map<String, dynamic>>[];

    // Yöntem A: Satır bazlı tablo veya özet kırılımları (satırda "X/10" ve en az 2 para tutarı geçen satırlar)
    final oranSatirRegex = RegExp(r'\b(10|[234579])\s*/\s*10\b');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final oMatch = oranSatirRegex.firstMatch(line);
      if (oMatch == null) continue;

      final pay = int.parse(oMatch.group(1)!);
      final oranStr = '$pay/10';
      final katsayi = pay / 10.0;

      // Oran ifadesini ve KDV yüzdesini temizleyip kalan gerçek para tutarlarını çıkar
      int? satirKdvOrani;
      final kdvYuzdeM = RegExp(r'%\s*(10|20|1|8|18)\b|\b(10|20)\s*%').firstMatch(line);
      if (kdvYuzdeM != null) {
        satirKdvOrani = int.tryParse(kdvYuzdeM.group(1) ?? kdvYuzdeM.group(2) ?? '');
      }

      var temizSatir = line.replaceAll(oranSatirRegex, ' ');
      temizSatir = temizSatir.replaceAll(RegExp(r'%\s*\d+|\d+\s*%'), ' ');
      // Tarih ve VKN/FaturaNo ifadelerini temizle
      temizSatir = temizSatir.replaceAll(RegExp(r'\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\b'), ' ');
      temizSatir = temizSatir.replaceAll(RegExp(r'\b[A-Z]{3}\d{13}\b'), ' ');
      temizSatir = temizSatir.replaceAll(RegExp(r'\b\d{10,11}\b'), ' ');

      final adaySayilar = <double>[];
      for (final m in RegExp(r'\b\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?\b|\b\d+(?:[.,]\d{2})\b').allMatches(temizSatir)) {
        final s = TurkceFormat.parseSayi(m.group(0));
        if (s > 1.0) adaySayilar.add(s);
      }

      if (adaySayilar.length >= 2) {
        // Aday sayılar içinde (matrah, kdv, tevkifat) üçlüsünü veya ikilisini bul
        double? bulunanMatrah;
        double? bulunanKdv;
        double? bulunanTevkifat;
        int bulunanOran = satirKdvOrani ?? 20;

        for (final mAday in adaySayilar) {
          for (final testKdvOrani in (satirKdvOrani != null ? [satirKdvOrani] : const [20, 10, 1, 8, 18])) {
            final beklenenKdv = mAday * (testKdvOrani / 100.0);
            final beklenenTvk = beklenenKdv * katsayi;
            final kdvVar = adaySayilar.any((x) => (x - mAday).abs() > 0.01 && (x - beklenenKdv).abs() <= max(1.5, beklenenKdv * 0.02));
            final tvkVar = adaySayilar.any((x) => (x - mAday).abs() > 0.01 && (x - beklenenTvk).abs() <= max(1.5, beklenenTvk * 0.02));
            if (kdvVar || tvkVar) {
              bulunanMatrah = mAday;
              bulunanOran = testKdvOrani;
              final gercekKdv = adaySayilar.where((x) => (x - beklenenKdv).abs() <= max(1.5, beklenenKdv * 0.02)).firstOrNull;
              final gercekTvk = adaySayilar.where((x) => (x - beklenenTvk).abs() <= max(1.5, beklenenTvk * 0.02)).firstOrNull;
              bulunanKdv = gercekKdv ?? double.parse(beklenenKdv.toStringAsFixed(2));
              bulunanTevkifat = gercekTvk ?? double.parse((bulunanKdv * katsayi).toStringAsFixed(2));
              break;
            }
          }
          if (bulunanMatrah != null) break;
        }

        if (bulunanMatrah != null && bulunanMatrah > 0) {
          final yeniMap = <String, dynamic>{
            'firmaAdi': firmaAdi,
            'vergiTcNo': vkn,
            'faturaNo': faturaNo,
            'faturaTarihi': faturaTarihi,
            'matrahTutari': bulunanMatrah,
            'kdvOrani': bulunanOran,
            'kdvTutari': bulunanKdv!,
            'tevkifatTutari': bulunanTevkifat!,
            'tevkifatOrani': oranStr,
          };
          final mukerrer = bulunanSatirlar.any((m) => BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(m, yeniMap));
          if (!mukerrer) {
            bulunanSatirlar.add(yeniMap);
          }
        }
      }
    }

    if (bulunanSatirlar.length > 1) {
      return bulunanSatirlar;
    }

    // Yöntem B: Alt alta yazılmış çoklu etiketli bloklar
    // Örn: Matrah: 50.000,00 / Hesaplanan KDV (%10): 5.000,00 / Tevkifat (9/10): 4.500,00
    //      Matrah: 30.000,00 / Hesaplanan KDV (%20): 6.000,00 / Tevkifat (7/10): 4.200,00
    final tumMatrahlar = RegExp(
      r'(?:mal\s*hizmet\s*toplam\s*tutar[ıi]?|vergi\s*matrah[ıi]|matrah(?:\s*tutar[ıi])?)\s*(?:\(%\s*(1|8|10|18|20)\))?\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).allMatches(blok).toList();
    final tumKdvler = RegExp(
      r'(?:hesaplanan\s*kdv|toplam\s*kdv|kdv\s*tutar[ıi])\s*(?:\(%\s*(1|8|10|18|20)\))?\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).allMatches(blok).toList();
    final tumTevkifatlar = RegExp(
      r'(?:hesaplanan\s*kdv\s*tevkifat|tevkifat\s*tutar[ıi]|tevkif\s*edilen\s*kdv|kdv\s*tevkifat)\s*(?:\(\s*(10|[234579])\s*/\s*10\s*\))?\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).allMatches(blok).toList();

    if (tumTevkifatlar.length > 1 && tumMatrahlar.length >= tumTevkifatlar.length) {
      final etiketliSatirlar = <Map<String, dynamic>>[];
      for (int idx = 0; idx < tumTevkifatlar.length; idx++) {
        final mMatch = tumMatrahlar[idx];
        final kMatch = idx < tumKdvler.length ? tumKdvler[idx] : null;
        final tMatch = tumTevkifatlar[idx];

        final mtr = TurkceFormat.parseSayi(mMatch.group(2));
        if (mtr <= 0) continue;

        final tvk = TurkceFormat.parseSayi(tMatch.group(2));
        final acikPay = tMatch.group(1);
        final acikKdvOranStr = kMatch?.group(1) ?? mMatch.group(1);
        double kdv = kMatch != null ? TurkceFormat.parseSayi(kMatch.group(2)) : 0.0;

        final kdvOran = BirimMizanAnalizSonucu.cozumleKdvOrani(
          hamKdvOrani: acikKdvOranStr,
          matrah: mtr,
          kdv: kdv,
        );
        if (kdv <= 0) {
          kdv = double.parse((mtr * (kdvOran / 100.0)).toStringAsFixed(2));
        }

        String oranStr = acikPay != null ? '$acikPay/10' : '9/10';
        if (acikPay == null && kdv > 0 && tvk > 0) {
          final r = ((tvk / kdv) * 10).round();
          if (const [2, 3, 4, 5, 7, 9, 10].contains(r)) {
            oranStr = '$r/10';
          }
        }

        final yeniMap = <String, dynamic>{
          'firmaAdi': firmaAdi,
          'vergiTcNo': vkn,
          'faturaNo': faturaNo,
          'faturaTarihi': faturaTarihi,
          'matrahTutari': mtr,
          'kdvOrani': kdvOran,
          'kdvTutari': kdv,
          'tevkifatTutari': tvk,
          'tevkifatOrani': oranStr,
        };
        final mukerrer = etiketliSatirlar.any((m) => BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(m, yeniMap));
        if (!mukerrer) {
          etiketliSatirlar.add(yeniMap);
        }
      }
      if (etiketliSatirlar.length > 1) {
        return etiketliSatirlar;
      }
    }

    return const [];
  }

  /// Ek belge metninden İhaleye Ait Damga Vergisi (Karar Pulu Binde 5,69 & Sözleşme Damga Binde 9,48) tutarlarını çıkarır.
  static ({double ihaleKararPulu, double ihaleSozlesme}) parseIhaleDamgaBelgesi(String rawText) {
    if (rawText.trim().isEmpty) {
      return (ihaleKararPulu: 0.0, ihaleSozlesme: 0.0);
    }
    double kararPulu = 0.0;
    double sozlesmeDamga = 0.0;

    final lines = rawText.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.replaceAll('|', ' ').trim();
      if (line.isEmpty) continue;
      final u = line.toUpperCase();

      // 360.03.02 / 360.03.03 mizan satırlarını zaten mizan parser okur; burada ek belge / makbuz / yazı satırlarını yakala
      if (RegExp(r'^\d{3}\.').hasMatch(line)) continue;

      final isKararPulu = u.contains('KARAR PULU') ||
          u.contains('İHALE KARAR') ||
          u.contains('IHALE KARAR') ||
          u.contains('5,69') ||
          u.contains('5.69');
      final isSozlesme = u.contains('SÖZLEŞME DAMGA') ||
          u.contains('SOZLESME DAMGA') ||
          u.contains('SÖZLEŞMEYE DAİR') ||
          u.contains('SOZLESMEYE DAIR') ||
          u.contains('İHALE SÖZLEŞME') ||
          u.contains('IHALE SOZLESME') ||
          (u.contains('İHALE') && u.contains('DAMGA') && !isKararPulu);

      if (!isKararPulu && !isSozlesme) continue;

      // Satırdaki para tutarlarını bul (oran rakamları 5,69 ve 9,48 hariç)
      final temiz = line
          .replaceAll(RegExp(r'0[.,]00569|5[.,]69|0[.,]00948|9[.,]48'), ' ')
          .replaceAll(RegExp(r'\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\b'), ' ')
          .replaceAll(RegExp(r'\b\d{10,11}\b'), ' ');

      final sayilar = <double>[];
      for (final m in RegExp(r'\b\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?\b|\b\d+(?:[.,]\d{2})\b').allMatches(temiz)) {
        final val = TurkceFormat.parseSayi(m.group(0));
        if (val > 1.0) sayilar.add(val);
      }
      if (sayilar.isEmpty) continue;

      // Eğer satırda hem ihale bedeli (matrah) hem damga vergisi varsa küçük olan vergi tutarıdır
      double secilenVergi = sayilar.last;
      if (sayilar.length >= 2) {
        final enBuyuk = sayilar.reduce(max);
        final enKucuk = sayilar.reduce(min);
        if (enKucuk < enBuyuk * 0.05) {
          secilenVergi = enKucuk;
        }
      }

      if (isKararPulu && secilenVergi > 0) {
        kararPulu += secilenVergi;
      } else if (isSozlesme && secilenVergi > 0) {
        sozlesmeDamga += secilenVergi;
      }
    }

    return (
      ihaleKararPulu: double.parse(kararPulu.toStringAsFixed(2)),
      ihaleSozlesme: double.parse(sozlesmeDamga.toStringAsFixed(2)),
    );
  }

  /// Ek belge / fatura metninden GİB KDV 2 Tevkifat faturalarını kural tabanlı çıkarır.
  /// Arka arkaya taranmış çok sayfalı veya tek faturada 3 farklı tevkifat oranı içeren faturaların TÜMÜNÜ eksiksiz yakalar.
  static List<Map<String, dynamic>> parseTevkifatFaturalari(String rawText) {
    if (rawText.trim().isEmpty) return [];
    final sonuclar = <Map<String, dynamic>>[];

    // 1. Çoklu fatura varsa form feed (\f), sayfa çizgisi veya fatura başlığı sınırlarından akıllıca böl
    final bolucuRegex = RegExp(
      r'(?=(?:\f|\x0C|---\s*SAYFA\s*\d+\s*---|===\s*SAYFA\s*\d+\s*===|(?:e-ar[şs]iv(?:\s*fatura)?|e-fatura|ettn\s*[:.\-]?|özelle[şs]tirme\s*no|(?:temel|ticari|kamu|istisna|tevkifat)\s*fatura)\b))',
      caseSensitive: false,
    );
    final adayParcalar = rawText.split(bolucuRegex).where((p) => p.trim().length > 40).toList();
    final parcalar = <String>[];
    if (adayParcalar.length > 1) {
      parcalar.addAll(adayParcalar);
    } else {
      parcalar.add(rawText);
    }

    // 2. Parça içinde birden çok satıcı VKN varsa alt bloklara ayır
    final nihaiBloklar = <String>[];
    for (final p in parcalar) {
      final lines = p.split('\n');
      final vknPozisyonlari = <int>[];
      final gorulenVknler = <String>{};
      int charOffset = 0;
      for (final line in lines) {
        if (!_isAliciSatiri(line)) {
          for (final m in RegExp(r'\b\d{10,11}\b').allMatches(line)) {
            final val = m.group(0)!;
            final gecerli = (val.length == 10 && BeyannameDenetimServisi.dogrulaVkn(val)) ||
                (val.length == 11 && BeyannameDenetimServisi.dogrulaTckn(val)) ||
                RegExp(r'(?:vergi\s*(?:kimlik\s*)?no|vkn|tckn)\s*[:.\-]?\s*\d{10,11}\b', caseSensitive: false).hasMatch(line);
            if (gecerli && !gorulenVknler.contains(val)) {
              gorulenVknler.add(val);
              vknPozisyonlari.add(charOffset);
              break;
            }
          }
        }
        charOffset += line.length + 1;
      }

      if (vknPozisyonlari.length > 1) {
        for (int i = 0; i < vknPozisyonlari.length; i++) {
          final bas = max(0, vknPozisyonlari[i] - 120);
          final bit = (i + 1 < vknPozisyonlari.length)
              ? max(bas + 40, vknPozisyonlari[i + 1] - 120)
              : p.length;
          if (bit > bas) {
            nihaiBloklar.add(p.substring(bas, bit));
          }
        }
      } else {
        nihaiBloklar.add(p);
      }
    }

    // 3. Her bloğu tek tek ayrıştır (aynı faturadaki çoklu tevkifat oranları dahil) ve mükerrer olmayanları ekle
    for (final blok in nihaiBloklar) {
      final f = _parseTekilTevkifatBlok(blok);
      if (f != null) {
        final altKirilimlar = f['_altTevkifatKirilimlari'] as List<Map<String, dynamic>>?;
        final eklenecekListe = altKirilimlar ?? [f];
        for (final item in eklenecekListe) {
          final temizItem = Map<String, dynamic>.from(item)..remove('_altTevkifatKirilimlari');
          final mukerrer = sonuclar.any(
            (mevcut) => BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(mevcut, temizItem),
          );
          if (!mukerrer) {
            sonuclar.add(temizItem);
          }
        }
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
    double ekIhaleSozlesmeDamga = 0.0,
    double ekIhaleKararPuluDamga = 0.0,
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
    final isDosim = bKey == 'dosim';
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
    final bool isAylikKutuKumulatif = aylikMeta.isYillikKumulatif;

    // --- 1. 600 Hasılat (600 Yurtiçi + 601 Yurtdışı) & 123 POS Hesabı ---
    // Net Satışlar: 600 Yurtiçi + 601 Yurtdışı Satışlar (Alacak) - 610 Satıştan İadeler (Borç) - 611 Satış İskontoları (Borç)
    double hesaplaNetHasilat(Map<String, MizanHesapSatiri> hesaplar) {
      double brut = 0.0;
      if (hesaplar.containsKey('600')) {
        final h600 = hesaplar['600']!;
        brut += h600.alacak > 0 ? h600.alacak : h600.alacakKalan;
      }
      if (hesaplar.containsKey('601')) {
        final h601 = hesaplar['601']!;
        brut += h601.alacak > 0 ? h601.alacak : h601.alacakKalan;
      }

      if (brut <= 0) return 0.0;

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

    if (hasYillik && (yillikHesaplar.containsKey('600') || yillikHesaplar.containsKey('601'))) {
      hasilat600Kumulatif = hesaplaNetHasilat(yillikHesaplar);
    }

    if (hasAylik && (aylikHesaplar.containsKey('600') || aylikHesaplar.containsKey('601'))) {
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
    // Konsolide mizan sızıntısı engellenerek, mizanında 123 hesabı olan tüm birimler için (Sağlık, Sosyal Tesisler, DTS Satış, TÖMER vb.)
    double krediKarti123 = 0.0;
    if (!isAylikKonsolideMizan || isSaglikPosBirimi) {
      if (hasYillik && yillikHesaplar.containsKey('123') && yillikHesaplar['123']!.borcKalan > 0) {
        krediKarti123 = yillikHesaplar['123']!.borcKalan;
      } else if (hasAylik && aylikHesaplar.containsKey('123')) {
        final posBakiye = aylikHesaplar['123']!.borcKalan;
        krediKarti123 = posBakiye > 0 ? posBakiye : aylikHesaplar['123']!.borc;
      } else if (hasYillik && yillikHesaplar.containsKey('123')) {
        krediKarti123 = yillikHesaplar['123']!.borcKalan;
      }
    }

    // --- 2. 391 Hesaplanan KDV (%1, %10 ve %20) ---
    final aktifHesaplar = hasAylik ? aylikHesaplar : yillikHesaplar;

    var kdv391Kirilim = _ayristirKdvOranlari(aktifHesaplar, '391', isAlacak: true);
    if (kdv391Kirilim.kdv1 == 0.0 && kdv391Kirilim.kdv10 == 0.0 && kdv391Kirilim.kdv20 == 0.0 && hasYardimci) {
      kdv391Kirilim = _ayristirKdvOranlari(yardimciHesaplar, '391', isAlacak: true);
    }

    double kdv1 = kdv391Kirilim.kdv1;
    double kdv10 = kdv391Kirilim.kdv10;
    double kdv20 = kdv391Kirilim.kdv20;

    // Alt hesap kırılımı yoksa ve ana 391 hesabı varsa:
    if (kdv1 == 0.0 && kdv10 == 0.0 && kdv20 == 0.0 && aktifHesaplar.containsKey('391')) {
      final ana391 = aktifHesaplar['391']!.alacak > 0
          ? aktifHesaplar['391']!.alacak
          : aktifHesaplar['391']!.alacakKalan;
      if (ana391 > 0) {
        final bKey = BirimAdlandirma.canonicalKey(birimAdi);
        final isEgitimBirimi = bKey.contains('tomer') || bKey.contains('usem');
        final isOran10Uyumlu = hasilat600Aylik > 0 && (ana391 - hasilat600Aylik * 0.10).abs() <= 1.0;
        final isOran1Uyumlu = hasilat600Aylik > 0 && (ana391 - hasilat600Aylik * 0.01).abs() <= 1.0;

        if (isOran1Uyumlu) {
          kdv1 = ana391;
        } else if (isOran10Uyumlu || (isEgitimBirimi && (hasilat600Aylik == 0 || (ana391 - hasilat600Aylik * 0.20).abs() > 1.0))) {
          kdv10 = ana391;
        } else {
          kdv20 = ana391;
        }
      }
    }

    double matrah1 = kdv1 > 0 ? double.parse((kdv1 / 0.01).toStringAsFixed(2)) : 0.0;
    double matrah10 = kdv10 > 0 ? double.parse((kdv10 / 0.10).toStringAsFixed(2)) : 0.0;
    double matrah20 = kdv20 > 0 ? double.parse((kdv20 / 0.20).toStringAsFixed(2)) : 0.0;

    // Kuruş Yuvarlama Senkronizasyonu: Matrah ile 600 Hasılat arasındaki fark <= 0,50 TL ise 600 Hasılat'a eşitle
    if (hasilat600Aylik > 0) {
      if (matrah20 > 0 && matrah10 == 0 && matrah1 == 0 && (matrah20 - hasilat600Aylik).abs() <= 0.50) {
        matrah20 = hasilat600Aylik;
      } else if (matrah10 > 0 && matrah20 == 0 && matrah1 == 0 && (matrah10 - hasilat600Aylik).abs() <= 0.50) {
        matrah10 = hasilat600Aylik;
      } else if (matrah1 > 0 && matrah20 == 0 && matrah10 == 0 && (matrah1 - hasilat600Aylik).abs() <= 0.50) {
        matrah1 = hasilat600Aylik;
      }
    }

    // Yıllık kümülatif mizan kullanılıyorsa ve aylık net hasılat biliniyorsa:
    // Kümülatif mizan KDV'sinin aylık beyannameye sızmasını engelle (DTS & TADAUM koruması)
    final bool isYillikMizandanOkundu = !hasAylik || isAylikKonsolideMizan;
    if (isYillikMizandanOkundu) {
      if (hasilat600Aylik == 0.0) {
        // Bu ay hiç hasılat yoksa (TADAUM gibi), yıllık kümülatif mizan KDV'si bu aya yazılamaz
        kdv1 = 0.0;
        kdv10 = 0.0;
        kdv20 = 0.0;
        matrah1 = 0.0;
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
        if (kdv1 > 0 && (kdv1 > hasilat600Aylik || matrah1 > hasilat600Aylik * 1.5)) {
          kdv1 = double.parse((hasilat600Aylik * 0.01).toStringAsFixed(2));
          matrah1 = hasilat600Aylik;
        }
      }
    }

    // --- 3. 191 İndirilecek KDV (%1, %10 ve %20) ---
    var kdv191Kirilim = _ayristirKdvOranlari(aktifHesaplar, '191', isAlacak: false);
    if (kdv191Kirilim.kdv1 == 0.0 && kdv191Kirilim.kdv10 == 0.0 && kdv191Kirilim.kdv20 == 0.0 && hasYardimci) {
      kdv191Kirilim = _ayristirKdvOranlari(yardimciHesaplar, '191', isAlacak: false);
    }

    double ind1 = kdv191Kirilim.kdv1;
    double ind10 = kdv191Kirilim.kdv10;
    double ind20 = kdv191Kirilim.kdv20;

    if (ind1 == 0.0 && ind10 == 0.0 && ind20 == 0.0 && aktifHesaplar.containsKey('191')) {
      ind20 = aktifHesaplar['191']!.borc > 0
          ? aktifHesaplar['191']!.borc
          : aktifHesaplar['191']!.borcKalan;
    }

    if (isYillikMizandanOkundu) {
      // Yıllık kümülatif 191 tutarı tek bir aya indirilecek KDV olarak yazılamaz
      ind1 = 0.0;
      ind10 = 0.0;
      ind20 = 0.0;
    }

    final double indMatrah1 = ind1 > 0 ? double.parse((ind1 / 0.01).toStringAsFixed(2)) : 0.0;
    final double indMatrah10 = ind10 > 0 ? double.parse((ind10 / 0.10).toStringAsFixed(2)) : 0.0;
    final double indMatrah20 = ind20 > 0 ? double.parse((ind20 / 0.20).toStringAsFixed(2)) : 0.0;

    // --- 4. 190 Devreden KDV ---
    double devreden190 = 0.0;
    if (aktifHesaplar.containsKey('190')) {
      devreden190 = aktifHesaplar['190']!.borcKalan;
    } else if (yillikHesaplar.containsKey('190')) {
      devreden190 = yillikHesaplar['190']!.borcKalan;
    }

    // --- 5. 360 Damga Vergisi (Ödemelerden / Hakedişlerden Kesilen & İhale Damga) ---
    // Aylık Mizan + Yıllık Mizan + Yardımcı Defter (Muavin) 3'lü Çapraz Çözümleme Motoru:
    bool isDigerBirimAltHesabi(String hesapAdi) =>
        Mizan360CaprazCozumleyici.isDigerBirimMetni(hesapAdi, isDosim: isDosim);

    double oku360NetBakiye(MizanHesapSatiri s, {required bool isYillik}) =>
        Mizan360CaprazCozumleyici.oku360NetBakiye(s, isYillik: isYillik, isDosim: isDosim);

    final damgaDetay = Mizan360CaprazCozumleyici.cozumleCaprazDamga360(
      aylikHesaplar: aylikHesaplar,
      yillikHesaplar: yillikHesaplar,
      yardimciHesaplar: yardimciHesaplar,
      yardimciMizanMetni: yardimciMizanMetni,
      isAylikKutuKumulatif: isAylikKutuKumulatif,
      isDosim: isDosim,
    );

    double damga360 = damgaDetay.toplamDamga;
    double ihaleKararPulu360 = damgaDetay.ihaleKararPulu;
    double ihaleSozlesme360 = damgaDetay.ihaleSozlesme;

    // Ek evraktan gelen ihale damga vergisi varsa ve henüz mizanda yoksa ilgili ihale damga alanına ata (hakediş damga360 ile çift toplanmaz)
    if (ekIhaleKararPuluDamga > 0 && ihaleKararPulu360 == 0.0) {
      ihaleKararPulu360 = ekIhaleKararPuluDamga;
    }
    if (ekIhaleSozlesmeDamga > 0 && ihaleSozlesme360 == 0.0) {
      ihaleSozlesme360 = ekIhaleSozlesmeDamga;
    }

    final damgaMatrah = damga360 > 0 ? double.parse((damga360 / 0.00948).toStringAsFixed(2)) : 0.0;

    // --- 5b. 360.04 Mizan KDV 2 Tevkifatı (Sorumlu Sıfatıyla Ödenecek KDV) ---
    ({double toplamKdv2, String hesapDetayi, bool hesapBulundu, bool borcHareketiVar}) bulKdv2Tevkifat360(
      Map<String, MizanHesapSatiri> hesapMap, {
      required bool isYillik,
    }) {
      if (hesapMap.isEmpty) {
        return (toplamKdv2: 0.0, hesapDetayi: '', hesapBulundu: false, borcHareketiVar: false);
      }

      double toplam = 0.0;
      final detayList = <String>[];
      bool bulundu = false;
      bool borcVar = false;

      for (final entry in hesapMap.entries) {
        final k = entry.key;
        final norm = k.replaceAll(RegExp(r'\.0+'), '.');
        if (!k.startsWith('360') || k == '360') continue;

        final altVar = hesapMap.keys.any((other) => other != k && other.startsWith('$k.'));
        if (altVar) continue;

        final ad = entry.value.hesapAdi.toUpperCase();
        final is36004 = k == '360.04' ||
            norm == '360.4' ||
            k.startsWith('360.04.') ||
            norm.startsWith('360.4.');
        final isAdKdvTevkifat = (ad.contains('KDV') &&
                (ad.contains('TEVKİFAT') ||
                    ad.contains('TEVKIFAT') ||
                    ad.contains('SORUMLU') ||
                    ad.contains('2 NOLU') ||
                    ad.contains('2 NO.LU') ||
                    ad.contains('İKİ NOLU'))) ||
            ad.contains('SORUMLU SIFATIYLA');

        if (is36004 || isAdKdvTevkifat) {
          bulundu = true;
          if (entry.value.borc > 0) borcVar = true;
          if (isDigerBirimAltHesabi(entry.value.hesapAdi)) continue;
          final v = oku360NetBakiye(entry.value, isYillik: isYillik);
          if (v > 0) {
            toplam += v;
            detayList.add('$k ${entry.value.hesapAdi}');
          }
        }
      }

      return (
        toplamKdv2: double.parse(toplam.toStringAsFixed(2)),
        hesapDetayi: detayList.join(', '),
        hesapBulundu: bulundu,
        borcHareketiVar: borcVar,
      );
    }

    final muavin360 = Mizan360CaprazCozumleyici.cozumleYardimciDefterMuavinHareketleri(
      yardimciMizanMetni,
      isDosim: isDosim,
    );
    var kdv2MizanDetay = (toplamKdv2: 0.0, hesapDetayi: '', hesapBulundu: false, borcHareketiVar: false);
    if (muavin360.kdv2HareketBulundu && isDosim) {
      kdv2MizanDetay = (
        toplamKdv2: muavin360.kdv2Tevkifat,
        hesapDetayi: 'Yardımcı Defter (Muavin) 360.04',
        hesapBulundu: true,
        borcHareketiVar: false,
      );
    } else if (hasYardimci && isDosim) {
      final yKdv2 = bulKdv2Tevkifat360(yardimciHesaplar, isYillik: false);
      if (yKdv2.hesapBulundu) kdv2MizanDetay = yKdv2;
    }
    if (!kdv2MizanDetay.hesapBulundu && hasAylik) {
      kdv2MizanDetay = bulKdv2Tevkifat360(aylikHesaplar, isYillik: isAylikKutuKumulatif);
    }
    if (kdv2MizanDetay.toplamKdv2 == 0.0 && hasYardimci && !kdv2MizanDetay.hesapBulundu) {
      kdv2MizanDetay = bulKdv2Tevkifat360(yardimciHesaplar, isYillik: false);
    }
    if (hasYillik) {
      final yillikKdv2 = bulKdv2Tevkifat360(yillikHesaplar, isYillik: true);
      if (!kdv2MizanDetay.hesapBulundu ||
          (kdv2MizanDetay.toplamKdv2 == 0.0 && kdv2MizanDetay.borcHareketiVar && yillikKdv2.toplamKdv2 > 0) ||
          (yillikKdv2.hesapBulundu && yillikKdv2.borcHareketiVar && yillikKdv2.toplamKdv2 < kdv2MizanDetay.toplamKdv2)) {
        kdv2MizanDetay = yillikKdv2;
      }
    }
    final double kdv2Tevkifat360 = kdv2MizanDetay.toplamKdv2;
    final String kdv2HesapDetayi = kdv2MizanDetay.hesapDetayi;

    // --- 6. 360 Muhtasar (Gelir Vergisi Stopajı & Ücret Damga Vergisi Stopajı) ---
    final muhtasarDetay = Mizan360CaprazCozumleyici.cozumleCaprazMuhtasar(
      aylikHesaplar: aylikHesaplar,
      yillikHesaplar: yillikHesaplar,
      yardimciHesaplar: yardimciHesaplar,
      yardimciMizanMetni: yardimciMizanMetni,
      isAylikKutuKumulatif: isAylikKutuKumulatif,
      isDosim: isDosim,
      filtreAy: aylikMeta.bitisTarihi != null
          ? int.tryParse(aylikMeta.bitisTarihi!.split(RegExp(r'[./]')).length > 1
              ? aylikMeta.bitisTarihi!.split(RegExp(r'[./]'))[1]
              : '')
          : null,
    );

    final double muhtasarGelir360 = muhtasarDetay.muhtasarGelir;
    final double muhtasarDamga360 = muhtasarDetay.muhtasarDamga;

    // --- 7. Ters Bakiye Denetimleri ---
    final is191TersBakiye = (aktifHesaplar['191']?.alacakKalan ?? 0.0) > 0.01;
    final is391TersBakiye = (aktifHesaplar['391']?.borcKalan ?? 0.0) > 0.01;
    final is600TersBakiye = (aktifHesaplar['600']?.borcKalan ?? 0.0) > 0.01;

    // --- 8. Yardımcı Mizan Bilgileri ---
    double yardimci391 = 0.0;
    double yardimci191 = 0.0;
    double yardimci600 = 0.0;

    if (hasYardimci) {
      yardimci391 = yardimciHesaplar['391']?.alacak ?? (kdv391Kirilim.kdv1 + kdv391Kirilim.kdv10 + kdv391Kirilim.kdv20);
      yardimci191 = yardimciHesaplar['191']?.borc ?? (kdv191Kirilim.kdv1 + kdv191Kirilim.kdv10 + kdv191Kirilim.kdv20);
      yardimci600 = yardimciHesaplar['600']?.alacak ?? 0.0;
    }

    // Ham JSON kopyası (Denetim servisinin ve AI entegrasyonunun beklediği şema ile birebir uyumlu)
    final hamJson = {
      'birimAdi': birimAdi,
      'analizTarihi': DateTime.now().toIso8601String(),
      'hasilat600Aylik': hasilat600Aylik,
      'hasilat600Kumulatif': hasilat600Kumulatif,
      'krediKarti123': krediKarti123,
      'hesaplananKdvMatrah1': matrah1,
      'hesaplananKdv1': kdv1,
      'hesaplananKdvMatrah10': matrah10,
      'hesaplananKdv10': kdv10,
      'hesaplananKdvMatrah20': matrah20,
      'hesaplananKdv20': kdv20,
      'indirilecekKdvMatrah1': indMatrah1,
      'indirilecekKdv1': ind1,
      'indirilecekKdvMatrah10': indMatrah10,
      'indirilecekKdv10': ind10,
      'indirilecekKdvMatrah20': indMatrah20,
      'indirilecekKdv20': ind20,
      'damgaVergisi360': damga360,
      'damgaMatrah': damgaMatrah,
      'ihaleSozlesmeDamga360': ihaleSozlesme360,
      'ihaleKararPuluDamga360': ihaleKararPulu360,
      'kdv2Tevkifat360': kdv2Tevkifat360,
      'kdv2HesapDetayi': kdv2HesapDetayi,
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
      hesaplananKdvMatrah1: matrah1,
      hesaplananKdv1: kdv1,
      hesaplananKdvMatrah10: matrah10,
      hesaplananKdv10: kdv10,
      hesaplananKdvMatrah20: matrah20,
      hesaplananKdv20: kdv20,
      indirilecekKdvMatrah1: indMatrah1,
      indirilecekKdv1: ind1,
      indirilecekKdvMatrah10: indMatrah10,
      indirilecekKdv10: ind10,
      indirilecekKdvMatrah20: indMatrah20,
      indirilecekKdv20: ind20,
      damgaVergisi360: damga360,
      damgaMatrah: damgaMatrah,
      ihaleSozlesmeDamga360: ihaleSozlesme360,
      ihaleKararPuluDamga360: ihaleKararPulu360,
      kdv2Tevkifat360: kdv2Tevkifat360,
      kdv2HesapDetayi: kdv2HesapDetayi,
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

