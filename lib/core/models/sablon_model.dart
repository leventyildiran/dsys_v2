import 'package:cloud_firestore/cloud_firestore.dart';

class SablonModel {
  String id;
  String sablonAdi;
  String dosyaUzantisi; // '.docx', '.xlsx' vs.
  String dosyaUrl;
  String tur; // 'fatura', 'yk_karar', 'gundem', 'diger'
  DateTime eklenmeTarihi;
  String? birimId;
  String? birimAd;

  SablonModel({
    required this.id,
    required this.sablonAdi,
    required this.dosyaUzantisi,
    required this.dosyaUrl,
    required this.tur,
    required this.eklenmeTarihi,
    this.birimId,
    this.birimAd,
  });

  factory SablonModel.fromJson(Map<String, dynamic> json, String documentId) {
    return SablonModel(
      id: documentId,
      sablonAdi: json['sablonAdi'] ?? '',
      dosyaUzantisi: json['dosyaUzantisi'] ?? '',
      dosyaUrl: json['dosyaUrl'] ?? '',
      tur: json['tur'] ?? 'diger',
      eklenmeTarihi: json['eklenmeTarihi'] != null 
          ? (json['eklenmeTarihi'] as Timestamp).toDate() 
          : DateTime.now(),
      birimId: json['birimId'],
      birimAd: json['birimAd'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sablonAdi': sablonAdi,
      'dosyaUzantisi': dosyaUzantisi,
      'dosyaUrl': dosyaUrl,
      'tur': tur,
      'eklenmeTarihi': Timestamp.fromDate(eklenmeTarihi),
      'birimId': birimId,
      'birimAd': birimAd,
    };
  }
}
