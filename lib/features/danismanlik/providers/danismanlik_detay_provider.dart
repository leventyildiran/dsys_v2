import 'package:flutter/foundation.dart';
import '../../../core/hesaplama_motoru.dart';
import '../../../core/karar_metni_servisi.dart';
import '../../../core/turkce_format.dart';
import '../../personel/services/personel_hakedis_service.dart';
import '../../yk_karar/models/yk_karar_model.dart';
import '../../yk_karar/services/yk_karar_service.dart';
import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../services/dagitim_service.dart';
import '../services/taksit_service.dart';

class DanismanlikDetayProvider extends ChangeNotifier {
  DanismanlikDetayProvider(
    this.danismanlik, {
    TaksitService? taksitService,
    DagitimService? dagitimService,
    PersonelHakedisService? hakedisService,
    YkKararService? ykKararService,
  })  : _taksitService = taksitService ?? TaksitService(),
        _dagitimService = dagitimService ?? DagitimService(),
        _hakedisService = hakedisService ?? PersonelHakedisService(),
        _ykKararService = ykKararService ?? YkKararService() {
    _initTaksitlerStream();
  }

  final DanismanlikModel danismanlik;
  final TaksitService _taksitService;
  final DagitimService _dagitimService;
  final PersonelHakedisService _hakedisService;
  final YkKararService _ykKararService;

  List<TaksitModel> _taksitler = [];
  List<TaksitModel> get taksitler => _taksitler;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _initTaksitlerStream() {
    _taksitService.streamTaksitler(danismanlik.id).listen((data) {
      _taksitler = data;
      notifyListeners();
    });
  }

  /// Yeni taksit oluşturur (Sadece taslak olarak).
  Future<void> yeniTaksitEkle(int ayNo, double brutTutar) async {
    _setLoading(true);
    try {
      final taksit = TaksitModel(
        id: '',
        ayNo: ayNo,
        brutTutar: brutTutar,
        durum: TaksitDurum.taslak,
      );
      await _taksitService.create(danismanlik.id, taksit);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Taksit dağıtımını hesaplar ve eğer istenirse sisteme/arşive kaydeder.
  Future<void> dagitimiHesaplaVeKaydet(
    TaksitModel taksit,
    String islemAyi, // "2026-06"
    bool arshiveGonder,
  ) async {
    _setLoading(true);
    try {
      // 1. Kesinti Hesaplaması
      final KesintiBilgisi kesinti;
      if (danismanlik.tur == DanismanlikTuru.standart) {
        kesinti = HesaplamaMotoru.standartKesintiler(
          brutTutar: taksit.brutTutar,
          kdvOrani: danismanlik.kdvOrani,
          hazinePayiOrani: danismanlik.hazinePayiOrani,
          bapPayiOrani: danismanlik.bapPayiOrani,
          aracGerecPayiOrani: danismanlik.aracGerecPayiOrani,
        );
      } else {
        kesinti = HesaplamaMotoru.sanayiIsbirligiKesintiler(
          brutTutar: taksit.brutTutar,
          kdvOrani: danismanlik.kdvOrani,
        );
      }

      // 2. Personel Puanları
      final personelPuanlar = danismanlik.personeller
          .where((p) => p.faaliyetPuani > 0)
          .map((p) => PersonelPuanModel(
                personelId: p.personel.id,
                faaliyetPuani: p.faaliyetPuani,
                unvanKatsayisi: p.personel.unvanKatsayisi,
              ))
          .toList();

      double toplamPuan = 0;
      for (final p in personelPuanlar) {
        toplamPuan += p.bireyselPuan;
      }

      double katsayi = 0;
      if (toplamPuan > 0 && kesinti.dagitilabilirTutar > 0) {
        katsayi = HesaplamaMotoru.katsayiSimulasyonu(
          kesinti.dagitilabilirTutar,
          toplamPuan,
          personelPuanlar,
        );
      }

      // 3. Dağıtım Modellerini Oluşturma ve Tavan Kontrolü
      final dagitimlar = <DagitimModel>[];
      for (final p in danismanlik.personeller) {
        if (p.faaliyetPuani <= 0) continue;

        final bireyselPuan = p.faaliyetPuani * p.personel.unvanKatsayisi;
        final brutHakedis = double.parse((bireyselPuan * katsayi).toStringAsFixed(2));

        // Tavan Kontrolü (Aylık toplam mevcut gelir + EYDMA tavanı)
        // Dummy veri: memur maaş katsayısı ve göstergeler normalde sistem ayarlarından gelir.
        final eydma = HesaplamaMotoru.eydmaHesapla(
          gostergeEk: 4000,
          gostergeMakamTemsil: 6000,
          memurMaasKatsayisi: 0.907796,
        );
        final unvanTavani = HesaplamaMotoru.unvanTavaniHesapla(eydma, 1200);

        final aylikMevcutGelir =
            await _hakedisService.toplamAylikGelir(p.personel.id, islemAyi);

        final tavanSonucu = HesaplamaMotoru.tavanKontrol(
          unvanTavani: unvanTavani,
          toplamAylikMevcutGelir: aylikMevcutGelir,
          yeniHesaplananHakedis: brutHakedis,
        );

        dagitimlar.add(DagitimModel(
          personelId: p.personel.id,
          adSoyad: p.personel.adSoyad,
          unvan: p.personel.unvan,
          unvanKatsayisi: p.personel.unvanKatsayisi,
          ekGosterge: 160,
          faaliyetTuru: 'Genel',
          faaliyetAdeti: 1,
          faaliyetTabanPuani: p.faaliyetPuani,
          toplamPuan: toplamPuan,
          bireyselPuan: bireyselPuan,
          brutHakedis: brutHakedis,
          tavanKontrol: tavanSonucu.fazlalikHavuzTutari > 0,
          odenebilirHakedis: tavanSonucu.odenebilirHakedis,
          fazlalikHavuzTutari: tavanSonucu.fazlalikHavuzTutari,
        ));
      }

      // Taksit güncellemeleri
      final guncelTaksit = taksit.copyWith(
        hazinePayi: kesinti.hazinePayi,
        bapPayi: kesinti.bapPayi,
        aracGerecPayi: kesinti.aracGerecPayi,
        dagitilabilirTutar: kesinti.dagitilabilirTutar,
        toplamPuan: toplamPuan,
        ekOdemeKatsayisi: katsayi,
        durum: arshiveGonder ? TaksitDurum.onaylandi : TaksitDurum.taslak,
      );

      // Kaydetme işlemi
      await _taksitService.update(danismanlik.id, taksit.id, guncelTaksit);
      await _dagitimService.topluKaydet(danismanlik.id, taksit.id, dagitimlar);

      if (arshiveGonder) {
        // Aylık hakedişleri güncelle (DonerSermayeEkle)
        for (final d in dagitimlar) {
          if (d.odenebilirHakedis != null && d.odenebilirHakedis! > 0) {
            await _hakedisService.donerSermayeEkle(
                d.personelId, islemAyi, d.odenebilirHakedis!);
          }
        }

        // Karar Metnini Üret
        final veriler = _kararMetniVerileriHazirla(katsayi, kesinti.dagitilabilirTutar);
        final kararMetni = KararMetniServisi.metinUret(
          isStandart: danismanlik.tur == DanismanlikTuru.standart,
          veriler: veriler,
        );

        final ykKarar = YkKararModel(
          id: '',
          kararNo: 'DSYS-${DateTime.now().year}-${taksit.id.substring(0, 4).toUpperCase()}',
          toplantiId: '',
          toplantiNo: '',
          birimId: danismanlik.birimId,
          birimAd: danismanlik.birimKisaAd ?? 'Birim',
          tur: YkKararTuru.danismanlik,
          baslik: '${danismanlik.firmaUnvan} Danışmanlık Dağılımı',
          kararMetni: kararMetni,
          kararTarihi: DateTime.now().toIso8601String().split('T').first,
          olusturmaTarihi: DateTime.now(),
          tabloVerileri: dagitimlar.map((d) {
            return {
              'Personel': '${d.unvan} ${d.adSoyad}',
              'Brüt Hakediş': TurkceFormat.para(d.brutHakedis),
              'Kesinti/Taşan': TurkceFormat.para(d.fazlalikHavuzTutari ?? 0.0),
              'Net Ödenen': TurkceFormat.para(d.odenebilirHakedis ?? 0.0),
            };
          }).toList(),
        );

        await _ykKararService.kararCreate(ykKarar); // Toplanti bağımsız veya güncel toplantıya eklenebilir.
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> taksitSil(String taksitId) async {
    _setLoading(true);
    try {
      await _taksitService.delete(danismanlik.id, taksitId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Map<String, String?> _kararMetniVerileriHazirla(double katsayi, double dagitilabilirTutar) {
    final isStandart = danismanlik.tur == DanismanlikTuru.standart;
    final hocaUnvan = danismanlik.personeller.isNotEmpty ? danismanlik.personeller.first.personel.unvan : '';
    final hocaAdSoyad = danismanlik.personeller.isNotEmpty ? danismanlik.personeller.first.personel.adSoyad : '';

    if (isStandart) {
      return {
        'BIRIM_AD': danismanlik.birimKisaAd,
        'BIRIM_EVRAK_TARIHI': null,
        'BIRIM_EVRAK_SAYISI': null,
        'BIRIM_KURUL_TARIHI': null,
        'BIRIM_TOPLANTI_SAYI': null,
        'BIRIM_KARAR_NO': null,
        'YK_KARAR_TARIHI': danismanlik.ykKararTarihi,
        'YK_KARAR_NO': danismanlik.ykKararNo,
        'FIRMA_UNVAN': danismanlik.firmaUnvan,
        'ISIN_KONUSU': danismanlik.konusu,
        'DANISMANLIK_SURESI': danismanlik.suresi > 0 ? danismanlik.suresi.toString() : null,
        'HOCA_UNVAN': hocaUnvan,
        'HOCA_AD_SOYAD': hocaAdSoyad,
        'KATSAYI': katsayi > 0 ? TurkceFormat.katsayi(katsayi) : null,
      };
    } else {
      return {
        'UYK_KARAR_TARIHI': danismanlik.ykKararTarihi,
        'UYK_TOPLANTI_SAYI': danismanlik.ykToplantiSayisi,
        'UYK_KARAR_NO': danismanlik.ykKararNo,
        'FIRMA_UNVAN': danismanlik.firmaUnvan,
        'HOCA_UNVAN': hocaUnvan,
        'HOCA_AD_SOYAD': hocaAdSoyad,
        'HIZMET_BASLANGIC_TARIHI': danismanlik.baslangicTarihi != null ? TurkceFormat.tarih(danismanlik.baslangicTarihi!) : null,
        'HIZMET_BITIS_TARIHI': danismanlik.bitisTarihi != null ? TurkceFormat.tarih(danismanlik.bitisTarihi!) : null,
        'DANISMANLIK_SURESI': danismanlik.suresi > 0 ? danismanlik.suresi.toString() : null,
        'GELIR_TUTARI': danismanlik.toplamTutar > 0
            ? TurkceFormat.para(danismanlik.toplamTutar).replaceAll(' TL', '')
            : null,
        'KATKI_PAYI_TUTARI': dagitilabilirTutar > 0
            ? TurkceFormat.para(dagitilabilirTutar).replaceAll(' TL', '')
            : null,
      };
    }
  }
}
