import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../models/sablon_model.dart';

class SablonService {
  final CollectionReference _sablonlarRef = FirebaseFirestore.instance.collection('sistemSablonlari');
  final Reference _storageRef = FirebaseStorage.instance.ref().child('templates');

  Future<List<SablonModel>> getAllSablonlar() async {
    final querySnapshot = await _sablonlarRef.orderBy('eklenmeTarihi', descending: true).get();
    return querySnapshot.docs.map((doc) => SablonModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<void> addSablon(String sablonAdi, String tur, html.File file) async {
    try {
      final String safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final fileRef = _storageRef.child(safeFileName);
      
      // Upload file to Firebase Storage
      final uploadTask = fileRef.putBlob(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final dosyaUzantisi = file.name.contains('.') ? '.${file.name.split('.').last}' : '';

      final sablon = SablonModel(
        id: '',
        sablonAdi: sablonAdi,
        dosyaUzantisi: dosyaUzantisi,
        dosyaUrl: downloadUrl,
        tur: tur,
        eklenmeTarihi: DateTime.now(),
      );

      await _sablonlarRef.add(sablon.toJson());
    } catch (e) {
      debugPrint('[SablonService.addSablon] Hata: $e');
      rethrow;
    }
  }

  Future<void> deleteSablon(SablonModel sablon) async {
    try {
      // Önce Storage'dan silmeye çalış
      if (sablon.dosyaUrl.isNotEmpty) {
        final ref = FirebaseStorage.instance.refFromURL(sablon.dosyaUrl);
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Storage silinirken hata (belki dosya zaten yok): $e');
    }

    // Sonra Firestore'dan sil
    await _sablonlarRef.doc(sablon.id).delete();
  }
}
