import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firma_model.dart';
import 'firestore_service.dart';

class FirmaService {
  FirmaService({FirestoreService? firestoreService})
    : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'firmalar';

  CollectionReference<Map<String, dynamic>> get _firmalarRef =>
      _service.collection(_collection);

  static List<FirmaModel>? _cachedFirmalar;
  static DateTime? _lastFetchTime;

  Future<List<FirmaModel>> getAllFirmalar({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFirmalar != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 60) {
        return _cachedFirmalar!;
      }
    }

    final querySnapshot = await _firmalarRef.get();
    final list = querySnapshot.docs
        .map((doc) => FirmaModel.fromJson(doc.data(), doc.id))
        .toList();
    list.sort((a, b) => a.firmaAdi.compareTo(b.firmaAdi));

    _cachedFirmalar = list;
    _lastFetchTime = DateTime.now();
    return list;
  }

  void _invalidateCache() {
    _cachedFirmalar = null;
    _lastFetchTime = null;
  }

  Future<void> addFirma(FirmaModel firma) async {
    await _firmalarRef.add(firma.toJson());
    _invalidateCache();
  }

  Future<void> updateFirma(FirmaModel firma) async {
    await _firmalarRef.doc(firma.id).update(firma.toJson());
    _invalidateCache();
  }

  Future<void> deleteFirma(String id) async {
    await _firmalarRef.doc(id).delete();
    _invalidateCache();
  }
}
