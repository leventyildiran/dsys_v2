import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/batch_fatura_provider.dart';

class FaturaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveFatura(FaturaModel fatura) async {
    try {
      await _firestore.collection('faturalar').add({
        ...fatura.toMap(),
        'sistemeKayitTarihi': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Fatura kaydedilirken bir hata oluştu: $e');
    }
  }

  // Gelecekte fatura listeleme, silme vb. işlemleri de buraya eklenebilir
}
