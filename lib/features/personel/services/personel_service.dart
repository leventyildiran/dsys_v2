import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firestore_service.dart';
import '../models/personel_model.dart';

class PersonelService {
  PersonelService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'personel';

  CollectionReference<Map<String, dynamic>> get _personelRef =>
      _service.collection(_collection);

  Future<List<PersonelModel>> getAll({bool sadeceAktif = true}) async {
    try {
      final snapshot = await _personelRef.get();
      final list = snapshot.docs
          .map((doc) => PersonelModel.fromMap(doc.id, doc.data()))
          .where((p) => !sadeceAktif || p.aktif)
          .toList();
      list.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
      return list;
    } catch (e) {
      debugPrint('[PersonelService.getAll] Hata: $e');
      return [];
    }
  }

  Future<List<PersonelModel>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    final list = await getAll();
    if (normalized.isEmpty) return list;
    return list.where((p) {
      return p.adSoyad.toLowerCase().contains(normalized) ||
          p.unvan.toLowerCase().contains(normalized) ||
          p.tcKimlikNo.contains(normalized);
    }).toList();
  }

  Future<PersonelModel> add(PersonelModel personel) async {
    final doc = _personelRef.doc();
    final data = personel.toMap();
    data['id'] = doc.id;
    await doc.set(data);
    return PersonelModel.fromMap(doc.id, data);
  }

  Future<void> update(PersonelModel personel) async {
    await _personelRef
        .doc(personel.id)
        .set(personel.toMap(), SetOptions(merge: true));
  }
}
