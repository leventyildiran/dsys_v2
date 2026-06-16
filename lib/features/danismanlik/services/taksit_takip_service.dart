import 'dart:async';

import '../models/danismanlik_model.dart';
import '../models/taksit_takip_kayit.dart';
import '../models/taksit_model.dart';
import 'danismanlik_service.dart';
import 'taksit_service.dart';

/// Konsolide taksit takip verisi — tüm danışmanlıklar.
class TaksitTakipService {
  TaksitTakipService({
    TaksitService? taksitService,
    DanismanlikService? danismanlikService,
  }) : _taksitService = taksitService ?? TaksitService(),
       _danismanlikService = danismanlikService ?? DanismanlikService();

  final TaksitService _taksitService;
  final DanismanlikService _danismanlikService;

  final Map<String, DanismanlikModel> _danismanlikCache = {};

  Stream<List<TaksitTakipKayit>> streamKayitlar() {
    return _taksitService.streamTumTaksitler().asyncMap((ham) async {
      await _danismanliklariDoldur(ham.map((e) => e.danismanlikId).toSet());
      return ham
          .where(
            (e) =>
                e.danismanlikId.isNotEmpty &&
                _danismanlikCache.containsKey(e.danismanlikId),
          )
          .map(
            (e) => TaksitTakipKayit(
              danismanlikId: e.danismanlikId,
              danismanlik: _danismanlikCache[e.danismanlikId]!,
              taksit: e.taksit,
            ),
          )
          .toList();
    });
  }

  Future<void> _danismanliklariDoldur(Set<String> ids) async {
    final eksik = ids.where((id) => !_danismanlikCache.containsKey(id));
    await Future.wait(
      eksik.map((id) async {
        final d = await _danismanlikService.getById(id);
        if (d != null) _danismanlikCache[id] = d;
      }),
    );
  }

  void cacheTemizle() => _danismanlikCache.clear();
}

/// Taksit takip istatistikleri.
class TaksitTakipIstatistik {
  const TaksitTakipIstatistik({
    required this.toplam,
    required this.taslak,
    required this.onayBekleyen,
    required this.onaylanan,
    required this.odenen,
    required this.geciken,
    required this.toplamTutar,
  });

  final int toplam;
  final int taslak;
  final int onayBekleyen;
  final int onaylanan;
  final int odenen;
  final int geciken;
  final double toplamTutar;

  factory TaksitTakipIstatistik.hesapla(List<TaksitTakipKayit> kayitlar) {
    var taslak = 0, onayBekleyen = 0, onaylanan = 0, odenen = 0, geciken = 0;
    var toplamTutar = 0.0;

    for (final k in kayitlar) {
      toplamTutar += k.taksit.brutTutar;
      switch (k.taksit.durum) {
        case TaksitDurum.taslak:
          taslak++;
        case TaksitDurum.mudurOnayinda:
        case TaksitDurum.merkezOnayinda:
        case TaksitDurum.ykGundeminde:
          onayBekleyen++;
        case TaksitDurum.onaylandi:
          onaylanan++;
        case TaksitDurum.odendi:
          odenen++;
        case TaksitDurum.gecikti:
          geciken++;
      }
    }

    return TaksitTakipIstatistik(
      toplam: kayitlar.length,
      taslak: taslak,
      onayBekleyen: onayBekleyen,
      onaylanan: onaylanan,
      odenen: odenen,
      geciken: geciken,
      toplamTutar: toplamTutar,
    );
  }
}
