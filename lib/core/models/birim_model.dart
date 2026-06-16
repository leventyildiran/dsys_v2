import 'package:cloud_firestore/cloud_firestore.dart';

class BirimModel {
  final String id;
  final String ad;
  final bool aktif;

  BirimModel({
    required this.id,
    required this.ad,
    this.aktif = true,
  });

  factory BirimModel.fromJson(Map<String, dynamic> json, String documentId) {
    return BirimModel(
      id: documentId,
      ad: json['ad'] ?? '',
      aktif: json['aktif'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ad': ad,
      'aktif': aktif,
    };
  }
}
