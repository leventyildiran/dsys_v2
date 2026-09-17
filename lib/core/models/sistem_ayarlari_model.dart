class YkUyeModel {
  final String gorev;
  final String adSoyad;

  YkUyeModel({required this.gorev, required this.adSoyad});

  factory YkUyeModel.fromJson(Map<String, dynamic> json) {
    return YkUyeModel(
      gorev: json['gorev'] ?? '',
      adSoyad: json['adSoyad'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gorev': gorev,
      'adSoyad': adSoyad,
    };
  }
}

const _defaultUnvanlar = <String, double>{
  'Prof. Dr.': 3.0,
  'Doç. Dr.': 2.5,
  'Dr. Öğr. Üyesi': 2.0,
  'Arş. Gör.': 1.0,
  'Öğr. Görevlisi': 1.0,
  'Bilgisayar İşletmeni': 1.0,
  'Memur': 1.0,
  'Sürekli İşçi': 1.0,
  'Diğer': 1.0,
};

class SistemAyarlariModel {
  final String kurumAdi;
  final String hesapAdi;
  final String iban;
  /// Döner sermaye işletme VKN — fatura hesap adı alt satırı için.
  final String isletmeVkn;
  final double varsayilanKdvOrani;
  final String ebysDomain;
  final String geminiApiKey;
  /// Tercih edilen Gemini modeli (örn. 'gemini-2.5-flash', 'gemini-2.0-flash').
  final String geminiModel;
  /// Taranmış PDF için Gemini düşünce devreye giren Google Cloud Vision OCR anahtarı.
  final String visionApiKey;
  final String deepseekApiUrl;
  final String deepseekApiKey;
  final String deepseekModel;
  final List<YkUyeModel> kurulUyeleri;
  final Map<String, double> unvanKatsayilari;

  SistemAyarlariModel({
    this.kurumAdi = 'Uşak Üniversitesi',
    required this.hesapAdi,
    required this.iban,
    this.isletmeVkn = '',
    this.varsayilanKdvOrani = 20.0,
    this.ebysDomain = 'usak.local',
    required this.geminiApiKey,
    this.geminiModel = 'gemini-3.6-flash',
    this.visionApiKey = '',
    required this.deepseekApiUrl,
    required this.deepseekApiKey,
    required this.deepseekModel,
    this.kurulUyeleri = const [],
    this.unvanKatsayilari = _defaultUnvanlar,
  });

  factory SistemAyarlariModel.fromJson(Map<String, dynamic> json) {
    final rawGeminiModel = json['geminiModel']?.toString().trim() ?? '';
    final rawKurumAdi = json['kurumAdi']?.toString().trim() ?? '';
    final rawEbysDomain = json['ebysDomain']?.toString().trim() ?? '';
    String resolvedModel = rawGeminiModel;
    if (resolvedModel.isEmpty ||
        resolvedModel == 'gemini-flash-latest' ||
        resolvedModel == 'gemini-2.5-flash' ||
        resolvedModel == 'gemini-2.0-flash' ||
        resolvedModel == 'gemini-1.5-flash') {
      resolvedModel = 'gemini-3.6-flash';
    }
    return SistemAyarlariModel(
      kurumAdi: rawKurumAdi.isNotEmpty ? rawKurumAdi : 'Uşak Üniversitesi',
      hesapAdi: json['hesapAdi'] ?? '',
      iban: json['iban'] ?? '',
      isletmeVkn: json['isletmeVkn']?.toString() ?? '',
      varsayilanKdvOrani: (json['varsayilanKdvOrani'] as num?)?.toDouble() ?? 20.0,
      ebysDomain: rawEbysDomain.isNotEmpty ? rawEbysDomain : 'usak.local',
      geminiApiKey: json['geminiApiKey'] ?? '',
      geminiModel: resolvedModel,
      visionApiKey: json['visionApiKey']?.toString() ?? '',
      deepseekApiUrl: json['deepseekApiUrl'] ?? '',
      deepseekApiKey: json['deepseekApiKey'] ?? '',
      deepseekModel: json['deepseekModel'] ?? '',
      kurulUyeleri: (json['kurulUyeleri'] as List<dynamic>?)
              ?.map((e) => YkUyeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unvanKatsayilari: json['unvanKatsayilari'] != null
          ? Map<String, double>.from(
              (json['unvanKatsayilari'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            )
          : _defaultUnvanlar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kurumAdi': kurumAdi,
      'hesapAdi': hesapAdi,
      'iban': iban,
      'isletmeVkn': isletmeVkn,
      'varsayilanKdvOrani': varsayilanKdvOrani,
      'ebysDomain': ebysDomain,
      'geminiApiKey': geminiApiKey,
      'geminiModel': geminiModel,
      'visionApiKey': visionApiKey,
      'deepseekApiUrl': deepseekApiUrl,
      'deepseekApiKey': deepseekApiKey,
      'deepseekModel': deepseekModel,
      'kurulUyeleri': kurulUyeleri.map((e) => e.toJson()).toList(),
      'unvanKatsayilari': unvanKatsayilari,
    };
  }

  factory SistemAyarlariModel.empty() {
    return SistemAyarlariModel(
      kurumAdi: 'Uşak Üniversitesi',
      hesapAdi: '',
      iban: '',
      isletmeVkn: '',
      varsayilanKdvOrani: 20.0,
      ebysDomain: 'usak.local',
      geminiApiKey: '',
      geminiModel: 'gemini-3.6-flash',
      visionApiKey: '',
      deepseekApiUrl: '',
      deepseekApiKey: '',
      deepseekModel: '',
      kurulUyeleri: [],
      unvanKatsayilari: _defaultUnvanlar,
    );
  }
}
