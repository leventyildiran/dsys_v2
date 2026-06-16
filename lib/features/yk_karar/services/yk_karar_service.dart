import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../models/toplanti_model.dart';
import '../models/yk_karar_model.dart';

/// Toplantı ve YK Kararları için birleşik servis katmanı (v2).
///
/// Firestore koleksiyonları:
///   - `universiteler/{uniId}/toplantilar/{toplantiId}`
///   - `universiteler/{uniId}/ykKararlari/{kararId}`
class YkKararService {
  YkKararService({FirestoreService? firestoreService})
      : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const String _toplantiCollection = 'toplantilar';
  static const String _kararCollection = 'ykKararlari';

  // ═══════════════════════════════════════════════════════════
  // TOPLANTI (GÜNDEM) İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════

  /// Tüm toplantıları getirir (en yeniden en eskiye).
  Future<List<ToplantiModel>> toplantiGetAll() async {
    try {
      final snapshot = await _service.getAll(
        _toplantiCollection,
        queryBuilder: (ref) => ref.orderBy('olusturmaTarihi', descending: true),
      );
      return snapshot.docs
          .map((doc) => ToplantiModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[YkKararService.toplantiGetAll] Hata: $e');
      return [];
    }
  }

  /// Tekil toplantı kaydı getirir.
  Future<ToplantiModel?> toplantiGetById(String id) async {
    try {
      final doc = await _service.get(_toplantiCollection, id);
      if (!doc.exists || doc.data() == null) return null;
      return ToplantiModel.fromMap(id, doc.data()!);
    } catch (e) {
      debugPrint('[YkKararService.toplantiGetById] Hata: $e');
      return null;
    }
  }

  /// Yeni toplantı oluşturur.
  Future<String> toplantiCreate(ToplantiModel model) async {
    try {
      final data = model.toMap();
      data['olusturmaTarihi'] = DateTime.now().toIso8601String();
      return await _service.create(_toplantiCollection, data);
    } catch (e) {
      debugPrint('[YkKararService.toplantiCreate] Hata: $e');
      rethrow;
    }
  }

  /// Toplantı kaydını günceller.
  Future<void> toplantiUpdate(String id, Map<String, dynamic> data) async {
    try {
      await _service.update(_toplantiCollection, id, data);
    } catch (e) {
      debugPrint('[YkKararService.toplantiUpdate] Hata: $e');
      rethrow;
    }
  }

  /// Gündem maddelerini günceller.
  Future<void> gundemGuncelle(
      String toplantiId, List<GundemMaddesi> maddeler) async {
    await toplantiUpdate(toplantiId, {
      'gundemMaddeleri': maddeler.map((m) => m.toMap()).toList(),
    });
  }

  /// Gündem madde sıralamasını değiştirir.
  Future<void> siraDegistir(
    String toplantiId,
    List<GundemMaddesi> maddeler,
    int eskiIndex,
    int yeniIndex,
  ) async {
    final yeniListe = List<GundemMaddesi>.from(maddeler);
    final item = yeniListe.removeAt(eskiIndex);
    yeniListe.insert(yeniIndex, item);
    final guncellenmis = yeniListe.asMap().entries.map((entry) {
      return entry.value.copyWith(siraNo: entry.key + 1);
    }).toList();
    await gundemGuncelle(toplantiId, guncellenmis);
  }

  /// Toplantı siler.
  Future<void> toplantiDelete(String id) async {
    try {
      await _service.delete(_toplantiCollection, id);
    } catch (e) {
      debugPrint('[YkKararService.toplantiDelete] Hata: $e');
      rethrow;
    }
  }

  /// Gerçek zamanlı toplantı stream'i.
  Stream<List<ToplantiModel>> toplantiStream() {
    return _service
        .stream(
          _toplantiCollection,
          queryBuilder: (ref) =>
              ref.orderBy('olusturmaTarihi', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) => ToplantiModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════
  // YK KARAR İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════

  /// Belirli bir toplantıya ait tüm kararları getirir.
  Future<List<YkKararModel>> kararGetByToplanti(String toplantiId) async {
    try {
      final snapshot = await _service.where(
        _kararCollection,
        field: 'toplantiId',
        isEqualTo: toplantiId,
      );
      final list = snapshot.docs
          .map((doc) => YkKararModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.kararNo.compareTo(b.kararNo));
      return list;
    } catch (e) {
      debugPrint('[YkKararService.kararGetByToplanti] Hata: $e');
      return [];
    }
  }

  /// Birime ait geçmiş YK kararlarını getirir (id öncelikli, ad yedek eşleşme).
  Future<List<YkKararModel>> kararGetByBirim({
    required String birimId,
    String? birimAd,
    int limit = 10,
  }) async {
    try {
      final tumKararlar = await kararGetAll();
      final filtered = tumKararlar.where((k) {
        if (birimId.isNotEmpty && k.birimId == birimId) return true;
        if (birimAd != null && birimAd.isNotEmpty && k.birimAd.isNotEmpty) {
          final a = k.birimAd.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final b = birimAd.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          return a.contains(b) || b.contains(a);
        }
        return false;
      }).toList();

      filtered.sort((a, b) {
        final aDate = a.olusturmaTarihi ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.olusturmaTarihi ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return filtered.take(limit).toList();
    } catch (e) {
      debugPrint('[YkKararService.kararGetByBirim] Hata: $e');
      return [];
    }
  }

  /// Tüm kararları (kendi ürettiklerimiz ve dış kaynaklılar) getirir.
  Future<List<YkKararModel>> kararGetAll() async {
    try {
      final snapshot = await _service.getAll(
        _kararCollection,
        queryBuilder: (ref) => ref.orderBy('olusturmaTarihi', descending: true),
      );
      final list = snapshot.docs
          .map((doc) => YkKararModel.fromMap(doc.id, doc.data()))
          .toList();
      return list;
    } catch (e) {
      debugPrint('[YkKararService.kararGetAll] Hata: $e');
      return [];
    }
  }

  /// Sıradaki karar numarasını üretir.
  Future<String> sonrakiKararNoUret(String toplantiNo) async {
    try {
      final snapshot = await _service.where(
        _kararCollection,
        field: 'toplantiNo',
        isEqualTo: toplantiNo,
      );
      final list = snapshot.docs
          .map((doc) => YkKararModel.fromMap(doc.id, doc.data()))
          .toList();
      if (list.isEmpty) {
        return '$toplantiNo-01';
      }
      list.sort((a, b) => a.kararNo.compareTo(b.kararNo));
      final sonKararNo = list.last.kararNo;
      final parcalar = sonKararNo.split('-');
      if (parcalar.length > 1) {
        final sira = int.tryParse(parcalar.last) ?? 0;
        return '$toplantiNo-${(sira + 1).toString().padLeft(2, '0')}';
      }
      return '$toplantiNo-01';
    } catch (e) {
      debugPrint('[YkKararService.sonrakiKararNoUret] Hata: $e');
      return '$toplantiNo-01';
    }
  }

  /// Tekil karar kaydı getirir.
  Future<YkKararModel?> kararGetById(String id) async {
    try {
      final doc = await _service.get(_kararCollection, id);
      if (!doc.exists || doc.data() == null) return null;
      return YkKararModel.fromMap(id, doc.data()!);
    } catch (e) {
      debugPrint('[YkKararService.kararGetById] Hata: $e');
      return null;
    }
  }

  /// Yeni karar oluşturur.
  Future<String> kararCreate(YkKararModel model) async {
    try {
      final data = model.toMap();
      data['olusturmaTarihi'] = DateTime.now().toIso8601String();
      return await _service.create(_kararCollection, data);
    } catch (e) {
      debugPrint('[YkKararService.kararCreate] Hata: $e');
      rethrow;
    }
  }

  /// Toplu karar oluşturur (AI parse sonrası).
  Future<List<String>> kararCreateBatch(List<YkKararModel> kararlar) async {
    final ids = <String>[];
    for (final karar in kararlar) {
      final id = await kararCreate(karar);
      ids.add(id);
    }
    return ids;
  }

  /// Karar günceller.
  Future<void> kararUpdate(String id, Map<String, dynamic> data) async {
    try {
      await _service.update(_kararCollection, id, data);
    } catch (e) {
      debugPrint('[YkKararService.kararUpdate] Hata: $e');
      rethrow;
    }
  }

  /// Karar siler.
  Future<void> kararDelete(String id) async {
    try {
      await _service.delete(_kararCollection, id);
    } catch (e) {
      debugPrint('[YkKararService.kararDelete] Hata: $e');
      rethrow;
    }
  }

  /// Belirli toplantı kararları için gerçek zamanlı stream.
  Stream<List<YkKararModel>> kararStream(String toplantiId) {
    return _service
        .stream(
          _kararCollection,
          queryBuilder: (ref) =>
              ref.where('toplantiId', isEqualTo: toplantiId),
        )
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => YkKararModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.kararNo.compareTo(b.kararNo));
      return list;
    });
  }
}
