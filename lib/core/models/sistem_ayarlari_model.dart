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
  final Map<String, double> unvanKatsayilari;

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
    this.unvanKatsayilari = _defaultUnvanlar,
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
      'hesapAdi': hesapAdi,
      'iban': iban,
      'isletmeVkn': isletmeVkn,
      'geminiApiKey': geminiApiKey,
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
      hesapAdi: '',
      iban: '',
      isletmeVkn: '',
      geminiApiKey: '',
      visionApiKey: '',
      deepseekApiUrl: '',
      deepseekApiKey: '',
      deepseekModel: '',
      kurulUyeleri: [],
      unvanKatsayilari: _defaultUnvanlar,
    );
  }
}
