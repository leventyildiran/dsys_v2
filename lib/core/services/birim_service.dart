import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/birim_model.dart';
import 'firestore_service.dart';

class BirimService {
  BirimService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'birimler';

  CollectionReference<Map<String, dynamic>> get _birimRef =>
      _service.collection(_collection);

  /// Returns a list of all BirimModel objects.
  Future<List<BirimModel>> getAll({bool onlyActive = true}) async {
    final query = onlyActive
        ? _birimRef.where('aktif', isEqualTo: true)
        : _birimRef;
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => BirimModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Real‑time stream of Birim models.
  Stream<List<BirimModel>> stream({bool onlyActive = true}) {
    final query = onlyActive
        ? _birimRef.where('aktif', isEqualTo: true)
        : _birimRef;
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => BirimModel.fromJson(doc.data(), doc.id))
          .toList(),
    );
  }

  /// Add a new birim.
  Future<String> addBirim({required String ad, bool aktif = true}) async {
    final docRef = await _birimRef.add({'ad': ad, 'aktif': aktif});
    return docRef.id;
  }

  /// Update an existing birim.
  Future<void> updateBirim(String id, {String? ad, bool? aktif}) async {
    final data = <String, dynamic>{};
    if (ad != null) data['ad'] = ad;
    if (aktif != null) data['aktif'] = aktif;
    await _birimRef.doc(id).update(data);
  }

  /// Delete a birim.
  Future<void> deleteBirim(String id) async {
    await _birimRef.doc(id).delete();
  }
}
