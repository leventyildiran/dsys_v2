import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tek bir Gemini çağrısının sonucu ve ölçülen maliyeti.
class GeminiOkumaYaniti {
  final String metin;
  final String model;
  final int girdiToken;
  final int ciktiToken;
  final int dusunceToken;
  final double maliyetTl;

  const GeminiOkumaYaniti({
    required this.metin,
    required this.model,
    required this.girdiToken,
    required this.ciktiToken,
    required this.dusunceToken,
    required this.maliyetTl,
  });

  int get toplamToken => girdiToken + ciktiToken + dusunceToken;
}

/// Fatura okuma için MALİYET KONTROLLÜ Gemini istemcisi (REST).
///
/// Neden ayrı istemci?
/// - Eski zincir hata durumunda aynı belgeyi Pro modellerine de gönderiyordu
///   (fatura başına 5-10 TL'nin ana kaynağı).
/// - `google_generative_ai` paketi "thinking" bütçesini kapatmaya izin vermiyor;
///   2.5+ Flash modellerinde düşünme token'ları çıktı fiyatından faturalanır.
///
/// Kurallar:
/// 1. Yalnızca Flash ailesi. Adında `pro` geçen model ASLA çağrılmaz.
/// 2. `thinkingBudget: 0` (desteklemeyen modelde otomatik olarak çıkarılır).
/// 3. temperature 0 + JSON çıktı → kısa, deterministik yanıt.
/// 4. Her çağrının token kullanımı `usageMetadata`'dan okunur ve TL'ye çevrilir.
class FaturaGeminiOkuyucu {
  FaturaGeminiOkuyucu({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Tahmini kur (yalnızca terminalde maliyet göstermek için).
  static const double usdTlKuru = 42.0;

  /// Tercih edilen model başarısız olursa denenecek ucuz modeller (sırayla).
  static const List<String> yedekFlashModeller = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const int _maksModelDenemesi = 3;

  /// Adında `pro` geçen veya flash ailesinden olmayan modeli eler.
  static bool ucuzModelMi(String model) {
    final m = model.toLowerCase().trim();
    if (m.isEmpty) return false;
    if (m.contains('pro')) return false;
    return m.contains('flash');
  }

  /// Denenecek model sırası (tekrarsız, en fazla [_maksModelDenemesi]).
  static List<String> modelSirasi(String? tercihModel) {
    final sira = <String>[];
    final tercih = tercihModel?.trim() ?? '';
    if (ucuzModelMi(tercih)) sira.add(tercih);
    for (final m in yedekFlashModeller) {
      if (!sira.contains(m)) sira.add(m);
    }
    return sira.take(_maksModelDenemesi).toList();
  }

  /// USD / 1M token (girdi, çıktı). Düşünme token'ları çıktı fiyatındandır.
  static (double, double) fiyatTablosu(String model) {
    final m = model.toLowerCase();
    if (m.contains('lite')) return (0.10, 0.40);
    if (m.contains('2.0-flash')) return (0.10, 0.40);
    if (m.contains('1.5-flash')) return (0.075, 0.30);
    return (0.30, 2.50); // 2.5+ flash ve bilinmeyen flash sürümleri
  }

  static double maliyetHesapla({
    required String model,
    required int girdi,
    required int cikti,
    required int dusunce,
  }) {
    final (g, c) = fiyatTablosu(model);
    final usd = (girdi * g + (cikti + dusunce) * c) / 1000000.0;
    return usd * usdTlKuru;
  }

  /// [prompt] metnini (ve yalnızca gerekiyorsa [pdf] baytlarını) gönderir.
  ///
  /// [log] terminale satır yazmak için kullanılır.
  Future<GeminiOkumaYaniti> oku({
    required String apiKey,
    required String prompt,
    String? tercihModel,
    Uint8List? pdf,
    void Function(String mesaj, {bool uyari})? log,
    void Function()? iptalKontrol,
  }) async {
    final client = _client ?? http.Client();
    final sira = modelSirasi(tercihModel);
    final hasPdf = pdf != null && pdf.isNotEmpty;
    final timeout = Duration(seconds: hasPdf ? 120 : 45);
    Object? sonHata;

    try {
      for (final model in sira) {
        iptalKontrol?.call();
        var dusunmeKapat = true;
        for (var deneme = 0; deneme < 3; deneme++) {
          try {
            log?.call('   ↳ $model çağrılıyor${hasPdf ? ' (taranmış belge, görsel mod)' : ' (yalnızca metin)'}…');
            final yanit = await _istek(
              client: client,
              apiKey: apiKey,
              model: model,
              prompt: prompt,
              pdf: hasPdf ? pdf : null,
              dusunmeKapat: dusunmeKapat,
            ).timeout(timeout);
            if (yanit.metin.trim().isNotEmpty) return yanit;
            sonHata = '$model boş yanıt döndü';
            break;
          } on _GeminiHttpHatasi catch (e) {
            sonHata = e;
            if (e.kod == 400 && dusunmeKapat && e.govde.toLowerCase().contains('think')) {
              dusunmeKapat = false; // Bu model thinkingConfig desteklemiyor
              continue;
            }
            if (e.kod == 503 && deneme == 0) {
              log?.call('   ↳ $model yoğun (503), 2 sn sonra tekrar…', uyari: true);
              await Future.delayed(const Duration(seconds: 2));
              continue;
            }
            if (e.kod == 429) {
              log?.call('   ↳ $model kotası dolu (429) — ücretsiz kota modele özeldir, sonraki model deneniyor.', uyari: true);
            } else if (e.kod == 404) {
              log?.call('   ↳ $model bu anahtarla erişilebilir değil (404).', uyari: true);
            } else {
              log?.call('   ↳ $model hata ${e.kod}: ${e.kisaMesaj}', uyari: true);
            }
            break;
          } on TimeoutException {
            sonHata = '$model ${timeout.inSeconds} sn içinde yanıt vermedi';
            log?.call('   ↳ $model zaman aşımı.', uyari: true);
            break;
          }
        }
      }
    } finally {
      if (_client == null) client.close();
    }

    if (sonHata is _GeminiHttpHatasi) {
      final e = sonHata;
      if (e.kod == 429) {
        throw Exception(
          'Ücretsiz API kotası doldu (429). Birkaç dakika sonra tekrar deneyin '
          'veya Sistem Ayarlarından faturalandırmayı açın.',
        );
      }
      if (e.kod == 400 && e.govde.contains('API_KEY')) {
        throw Exception('API anahtarı geçersiz. Sistem Ayarlarını kontrol edin.');
      }
    }
    throw Exception('Okuma servisi yanıt vermedi: $sonHata');
  }

  Future<GeminiOkumaYaniti> _istek({
    required http.Client client,
    required String apiKey,
    required String model,
    required String prompt,
    required Uint8List? pdf,
    required bool dusunmeKapat,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${Uri.encodeComponent(model)}:generateContent',
    );
    final parts = <Map<String, dynamic>>[
      if (pdf != null)
        {
          'inline_data': {
            'mime_type': 'application/pdf',
            'data': base64Encode(pdf),
          },
        },
      {'text': prompt},
    ];
    final body = {
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'maxOutputTokens': 16384,
        if (dusunmeKapat) 'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'x-goog-api-key': apiKey.trim(),
      },
      body: jsonEncode(body),
    );
    final govde = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _GeminiHttpHatasi(res.statusCode, govde);
    }

    final json = jsonDecode(govde) as Map<String, dynamic>;
    final adaylar = json['candidates'] as List<dynamic>? ?? const [];
    final buffer = StringBuffer();
    if (adaylar.isNotEmpty) {
      final content = (adaylar.first as Map<String, dynamic>)['content'];
      final parcalar = (content is Map ? content['parts'] : null) as List<dynamic>? ?? const [];
      for (final p in parcalar) {
        if (p is Map && p['thought'] == true) continue;
        final t = p is Map ? p['text'] : null;
        if (t is String) buffer.write(t);
      }
    }

    final usage = json['usageMetadata'] as Map<String, dynamic>? ?? const {};
    int sayi(String k) => (usage[k] as num?)?.toInt() ?? 0;
    final girdi = sayi('promptTokenCount');
    final cikti = sayi('candidatesTokenCount');
    final dusunce = sayi('thoughtsTokenCount');

    return GeminiOkumaYaniti(
      metin: buffer.toString(),
      model: model,
      girdiToken: girdi,
      ciktiToken: cikti,
      dusunceToken: dusunce,
      maliyetTl: maliyetHesapla(
        model: model,
        girdi: girdi,
        cikti: cikti,
        dusunce: dusunce,
      ),
    );
  }
}

class _GeminiHttpHatasi implements Exception {
  _GeminiHttpHatasi(this.kod, this.govde);
  final int kod;
  final String govde;

  String get kisaMesaj {
    try {
      final j = jsonDecode(govde);
      if (j is Map) {
        final err = j['error'];
        if (err is Map) {
          final m = err['message'];
          if (m is String && m.isNotEmpty) {
            return m.length > 140 ? '${m.substring(0, 140)}…' : m;
          }
        }
      }
    } catch (_) {}
    return govde.length > 140 ? '${govde.substring(0, 140)}…' : govde;
  }

  @override
  String toString() => 'HTTP $kod: $kisaMesaj';
}
