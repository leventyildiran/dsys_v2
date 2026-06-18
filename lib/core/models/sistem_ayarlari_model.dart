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

class SistemAyarlariModel {
  final String hesapAdi;
  final String iban;
  /// Döner sermaye işletme VKN — fatura hesap adı alt satırı için.
  final String isletmeVkn;
  final String geminiApiKey;
  /// Taranmış PDF için Gemini düşünce devreye giren Google Cloud Vision OCR anahtarı.
  final String visionApiKey;
  final String deepseekApiUrl;
  final String deepseekApiKey;
  final String deepseekModel;
  final List<YkUyeModel> kurulUyeleri;

  SistemAyarlariModel({
    required this.hesapAdi,
    required this.iban,
    this.isletmeVkn = '',
    required this.geminiApiKey,
    this.visionApiKey = '',
    required this.deepseekApiUrl,
    required this.deepseekApiKey,
    required this.deepseekModel,
    this.kurulUyeleri = const [],
  });

  factory SistemAyarlariModel.fromJson(Map<String, dynamic> json) {
    return SistemAyarlariModel(
      hesapAdi: json['hesapAdi'] ?? '',
      iban: json['iban'] ?? '',
      isletmeVkn: json['isletmeVkn']?.toString() ?? '',
      geminiApiKey: json['geminiApiKey'] ?? '',
      visionApiKey: json['visionApiKey']?.toString() ?? '',
      deepseekApiUrl: json['deepseekApiUrl'] ?? '',
      deepseekApiKey: json['deepseekApiKey'] ?? '',
      deepseekModel: json['deepseekModel'] ?? '',
      kurulUyeleri: (json['kurulUyeleri'] as List<dynamic>?)
              ?.map((e) => YkUyeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hesapAdi': hesapAdi,
      'iban': iban,
      'isletmeVkn': isletmeVkn,
      'geminiApiKey': geminiApiKey,
      'visionApiKey': visionApiKey,
      'deepseekApiUrl': deepseekApiUrl,
      'deepseekApiKey': deepseekApiKey,
      'deepseekModel': deepseekModel,
      'kurulUyeleri': kurulUyeleri.map((e) => e.toJson()).toList(),
    };
  }

  factory SistemAyarlariModel.empty() {
    return SistemAyarlariModel(
      hesapAdi: '',
      iban: '',
      isletmeVkn: '',
      geminiApiKey: '',
      visionApiKey: '',
      deepseekApiUrl: '',
      deepseekApiKey: '',
      deepseekModel: '',
      kurulUyeleri: [],
    );
  }
}
