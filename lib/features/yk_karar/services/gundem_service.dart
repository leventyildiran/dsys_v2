import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/paginated_result.dart';
import '../models/gundem_model.dart';
import '../../../core/services/firestore_service.dart';

/// Toplantı gündem derleyici servis katmanı.
///
/// Firestore yolu: `toplantilar/{toplantiId}`
class GundemService {
  GundemService({FirestoreService? firestoreService})
      : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const String _collection = 'toplantilar';

  /// Tüm toplantıları getirir.
  Future<List<ToplantiModel>> getAll() async {
    try {
      final snapshot = await _service.getAll(_collection);
      return snapshot.docs
          .map((doc) => ToplantiModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[GundemService.getAll] Hata: $e');
      return [];
    }
  }

  Future<PaginatedResult<ToplantiModel,
      QueryDocumentSnapshot<Map<String, dynamic>>>> getPage({
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    try {
      final page = await _service.getPage(
        _collection,
        limit: limit,
        startAfterDocument: startAfterDocument,
        queryBuilder: (ref) => ref.orderBy('olusturmaTarihi', descending: true),
      );
      return PaginatedResult(
        items: page.docs
            .map((doc) => ToplantiModel.fromMap(doc.id, doc.data()))
            .toList(),
        hasMore: page.hasMore,
        nextCursor: page.lastDocument,
      );
    } catch (e) {
      debugPrint('[GundemService.getPage] Hata: $e');
      return const PaginatedResult(items: [], hasMore: false);
    }
  }

  /// Tekil toplantı kaydı getirir.
  Future<ToplantiModel?> getById(String id) async {
    try {
      final doc = await _service.get(_collection, id);
      if (!doc.exists || doc.data() == null) return null;
      return ToplantiModel.fromMap(id, doc.data()!);
    } catch (e) {
      debugPrint('[GundemService.getById] Hata: $e');
      return null;
    }
  }

  /// Yeni toplantı oluşturur.
  Future<String> create(ToplantiModel model) async {
    try {
      final data = model.toMap();
      data['olusturmaTarihi'] = DateTime.now().toIso8601String();
      final docRef = await _service.add(_collection, data);
      return docRef.id;
    } catch (e) {
      debugPrint('[GundemService.create] Hata: $e');
      rethrow;
    }
  }

  /// Toplantı kaydını günceller.
  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await _service.update(_collection, id, data);
    } catch (e) {
      debugPrint('[GundemService.update] Hata: $e');
      rethrow;
    }
  }

  /// Gündem maddelerini günceller (sıralama dahil).
  Future<void> gundemGuncelle(
      String toplantiId, List<GundemMaddesi> maddeler) async {
    await update(toplantiId, {
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

    // Sıra numaralarını güncelle
    final guncellenmis = yeniListe.asMap().entries.map((entry) {
      return entry.value.copyWith(siraNo: entry.key + 1);
    }).toList();

    await gundemGuncelle(toplantiId, guncellenmis);
  }

  /// Toplantı kaydını siler.
  Future<void> delete(String id) async {
    try {
      await _service.delete(_collection, id);
    } catch (e) {
      debugPrint('[GundemService.delete] Hata: $e');
      rethrow;
    }
  }

  /// Toplantı Gündem Maddeleri.docx için metin üretir.
  String gundemBelgesiUret(ToplantiModel toplanti) {
    final buffer = StringBuffer();
    buffer.writeln('DÖNER SERMAYE YÜRÜTME KURULU TOPLANTI GÜNDEMİ');
    buffer.writeln('═' * 60);
    buffer.writeln();
    buffer.writeln('Toplantı Tarihi : ${toplanti.toplantiTarihi}');
    buffer.writeln('Toplantı No     : ${toplanti.toplantiNo}');
    buffer.writeln();
    buffer.writeln('─' * 60);
    buffer.writeln('GÜNDEM MADDELERİ');
    buffer.writeln('─' * 60);
    buffer.writeln();

    for (final madde in toplanti.gundemMaddeleri) {
      buffer.writeln(
        '${madde.siraNo}. [${madde.tur.displayName}] ${madde.baslik}',
      );
      if (madde.birimAd != null) {
        buffer.writeln('   Birim: ${madde.birimAd}');
      }
      if (madde.aciklama != null && madde.aciklama!.isNotEmpty) {
        buffer.writeln('   Açıklama: ${madde.aciklama}');
      }
      buffer.writeln();
    }

    buffer.writeln('─' * 60);
    buffer.writeln(
        'Toplam Gündem Maddesi: ${toplanti.gundemMaddeleri.length}');

    return buffer.toString();
  }

  /// Gerçek zamanlı dinleme.
  Stream<List<ToplantiModel>> stream() {
    return _service.stream(_collection).map((snapshot) => snapshot.docs
        .map((doc) => ToplantiModel.fromMap(doc.id, doc.data()))
        .toList());
  }
}
