import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sistem_ayarlari_model.dart';

class SistemAyarlariService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _docId = 'sistem_genel';

  Future<SistemAyarlariModel> getAyarlar() async {
    try {
      final doc = await _firestore.collection('ayarlar').doc(_docId).get();
      if (doc.exists && doc.data() != null) {
        return SistemAyarlariModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Ayarlar okunamadı: $e');
    }
    return SistemAyarlariModel.empty();
  }

  Future<void> saveAyarlar(SistemAyarlariModel ayarlar) async {
    try {
      await _firestore.collection('ayarlar').doc(_docId).set(ayarlar.toJson());
    } catch (e) {
      print('Ayarlar kaydedilemedi: $e');
      rethrow;
    }
  }
}
