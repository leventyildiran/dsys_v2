import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/turkce_format.dart';
import '../../fatura/services/excel_universal_parser.dart';
import '../../fatura/services/fatura_offline_parser.dart';
import '../models/beyanname_belge_model.dart';
import '../models/beyanname_denetim_rapor_model.dart';
import 'beyanname_denetim_servisi.dart';
import 'mizan_deterministik_parser.dart';

/// Canlı akış log mesajı
class AjanLogMesaji {
  final DateTime zaman;
  final String mesaj;
  final String? birimAdi;
  final double ilerlemeYuzdesi; // 0.0 - 1.0
  final bool isHata;
  final bool isBasarili;

  const AjanLogMesaji({
    required this.zaman,
    required this.mesaj,
    this.birimAdi,
    required this.ilerlemeYuzdesi,
    this.isHata = false,
    this.isBasarili = false,
  });

  String get formatliZaman {
    final s = zaman.hour.toString().padLeft(2, '0');
    final d = zaman.minute.toString().padLeft(2, '0');
    final sn = zaman.second.toString().padLeft(2, '0');
    return '$s:$d:$sn';
  }
}

/// Sıralı, kontrollü, hata dayanımlı ve faturadaki evrensel okuma modüllerini
/// kullanan Akıllı Beyanname Mizan & Belge Ajanı Servisi.
class BeyannameAiAjanServisi {
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();

  static const List<String> _geminiModelFallbacks = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.7-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  /// Fatura modülündeki evrensel parser'ları ve PDF text extractor'ı kullanarak
  /// belge içeriğinden saf metni çıkarır.
  Future<String> belgeMetniniCikar(BirimYuklenenBelge belge) async {
    final bytes = belge.dosyaBytes;
    if (bytes == null || bytes.isEmpty) return '';

    // 1. Excel ise doğrudan fatura modülündeki ExcelUniversalParser'ı kullan (tekrar yazma!)
    if (belge.isExcel) {
      try {
        final text = await ExcelUniversalParser.extractText(
          bytes,
          fileName: belge.dosyaAdi,
        );
        if (text.trim().isNotEmpty) {
          debugPrint(
            '[BeyannameAiAjanServisi] Excel başarıyla ayrıştırıldı (${belge.dosyaAdi}): ${text.length} karakter.',
          );
          return text;
        }
      } catch (e) {
        debugPrint('[BeyannameAiAjanServisi] ExcelUniversalParser hatası: $e');
      }
    }

    // 2. PDF ise syncfusion_flutter_pdf ile metin katmanını çıkar
    if (belge.isPdf) {
      try {
        final doc = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(doc).extractText().trim();
        doc.dispose();
        debugPrint(
          '[BeyannameAiAjanServisi] PDF metin katmanı çıkarıldı (${belge.dosyaAdi}): ${text.length} karakter.',
        );
        return text;
      } catch (e) {
        debugPrint('[BeyannameAiAjanServisi] PDF metin çıkarma hatası: $e');
      }
    }

    // 3. Düz metin / CSV
    try {
      return utf8.decode(bytes, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }

  /// Sıralı (Sequential Queue) Analiz Akışı:
  /// Tek tek her birimi OpenRouter veya Gemini'ye okutur; o birim doğrulanana kadar sonrakine geçmez.
  Stream<AjanLogMesaji> siraliAnalizBaslat({
    required int yil,
    required int ay,
    required Map<String, Map<BirimBelgeSlotTuru, BirimYuklenenBelge>> yuklenenBelgeler,
    required Map<String, double> birimOncekiAylarHasilat,
    required double oncekiAydanDevredenKdv,
    String? sadeceBuBirim,
    required void Function(BeyannameAjanRaporu rapor) onTamamlandi,
    required void Function(String hataMesaji) onHata,
  }) async* {
    final ayarlar = await _ayarlarService.getAyarlar();
    final hasGemini = ayarlar.geminiApiKey.trim().isNotEmpty;
    final hasOpenRouter = ayarlar.deepseekApiKey.trim().isNotEmpty;
    final bool isOfflineMod = !hasGemini && !hasOpenRouter;

    if (isOfflineMod) {
      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⚡ Sistem Ayarlarında AI anahtarı tanımlı değil. Kural Tabanlı Deterministik Mizan Motoru devreye alındı (Çevrimdışı & Sıfır Maliyetli Çalışma).',
        ilerlemeYuzdesi: 0.01,
      );
    }

    // Yalnızca en az 1 belgesi yüklenmiş aktif birimleri filtrele
    List<String> doluBirimler = yuklenenBelgeler.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (sadeceBuBirim != null && sadeceBuBirim.trim().isNotEmpty) {
      final hedefBirim = sadeceBuBirim.trim();
      doluBirimler = doluBirimler.where((b) => b == hedefBirim).toList();
      if (doluBirimler.isEmpty) {
        final msg = '$hedefBirim birimi için henüz yüklenmiş bir mizan veya evrak bulunmuyor.';
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '⚠️ $msg',
          ilerlemeYuzdesi: 0.0,
          isHata: true,
        );
        onHata(msg);
        return;
      }
    } else if (doluBirimler.isEmpty) {
      final msg = 'Lütfen analiz edilecek birimlere en az bir mizan/belge yükleyiniz.';
      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⚠️ $msg',
        ilerlemeYuzdesi: 0.0,
        isHata: true,
      );
      onHata(msg);
      return;
    }

    int toplamDosya = 0;
    for (final b in doluBirimler) {
      toplamDosya += yuklenenBelgeler[b]?.length ?? 0;
    }

    final motorBilgisi = hasGemini
        ? '🤖 Google Gemini (${ayarlar.geminiModel})${hasOpenRouter ? " [OpenRouter Yedekli]" : ""}'
        : '🌐 OpenRouter (${ayarlar.deepseekModel.isNotEmpty ? ayarlar.deepseekModel : "Varsayılan Model"})';

    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🚀 Beyanname Ajanı Başlatıldı [$motorBilgisi] ($yil / ${ay.toString().padLeft(2, '0')}). Toplam $toplamDosya evrak sıralı kuyruğa alındı.',
      ilerlemeYuzdesi: 0.02,
    );

    final analizSonuclari = <String, BirimMizanAnalizSonucu>{};
    final toplamBirimSayisi = doluBirimler.length;

    // BİRİM BİRİM SIRALI İŞLEME DÖNGÜSÜ
    for (int i = 0; i < toplamBirimSayisi; i++) {
      final birimAdi = doluBirimler[i];
      final birimBelgeleri = yuklenenBelgeler[birimAdi] ?? {};

      final birimIlerlemeBaslangic = (i / toplamBirimSayisi);
      final birimIlerlemeBitis = ((i + 1) / toplamBirimSayisi);

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⏳ [${i + 1}/$toplamBirimSayisi] $birimAdi için analiz başlatılıyor...',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBaslangic,
      );

      final aylikMizanBelgesi = birimBelgeleri[BirimBelgeSlotTuru.aylikMizan];
      final yardimciMizanBelgesi = birimBelgeleri[BirimBelgeSlotTuru.yardimciMizan];
      final yillikMizanBelgesi = birimBelgeleri[BirimBelgeSlotTuru.yillikMizan];
      final digerBelge = birimBelgeleri[BirimBelgeSlotTuru.diger];

      // 1. Aylık Mizan Metni ve Dosyası
      String aylikMizanMetni = '';
      if (aylikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📄 [$birimAdi] Aylık Mizan (${aylikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.05 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        aylikMizanMetni = await belgeMetniniCikar(aylikMizanBelgesi);
      }

      // 2. Yardımcı Mizan (Muavin) Metni
      String yardimciMizanMetni = '';
      if (yardimciMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📑 [$birimAdi] Yardımcı Mizan (Muavin) (${yardimciMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.10 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        yardimciMizanMetni = await belgeMetniniCikar(yardimciMizanBelgesi);
      }

      // 3. Yıllık Mizan Metni
      String yillikMizanMetni = '';
      if (yillikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📊 [$birimAdi] Yıllık Kümülatif Mizan (${yillikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.15 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        yillikMizanMetni = await belgeMetniniCikar(yillikMizanBelgesi);
      }

      // 4. Diğer Belgeler (Fatura modülünün offline ayrıştırıcısı ile kontrol)
      String digerBelgeMetni = '';
      final tevkifatFaturaListesi = <Map<String, dynamic>>[];
      if (digerBelge != null) {
        digerBelgeMetni = await belgeMetniniCikar(digerBelge);
        // Faturada varsa kural tabanlı offline parser'ı dene
        try {
          final faturalar = FaturaOfflineParser.parse(digerBelgeMetni);
          for (final f in faturalar) {
            if (f.kalemler.isNotEmpty) {
              tevkifatFaturaListesi.add({
                'firmaAdi': f.firmaAdi,
                'vergiTcNo': f.vergiNo,
                'matrahTutari': f.matrah,
                'kdvTutari': f.kdvTutari,
                'tevkifatTutari': f.kdvTutari * 0.9, // Varsa oran
                'tevkifatOrani': '9/10',
              });
            }
          }
        } catch (_) {}
      }

      // 5. Kural Tabanlı Deterministik Mizan Ayrıştırması (Her Zaman Çalışır)
      final deterministikSonuc = MizanDeterministikParser.analizEt(
        birimAdi: birimAdi,
        aylikMizanMetni: aylikMizanMetni,
        yillikMizanMetni: yillikMizanMetni,
        yardimciMizanMetni: yardimciMizanMetni,
        oncekiAylarHasilat: birimOncekiAylarHasilat[birimAdi] ?? 0.0,
        ekTevkifatFaturalari: tevkifatFaturaListesi,
      );

      final hasDeterministikVeri = deterministikSonuc.hasilat600Aylik > 0 ||
          deterministikSonuc.hasilat600Kumulatif > 0 ||
          deterministikSonuc.toplamHesaplananKdv > 0 ||
          deterministikSonuc.damgaVergisi360 > 0;

      if (hasDeterministikVeri) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📐 [$birimAdi] Kural tabanlı mizan tespiti: 600 Hasılat: ${TurkceFormat.para(deterministikSonuc.hasilat600Aylik)}, KDV: ${TurkceFormat.para(deterministikSonuc.toplamHesaplananKdv)}, Damga: ${TurkceFormat.para(deterministikSonuc.damgaVergisi360)}.',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.25 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
      }

      BirimMizanAnalizSonucu? sonuc;

      // Eğer çevrimdışı moddaysa (AI anahtarı yoksa), doğrudan deterministik sonucu kullan
      if (isOfflineMod) {
        sonuc = deterministikSonuc;
      } else {
        // AI İstemi Hazırlama (Deterministik referans değerlerini de ekle)
        final prompt = _buildMizanPrompt(
          birimAdi: birimAdi,
          yil: yil,
          ay: ay,
          aylikMizanMetni: aylikMizanMetni,
          yardimciMizanMetni: yardimciMizanMetni,
          yillikMizanMetni: yillikMizanMetni,
          digerBelgeMetni: digerBelgeMetni,
        );

        final contentParts = <Part>[];
        void addMediaPartIfApplicable(BirimYuklenenBelge? doc, String extractedText) {
          if (doc == null || doc.dosyaBytes == null || doc.dosyaBytes!.isEmpty) return;
          final ext = doc.dosyaUzantisi.toLowerCase().replaceAll('.', '').trim();
          if (ext == 'png') {
            contentParts.add(DataPart('image/png', doc.dosyaBytes!));
          } else if (ext == 'jpg' || ext == 'jpeg') {
            contentParts.add(DataPart('image/jpeg', doc.dosyaBytes!));
          } else if (ext == 'pdf' && extractedText.trim().length < 30) {
            contentParts.add(DataPart('application/pdf', doc.dosyaBytes!));
          }
        }

        addMediaPartIfApplicable(aylikMizanBelgesi, aylikMizanMetni);
        addMediaPartIfApplicable(yardimciMizanBelgesi, yardimciMizanMetni);
        addMediaPartIfApplicable(yillikMizanBelgesi, yillikMizanMetni);
        addMediaPartIfApplicable(digerBelge, digerBelgeMetni);
        contentParts.add(TextPart(prompt));

        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: hasGemini
              ? '🤖 [$birimAdi] Google Gemini AI ile derin mizan taraması ve hesap kodları tespiti yapılıyor...'
              : '🌐 [$birimAdi] OpenRouter üzerinden derin mizan ve tevkifat analizi yapılıyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.35 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );

        // Kesintisiz Dayanıklı AI Çağrısı (OpenRouter + Gemini Fallback & Retry)
        int denemeSayisi = 0;
        const maxDeneme = 4;

        while (denemeSayisi < maxDeneme) {
          denemeSayisi++;
          try {
            final aiResponseText = await _calistirAiModel(
              ayarlar: ayarlar,
              prompt: prompt,
              geminiParts: contentParts,
            );

            if (aiResponseText != null && aiResponseText.isNotEmpty) {
              final parsedJson = _parseCleanJson(aiResponseText);
              if (parsedJson != null) {
                // Tevkifat faturalarını tekilleştirerek birleştir
                final aiTevkifat = (parsedJson['tevkifatFaturalari'] as List<dynamic>?)
                        ?.map((e) => Map<String, dynamic>.from(e as Map))
                        .toList() ??
                    [];
                for (final tf in tevkifatFaturaListesi) {
                  final vNo = tf['vergiTcNo']?.toString().trim() ?? '';
                  final mtr = TurkceFormat.parseSayi(tf['matrahTutari']);
                  final alreadyExists = aiTevkifat.any((a) {
                    final aVNo = a['vergiTcNo']?.toString().trim() ?? '';
                    final aMtr = TurkceFormat.parseSayi(a['matrahTutari']);
                    final sameMatrah = mtr > 0 && (aMtr - mtr).abs() < 1.0;
                    return sameMatrah && (vNo.isEmpty || aVNo.isEmpty || aVNo == vNo);
                  });
                  if (!alreadyExists) {
                    aiTevkifat.add(tf);
                  }
                }
                parsedJson['tevkifatFaturalari'] = aiTevkifat;
                parsedJson['birimAdi'] = birimAdi;
                parsedJson['analizTarihi'] = DateTime.now().toIso8601String();

                // Eğer AI hasılat veya KDV'yi 0 dönmüş ama deterministik parser bulmuşsa,
                // kurumsal mizan değerlerini koru (halüsinasyon koruması)
                if (hasDeterministikVeri) {
                  if (TurkceFormat.parseSayi(parsedJson['hasilat600Aylik']) == 0 &&
                      deterministikSonuc.hasilat600Aylik > 0) {
                    parsedJson['hasilat600Aylik'] = deterministikSonuc.hasilat600Aylik;
                  }
                  if (TurkceFormat.parseSayi(parsedJson['hasilat600Kumulatif']) == 0 &&
                      deterministikSonuc.hasilat600Kumulatif > 0) {
                    parsedJson['hasilat600Kumulatif'] = deterministikSonuc.hasilat600Kumulatif;
                  }
                  if (TurkceFormat.parseSayi(parsedJson['hesaplananKdv20']) == 0 &&
                      deterministikSonuc.hesaplananKdv20 > 0) {
                    parsedJson['hesaplananKdv20'] = deterministikSonuc.hesaplananKdv20;
                    parsedJson['hesaplananKdvMatrah20'] = deterministikSonuc.hesaplananKdvMatrah20;
                  }
                  if (TurkceFormat.parseSayi(parsedJson['damgaVergisi360']) == 0 &&
                      deterministikSonuc.damgaVergisi360 > 0) {
                    parsedJson['damgaVergisi360'] = deterministikSonuc.damgaVergisi360;
                    parsedJson['damgaMatrah'] = deterministikSonuc.damgaMatrah;
                  }
                }

                sonuc = BirimMizanAnalizSonucu.fromMap(parsedJson);
                break; // Başarılı, döngüden çık!
              }
            }

            throw Exception('Yapay zeka geçerli JSON çıktısı üretemedi.');
          } catch (e) {
            final hataStr = e.toString();
            debugPrint('[$birimAdi] Deneme $denemeSayisi/$maxDeneme hatası: $hataStr');

            if (denemeSayisi < maxDeneme) {
              final beklemeSaniye = denemeSayisi * 2;
              yield AjanLogMesaji(
                zaman: DateTime.now(),
                mesaj: '⏳ [$birimAdi] AI servisinden yanıt bekleniyor ($beklemeSaniye sn sonra tekrar denenecek: $denemeSayisi/$maxDeneme)...',
                birimAdi: birimAdi,
                ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.40 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
                isHata: true,
              );
              await Future.delayed(Duration(seconds: beklemeSaniye));
            } else {
              // AI yanıt veremezse deterministik analizi devreye al (Kayıp ve çökme yok!)
              if (hasDeterministikVeri) {
                yield AjanLogMesaji(
                  zaman: DateTime.now(),
                  mesaj: 'ℹ️ [$birimAdi] AI yanıt veremedi ($hataStr). Kural tabanlı deterministik mizan analiz sonucu korundu.',
                  birimAdi: birimAdi,
                  ilerlemeYuzdesi: birimIlerlemeBitis,
                );
                sonuc = deterministikSonuc;
              } else {
                yield AjanLogMesaji(
                  zaman: DateTime.now(),
                  mesaj: '❌ [$birimAdi] $maxDeneme denemede okunamadı ($hataStr). Bu birim için sıfır/boş taslak oluşturuldu.',
                  birimAdi: birimAdi,
                  ilerlemeYuzdesi: birimIlerlemeBitis,
                  isHata: true,
                );
                sonuc = BirimMizanAnalizSonucu(
                  birimAdi: birimAdi,
                  analizTarihi: DateTime.now(),
                  aciklama: 'AI okuma hatası: $hataStr',
                );
              }
            }
          }
        }
      }

      analizSonuclari[birimAdi] = sonuc!;

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '✅ [${i + 1}/$toplamBirimSayisi] $birimAdi tamamlandı -> 600 Hasılat: ${TurkceFormat.para(sonuc.hasilat600Aylik)}, 123 POS: ${TurkceFormat.para(sonuc.krediKarti123)}, KDV: ${TurkceFormat.para(sonuc.toplamHesaplananKdv)}.',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBitis,
        isBasarili: true,
      );
    }

    // =========================================================================
    // TÜM BİRİMLER BİTTİĞİNDE 9 SENARYOLU KAPSAMLI DENETİM VE RAPORLAMA
    // =========================================================================
    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🔍 Tüm birimler okundu. 9 Senaryolu Çapraz Denetim ve Mutabakat Motoru çalıştırılıyor...',
      ilerlemeYuzdesi: 0.95,
    );

    final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
      yil: yil,
      ay: ay,
      birimSonuclari: analizSonuclari,
      toplamDosyaSayisi: toplamDosya,
      birimOncekiAylarHasilat: birimOncekiAylarHasilat,
      oncekiAydanDevredenKdv: oncekiAydanDevredenKdv,
    );

    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🎉 Analiz ve Denetim Tamamlandı! ${rapor.analizEdilenBirimler.length} birim incelendi, ${rapor.denetimKontrolleri.length} mutabakat testi yapıldı (${rapor.kritikHataSayisi} Kritik Hata, ${rapor.uyariSayisi} İnceleme Uyarısı).',
      ilerlemeYuzdesi: 1.0,
      isBasarili: true,
    );

    onTamamlandi(rapor);
  }

  /// OpenRouter / OpenAI uyumlu REST API çağrısı
  Future<String?> _runOpenRouter({
    required String apiUrl,
    required String apiKey,
    required String modelName,
    required String prompt,
  }) async {
    final cleanUrl = apiUrl.trim().isEmpty
        ? 'https://openrouter.ai/api/v1'
        : apiUrl.trim();
    final base = cleanUrl.endsWith('/')
        ? cleanUrl.substring(0, cleanUrl.length - 1)
        : cleanUrl;
    final endpoint = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';
    final resolvedModel = modelName.trim().isEmpty
        ? 'google/gemini-2.0-flash-001'
        : modelName.trim();

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://dsys.local',
        'X-Title': 'DSYS Beyanname',
      },
      body: jsonEncode({
        'model': resolvedModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final first = choices.first as Map<String, dynamic>;
          final msg = first['message'] as Map<String, dynamic>?;
          return msg?['content']?.toString();
        }
      }
    } else {
      throw Exception('OpenRouter Hatası (${response.statusCode}): ${response.body}');
    }
    return null;
  }

  /// Birincil olarak Google Gemini (tanımlıysa), yoksa veya hata verirse OpenRouter çalıştırır
  Future<String?> _calistirAiModel({
    required SistemAyarlariModel ayarlar,
    required String prompt,
    List<Part>? geminiParts,
  }) async {
    Object? sonHata;

    // 1. İLK TERCİH: Google Gemini Tanımlıysa Önce Onu Çağır (Fatura modülüyle aynı kurumsal standart)
    if (ayarlar.geminiApiKey.trim().isNotEmpty) {
      try {
        final parts = geminiParts ?? [TextPart(prompt)];
        final text = await _runGeminiWithFallback(
          apiKey: ayarlar.geminiApiKey,
          preferredModel: ayarlar.geminiModel,
          parts: parts,
        );
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (e) {
        sonHata = e;
        debugPrint('[Beyanname AI] Gemini çağrısı hata verdi: $e');
        if (ayarlar.deepseekApiKey.trim().isEmpty) rethrow;
      }
    }

    // 2. YEDEK HAT: Gemini başarısız olduysa veya anahtarı yoksa OpenRouter devreye girer
    if (ayarlar.deepseekApiKey.trim().isNotEmpty) {
      try {
        debugPrint('[Beyanname AI] Gemini yanıt vermedi, OpenRouter yedeğine geçiliyor...');
        final text = await _runOpenRouter(
          apiUrl: ayarlar.deepseekApiUrl,
          apiKey: ayarlar.deepseekApiKey,
          modelName: ayarlar.deepseekModel,
          prompt: prompt,
        );
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (e) {
        sonHata = e;
        debugPrint('[Beyanname AI] OpenRouter çağrısı da hata verdi: $e');
        rethrow;
      }
    }

    if (sonHata != null) throw Exception(sonHata.toString());
    return null;
  }

  /// Gemini API'ye model fallback ve retry zinciri ile istek gönderir.
  Future<String?> _runGeminiWithFallback({
    required String apiKey,
    required List<Part> parts,
    String? preferredModel,
  }) async {
    final modelOrder = <String>[];
    String? cleanPreferred = preferredModel?.trim();
    if (cleanPreferred == null ||
        cleanPreferred.isEmpty ||
        cleanPreferred == 'gemini-flash-latest' ||
        cleanPreferred == 'gemini-2.5-flash' ||
        cleanPreferred == 'gemini-2.0-flash' ||
        cleanPreferred == 'gemini-1.5-flash') {
      cleanPreferred = 'gemini-3.8-flash';
    }

    // Kural: 3.8'den başlasın, cevap gelmezse 3.6'ya geçsin
    if (cleanPreferred == 'gemini-3.8-flash' || cleanPreferred == 'gemini-3.6-flash') {
      modelOrder.add('gemini-3.8-flash');
      modelOrder.add('gemini-3.6-flash');
    } else {
      modelOrder.add(cleanPreferred);
      if (!modelOrder.contains('gemini-3.8-flash')) modelOrder.add('gemini-3.8-flash');
      if (!modelOrder.contains('gemini-3.6-flash')) modelOrder.add('gemini-3.6-flash');
    }

    for (final m in _geminiModelFallbacks) {
      if (!modelOrder.contains(m)) modelOrder.add(m);
    }

    final hasMedia = parts.any((p) => p is DataPart);
    final modelTimeout = Duration(seconds: hasMedia ? 180 : 60);

    Object? sonHata;
    for (final modelName in modelOrder) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model
              .generateContent([Content.multi(parts)])
              .timeout(modelTimeout);
          final text = response.text?.trim() ?? '';
          if (text.isNotEmpty) return text;
          break;
        } catch (e) {
          sonHata = e;
          final err = e.toString();
          final is503 = err.contains('503') ||
              err.contains('UNAVAILABLE') ||
              err.contains('high demand') ||
              err.contains('overloaded');
          if (is503 && attempt == 0) {
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (sonHata != null) throw Exception(sonHata.toString());
    return null;
  }

  /// JSON metnini güvenli temizleyip ayrıştırır
  Map<String, dynamic>? _parseCleanJson(String raw) {
    var cleaned = raw.trim();

    // Markdown ```json ... ``` bloğu varsa çıkar
    final mdMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(cleaned);
    if (mdMatch != null) {
      cleaned = mdMatch.group(1)!.trim();
    } else {
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    // Trailing comma temizliği: , } veya , ] -> } veya ]
    cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Regex ile ilk { ... } bloğunu bulmayı dene
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        try {
          var block = match.group(0)!;
          block = block.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
          final decoded = jsonDecode(block);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Katı Türk Kamu Döner Sermaye Mizan Promptu
  String _buildMizanPrompt({
    required String birimAdi,
    required int yil,
    required int ay,
    required String aylikMizanMetni,
    required String yardimciMizanMetni,
    required String yillikMizanMetni,
    required String digerBelgeMetni,
  }) {
    return '''
Sen Türkiye Cumhuriyeti Üniversiteleri Döner Sermaye İşletmeleri konusunda uzmanlaşmış kıdemli bir Mali Müşavir ve Beyanname Hazırlama Yapay Zeka Ajanısın.

GÖREV:
Aşağıda verilen "$birimAdi" birimine ait $yil yılı ${ay.toString().padLeft(2, '0')}. ay belgelerini (Aylık Mizan, Yardımcı Mizan / Muavin, Yıllık Kümülatif Mizan ve Ek Belgeler) incele.
Belgelerdeki muhasebe hesap kodlarından KDV 1, Damga Vergisi, 600 Hasılat ve 123 Kredi Kartı beyanname verilerini hatasız ve kuruşu kuruşuna çıkar.

ARANACAK HESAP KODLARI VE KURALLAR:
1. 600 HESABI (YURT İÇİ GELİRLER / HASILAT):
   - Aylık Mizandan: Sadece bu ayın 600 alacak hareketini veya dönem net gelirini bul -> "hasilat600Aylik"
   - Yıllık Mizandan: Yıl başından bu aya kadar olan kümülatif 600 alacak bakiyesini bul -> "hasilat600Kumulatif"
2. 123 HESABI (KREDİ KARTI / POS TAHSİLATLARI):
   - POS ile yapılan satış ve tahsilatların bu ayki borç tutarı (GİB Satır 45) -> "krediKarti123"
3. 391 HESABI (HESAPLANAN KDV):
   - %20 KDV oranı için Matrah ve KDV tutarını ayır: "hesaplananKdvMatrah20", "hesaplananKdv20"
   - %10 KDV oranı için Matrah ve KDV tutarını ayır: "hesaplananKdvMatrah10", "hesaplananKdv10"
4. 191 HESABI (İNDİRİLECEK KDV):
   - Mal ve hizmet alımlarında ödenen indirilecek KDV:
   - "indirilecekKdvMatrah20", "indirilecekKdv20"
   - "indirilecekKdvMatrah10", "indirilecekKdv10"
5. 360.03.05 HESABI (DAMGA VERGİSİ):
   - Hakediş ve ödemelerden kesilen Damga Vergisi tutarı (alacak kalanı): "damgaVergisi360"
   - Matrah (Damga / 0.00948): "damgaMatrah"
6. 190 HESABI (DEVREDEN KDV):
   - Mizanda devreden KDV borç kalanı varsa: "devredenKdv190"
7. TERS BAKİYE KONTROLLERİ:
   - 191 hesabı alacak bakiyesi veriyor mu? -> "is191TersBakiye": true/false
   - 391 hesabı borç bakiyesi veriyor mu? -> "is391TersBakiye": true/false
   - 600 hesabı borç bakiyesi veriyor mu? -> "is600TersBakiye": true/false
8. TEVKİFATLI FATURALAR VE BELGE-MİZAN MUTABAKATI:
   - Ekli belgelerde/görsellerde (taranmış veya dijital) yer alan faturaları incele. Tevkifatlı olanları tespit et.
   - Eğer fatura mevcut ancak mizandaki 600/391 hesaplarına henüz yansımamışsa veya tutarlar arasında mutabakatsızlık varsa "aciklama" alanına açıkça yaz (Örn: "X firmasına ait Y TL tevkifatlı fatura mizana henüz yansımamış").
9. YARDIMCI MİZAN (MUAVİN / ALT HESAP MİZANI) MUTABAKATI:
   - Eğer Yardımcı Mizan (Muavin) yüklenmişse; 391.20, 391.10 (%20 ve %10 KDV), 191.20, 191.10 ve 600 alt gelir kodlarını buradan kuruşu kuruşuna teyit et.
   - Yardımcı mizan alt toplamları ile Ana Mizan bakiyelerini karşılaştır. Fark varsa "aciklama" alanına yaz.
   - "yardimciMizanKullanildi": true/false,
   - "yardimciMizan391Toplam": 0.0,
   - "yardimciMizan191Toplam": 0.0,
   - "yardimciMizan600Toplam": 0.0

ÇIKTI FORMATI:
SADECE VE SADECE aşağıdaki JSON formatında bir nesne döndür (Markdown backtick dışında hiçbir açıklama veya ek yazı yazma):
{
  "hasilat600Aylik": 0.0,
  "hasilat600Kumulatif": 0.0,
  "krediKarti123": 0.0,
  "hesaplananKdvMatrah20": 0.0,
  "hesaplananKdv20": 0.0,
  "hesaplananKdvMatrah10": 0.0,
  "hesaplananKdv10": 0.0,
  "indirilecekKdvMatrah20": 0.0,
  "indirilecekKdv20": 0.0,
  "indirilecekKdvMatrah10": 0.0,
  "indirilecekKdv10": 0.0,
  "damgaVergisi360": 0.0,
  "damgaMatrah": 0.0,
  "muhtasarGelir360": 0.0,
  "muhtasarDamga360": 0.0,
  "devredenKdv190": 0.0,
  "is191TersBakiye": false,
  "is391TersBakiye": false,
  "is600TersBakiye": false,
  "yardimciMizanKullanildi": false,
  "yardimciMizan391Toplam": 0.0,
  "yardimciMizan191Toplam": 0.0,
  "yardimciMizan600Toplam": 0.0,
  "tevkifatFaturalari": [],
  "aciklama": ""
}

---
AYLIK MİZAN METNİ:
$aylikMizanMetni

---
YARDIMCI MİZAN (MUAVİN) METNİ:
$yardimciMizanMetni

---
YILLIK KÜMÜLATİF MİZAN METNİ:
$yillikMizanMetni

---
DİĞER BELGELER METNİ:
$digerBelgeMetni
''';
  }
}
