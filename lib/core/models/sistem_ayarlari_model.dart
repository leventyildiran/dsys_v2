class SistemAyarlariModel {
  final String hesapAdi;
  final String iban;
  final String geminiApiKey;
  final String deepseekApiUrl;
  final String deepseekApiKey;
  final String deepseekModel;

  SistemAyarlariModel({
    required this.hesapAdi,
    required this.iban,
    required this.geminiApiKey,
    required this.deepseekApiUrl,
    required this.deepseekApiKey,
    required this.deepseekModel,
  });

  factory SistemAyarlariModel.fromJson(Map<String, dynamic> json) {
    return SistemAyarlariModel(
      hesapAdi: json['hesapAdi'] ?? '',
      iban: json['iban'] ?? '',
      geminiApiKey: json['geminiApiKey'] ?? '',
      deepseekApiUrl: json['deepseekApiUrl'] ?? '',
      deepseekApiKey: json['deepseekApiKey'] ?? '',
      deepseekModel: json['deepseekModel'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hesapAdi': hesapAdi,
      'iban': iban,
      'geminiApiKey': geminiApiKey,
      'deepseekApiUrl': deepseekApiUrl,
      'deepseekApiKey': deepseekApiKey,
      'deepseekModel': deepseekModel,
    };
  }

  factory SistemAyarlariModel.empty() {
    return SistemAyarlariModel(
      hesapAdi: '',
      iban: '',
      geminiApiKey: '',
      deepseekApiUrl: '',
      deepseekApiKey: '',
      deepseekModel: '',
    );
  }
}
