import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/yk_karar_model.dart';
import '../../danismanlik/models/danismanlik_model.dart';
import '../../../core/turkce_format.dart';

/// Word (DOCX) ve PDF belgeleri üretmek için servis (v2).
/// 
/// `docx_creator` paketi ile tamamen native Dart / Web uyumlu olarak
/// Karar defterleri ve Gündem çıktıları oluşturur.
class BelgeUretimServisi {
  
  /// Aktif karar için Word belgesi oluşturur ve indirir (Web uyumlu).
  static Future<void> kararWordIndir(YkKararModel karar) async {
    try {
      final docBuilder = docx();

      // Başlık Stili (Markdown tarzı **bold** desteği ile)
      docBuilder.p(
        '**T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ\n(Döner Sermaye İşletme Müdürlüğü)**\n',
        align: DocxAlign.center,
      );

      docBuilder.p(
        '**DÖNER SERMAYE YÜRÜTME KURULU KARARLARI**\n',
        align: DocxAlign.center,
      );

      // Toplantı Bilgileri
      docBuilder.p(
        '**Toplantı Tarihi:** ${karar.kararTarihi}\n**Karar No:** ${karar.kararNo}\n',
        align: DocxAlign.left,
      );

      // Karar Metni
      docBuilder.p(
        karar.kararMetni,
        align: DocxAlign.justify, // Justified
      );

      // Tablo varsa ekle (Faaliyet Cetveli vs)
      if (karar.tabloVerileri.isNotEmpty) {
        docBuilder.p('\n'); // Boşluk
        
        final columns = karar.tabloVerileri.first.keys.toList();
        
        final List<List<String>> tableData = [];
        
        // Tablo başlıkları (bold yapmak için Markdown ekleyebiliriz)
        tableData.add(columns.map((c) => '**${c.toUpperCase()}**').toList());

        // Tablo satırları
        for (final row in karar.tabloVerileri) {
          tableData.add(columns.map((col) => row[col]?.toString() ?? '').toList());
        }

        docBuilder.table(tableData, hasHeader: true);
      }

      // Dosyayı kaydet
      final builtDoc = docBuilder.build();
      final bytes = await DocxExporter().exportToBytes(builtDoc);
      
      // Web'de dosyayı indirtmek için dart:html kullan
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Karar_${karar.kararNo.replaceAll('/', '_')}.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Masaüstü/Mobil implementasyonu (Gerekirse)
        debugPrint('Web harici indirme henüz desteklenmiyor.');
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.kararWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Aktif karar için PDF belgesi üretir (Önizleme ve yazdırma için).
  static Future<Uint8List> kararPdfUret(YkKararModel karar) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Başlık
            pw.Center(
              child: pw.Text(
                'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ\n(Döner Sermaye İşletme Müdürlüğü)',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'DÖNER SERMAYE YÜRÜTME KURULU KARARLARI',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, decoration: pw.TextDecoration.underline),
              ),
            ),
            pw.SizedBox(height: 20),

            // Toplantı Bilgileri
            pw.Text(
              'Toplantı Tarihi: ${karar.kararTarihi}\nKarar No: ${karar.kararNo}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
            pw.SizedBox(height: 15),

            // Karar Metni
            pw.Paragraph(
              text: karar.kararMetni,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
              textAlign: pw.TextAlign.justify,
            ),

            // Tablo (Varsa)
            if (karar.tabloVerileri.isNotEmpty) ...[
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: karar.tabloVerileri.first.keys.map((k) => k.toUpperCase()).toList(),
                data: karar.tabloVerileri.map((row) => row.values.map((v) => v?.toString() ?? '').toList()).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.center,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Tüm toplantı kararlarını tek bir Word belgesinde birleştirir.
  static Future<void> topluKararWordIndir(List<YkKararModel> kararlar, String toplantiNo) async {
    if (kararlar.isEmpty) return;

    try {
      final docBuilder = docx();

      for (var i = 0; i < kararlar.length; i++) {
        final karar = kararlar[i];

        // Sayfa Başı (İlk sayfa hariç)
        if (i > 0) {
          docBuilder.pageBreak();
        }

        docBuilder.p(
          '**T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ\n(Döner Sermaye İşletme Müdürlüğü)**\n',
          align: DocxAlign.center,
        );

        docBuilder.p(
          '**Karar No:** ${karar.kararNo}',
          align: DocxAlign.left,
        );

        docBuilder.p(
          karar.kararMetni,
          align: DocxAlign.justify,
        );

        if (karar.tabloVerileri.isNotEmpty) {
          final columns = karar.tabloVerileri.first.keys.toList();
          final List<List<String>> tableData = [];
          
          tableData.add(columns.map((c) => '**${c.toUpperCase()}**').toList());

          for (final row in karar.tabloVerileri) {
            tableData.add(columns.map((col) => row[col]?.toString() ?? '').toList());
          }

          docBuilder.table(tableData, hasHeader: true);
        }
      }

      final builtDoc = docBuilder.build();
      final bytes = await DocxExporter().exportToBytes(builtDoc);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Toplanti_$toplantiNo.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.topluKararWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Danışmanlık Karar/Sözleşme taslağı için Word belgesi oluşturur.
  static Future<void> danismanlikWordIndir(DanismanlikModel danismanlik, String kararMetni) async {
    try {
      final docBuilder = docx();

      // Başlık Stili
      docBuilder.p(
        '**T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ\n(Döner Sermaye İşletme Müdürlüğü)**\n',
        align: DocxAlign.center,
      );

      docBuilder.p(
        '**DANIŞMANLIK KARAR ÖZETİ / SÖZLEŞME METNİ**\n',
        align: DocxAlign.center,
      );

      // Genel Bilgiler
      docBuilder.p(
        '**Danışmanlık Türü:** ${danismanlik.danismanlikTuru.displayName}\n'
        '**Firma:** ${danismanlik.firmaUnvan}\n'
        '**Konu:** ${danismanlik.konusu}\n'
        '**Brüt Tutar:** ${TurkceFormat.para(danismanlik.toplamTutar)}\n'
        '**Süre:** ${danismanlik.suresi} Ay\n',
        align: DocxAlign.left,
      );

      // Karar Metni
      docBuilder.p(
        kararMetni,
        align: DocxAlign.justify,
      );

      final builtDoc = docBuilder.build();
      final bytes = await DocxExporter().exportToBytes(builtDoc);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Danismanlik_${danismanlik.firmaUnvan?.replaceAll(' ', '_') ?? 'Belge'}.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.danismanlikWordIndir] Hata: $e');
      rethrow;
    }
  }
}
