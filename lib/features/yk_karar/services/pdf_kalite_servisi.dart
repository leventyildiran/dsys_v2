import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/models/sablon_model.dart';
import 'yk_karar_eslestirme_servisi.dart';

/// PDF yükleme/analiz öncesi kurumsal kalite kontrolü.
class PdfKaliteServisi {
  static const int minMetinUzunlugu = 80;

  Future<PdfKaliteSonucu> denetle({
    required Uint8List pdfBytes,
    SablonModel? kararSablon,
  }) async {
    final uyarilar = <String>[];
    final hatalar = <String>[];

    String pdfText;
    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      pdfText = PdfTextExtractor(doc).extractText();
      doc.dispose();
    } catch (e) {
      return PdfKaliteSonucu(
        gecerli: false,
        pdfText: '',
        hatalar: ['PDF dosyası okunamadı veya bozuk: $e'],
      );
    }

    final trimmed = pdfText.trim();
    if (trimmed.isEmpty) {
      hatalar.add(
        'PDF içinden metin çıkarılamadı. Taranmış (fotoğraf) PDF kullanılamaz — '
        'metin tabanlı PDF yükleyin.',
      );
      return PdfKaliteSonucu(gecerli: false, pdfText: '', hatalar: hatalar);
    }

    if (trimmed.length < minMetinUzunlugu) {
      hatalar.add(
        'PDF metni çok kısa (${trimmed.length} karakter). Muhtemelen taranmış belge — analiz durduruldu.',
      );
    }

    final tablolar = YkKararEslestirmeServisi.tabloVerileriCikar(trimmed);
    final sablonTablolu = kararSablon != null &&
        (kararSablon.dosyaUzantisi == '.docx' || kararSablon.dosyaUzantisi == '.doc');

    if (sablonTablolu && tablolar.isEmpty) {
      uyarilar.add(
        'PDF\'ten tablo verisi okunamadı. Word çıktısında tablo yapısı korunur '
        'ancak hücre değerleri şablondaki eski verilerle kalabilir.',
      );
    }

    if (tablolar.isNotEmpty &&
        tablolar.first.values.every((v) => v.toString().trim().isEmpty)) {
      uyarilar.add('Tablo satırları algılandı ancak hücre içerikleri boş görünüyor.');
    }

    final tarihler = RegExp(r'\d{2}[./]\d{2}[./]\d{4}').allMatches(trimmed).length;
    if (tarihler == 0) {
      uyarilar.add('PDF\'te tarih bulunamadı — evrak tarihi manuel kontrol edilmeli.');
    }

    final evrak = RegExp(r'E-?\d[\d-]*', caseSensitive: false).allMatches(trimmed).length;
    if (evrak == 0) {
      uyarilar.add('PDF\'te evrak numarası (E-...) bulunamadı.');
    }

    return PdfKaliteSonucu(
      gecerli: hatalar.isEmpty,
      pdfText: trimmed,
      tabloSatirSayisi: tablolar.length,
      tabloKolonSayisi: tablolar.isNotEmpty ? tablolar.first.keys.length : 0,
      uyarilar: uyarilar,
      hatalar: hatalar,
    );
  }
}

class PdfKaliteSonucu {
  const PdfKaliteSonucu({
    required this.gecerli,
    required this.pdfText,
    this.tabloSatirSayisi = 0,
    this.tabloKolonSayisi = 0,
    this.uyarilar = const [],
    this.hatalar = const [],
  });

  final bool gecerli;
  final String pdfText;
  final int tabloSatirSayisi;
  final int tabloKolonSayisi;
  final List<String> uyarilar;
  final List<String> hatalar;
}
