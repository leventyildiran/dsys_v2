import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// YK Karar Merkezi için PDF belgelerini arşive yükler.
  /// [pdfBytes]: Yüklenecek dosya verisi
  /// [birimId]: Hangi birime ait olduğu
  /// [fileName]: Dosya adı (örnek: karar_123.pdf)
  Future<String> uploadYkKararPdf(
    Uint8List pdfBytes,
    String birimId,
    String fileName,
  ) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = 'yk_karar_arsiv/$birimId/${timestamp}_$fileName';

      final Reference ref = _storage.ref().child(path);

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'birimId': birimId,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putData(pdfBytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('PDF yükleme hatası: $e');
      throw Exception('PDF arşive yüklenemedi: $e');
    }
  }
}
