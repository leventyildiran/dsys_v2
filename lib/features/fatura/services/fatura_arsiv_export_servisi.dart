import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import '../../../core/turkce_format.dart';

/// Geçici Firestore arşivini indirilebilir dosyalara dönüştürür.
class FaturaArsivExportServisi {
  FaturaArsivExportServisi._();

  static Future<void> indirJson(
    int yil,
    List<Map<String, dynamic>> kayitlar,
  ) async {
    final temiz = kayitlar.map(_temizKayit).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert({
      'kayitYili': yil,
      'disaAktarmaTarihi': DateTime.now().toIso8601String(),
      'faturaSayisi': temiz.length,
      'faturalar': temiz,
    });
    await _kaydet(
      'fatura_arsiv_$yil.json',
      utf8.encode(jsonStr),
      MimeType.json,
    );
  }

  static Future<void> indirCsv(
    int yil,
    List<Map<String, dynamic>> kayitlar,
  ) async {
    final satirlar = <String>[
      _csvBaslik.join(';'),
      ...kayitlar.map((k) => _csvSatir(k)),
    ];
    // UTF-8 BOM — Excel Türkçe karakterleri doğru açsın
    final bytes = utf8.encode('\uFEFF${satirlar.join('\n')}');
    await _kaydet('fatura_arsiv_$yil.csv', bytes, MimeType.text);
  }

  /// Eski yılları tek ZIP içinde JSON + CSV olarak indirir.
  static Future<void> indirYillikZip(
    Map<int, List<Map<String, dynamic>>> yilKayitlari,
  ) async {
    final archive = Archive();
    for (final entry in yilKayitlari.entries) {
      final yil = entry.key;
      final kayitlar = entry.value.map(_temizKayit).toList();

      final jsonBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'kayitYili': yil,
          'disaAktarmaTarihi': DateTime.now().toIso8601String(),
          'faturaSayisi': kayitlar.length,
          'faturalar': kayitlar,
        }),
      );
      archive.addFile(
        ArchiveFile('fatura_arsiv_$yil.json', jsonBytes.length, jsonBytes),
      );

      final csvSatirlar = [_csvBaslik.join(';'), ...entry.value.map(_csvSatir)];
      final csvBytes = utf8.encode('\uFEFF${csvSatirlar.join('\n')}');
      archive.addFile(
        ArchiveFile('fatura_arsiv_$yil.csv', csvBytes.length, csvBytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    await _kaydet(
      'fatura_arsiv_yedek_${DateTime.now().year}.zip',
      Uint8List.fromList(zipBytes),
      MimeType.zip,
    );
  }

  static const _csvBaslik = [
    'Firma Adı',
    'Adres',
    'Vergi Dairesi',
    'VKN/TC',
    'Tarih',
    'İrsaliye Tarihi',
    'İrsaliye No',
    'MELBES No',
    'Numune No',
    'Numune Açıklaması',
    'Kalemler',
    'Matrah',
    'KDV Oranı',
    'KDV Tutarı',
    'Genel Toplam',
    'IBAN',
    'Hesap Adı',
    'Hizmet Tipi',
    'Kurs Adı',
    'Kur No',
    'Ödeme Tipi',
    'Ürün Türü',
    'Tedarik Yöntemi',
    'Dönem',
    'Genel Açıklama',
    'YTB Öğrencisi',
    'KDV İstisnası',
    'Kayıt Yılı',
    'Sisteme Kayıt',
  ];

  static String _csvSatir(Map<String, dynamic> k) {
    final kalemler = _kalemOzeti(k['kalemler']);
    return [
      k['firmaAdi'],
      k['adres'],
      k['vergiDairesi'],
      k['vergiNo'],
      k['tarih'],
      k['irsaliyeTarihi'],
      k['irsaliyeNo'],
      k['melbesNo'],
      k['numuneNo'],
      k['numuneAciklamasi'],
      kalemler,
      _para(k['matrah']),
      k['kdvOrani']?.toString() ?? '',
      _para(k['kdvTutari']),
      _para(k['genelToplam']),
      k['iban'],
      k['hesapAdi'],
      k['hizmetTipi'],
      k['kursAdi'],
      k['kurNo']?.toString(),
      k['odemeTipi'],
      k['urunTuru'],
      k['tedarikYontemi'],
      k['donem'],
      k['aciklama'],
      k['ytbOgrencisi'] == true ? 'Evet' : 'Hayır',
      k['isKdvMuaf'] == true ? 'Evet' : 'Hayır',
      k['kayitYili']?.toString() ?? '',
      _tarihStr(k['sistemeKayitTarihi']),
    ].map(_csvHucre).join(';');
  }

  static String _kalemOzeti(dynamic kalemler) {
    if (kalemler is! List) return '';
    return kalemler
        .map((item) {
          if (item is! Map) return item.toString();
          final cinsi = item['cinsi'] ?? '';
          final miktar = item['miktar'] ?? 1;
          final fiyat = item['fiyat'] ?? 0;
          return '$cinsi ($miktar x $fiyat)';
        })
        .join(' | ');
  }

  static String _para(dynamic v) {
    final n = (v as num?)?.toDouble();
    if (n == null) return '';
    return TurkceFormat.ondalik(n).replaceAll('.', ',');
  }

  static String _tarihStr(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    return v.toString();
  }

  static String _csvHucre(dynamic v) {
    final s = (v ?? '').toString().replaceAll('\n', ' ').replaceAll(';', ',');
    if (s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Map<String, dynamic> _temizKayit(Map<String, dynamic> raw) {
    final kopya = Map<String, dynamic>.from(raw);
    final ts = kopya['sistemeKayitTarihi'];
    if (ts is Timestamp) {
      kopya['sistemeKayitTarihi'] = ts.toDate().toIso8601String();
    }
    return kopya;
  }

  static Future<void> _kaydet(
    String name,
    Uint8List bytes,
    MimeType mime,
  ) async {
    await FileSaver.instance.saveFile(name: name, bytes: bytes, mimeType: mime);
  }
}
