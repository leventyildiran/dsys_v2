import 'package:flutter/foundation.dart';
import '../../../core/hesaplama_motoru.dart';
import '../../../core/karar_metni_servisi.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../../personel/models/personel_model.dart';
import '../services/danismanlik_service.dart';

/// Canlı önizleme hesaplama sonucu.
class OnizlemeSonucu {
  const OnizlemeSonucu({
    required this.kesinti,
    required this.katsayi,
    required this.artikBakiye,
    required this.personelDagitimlari,
    required this.kararMetni,
    required this.sablonDogrulama,
  });

  final KesintiBilgisi kesinti;
  final double katsayi;
  final double artikBakiye;
  final List<PersonelDagitimSonucu> personelDagitimlari;
  final String kararMetni;
  final SablonDogrulamaSonucu sablonDogrulama;
}

/// Personel bazlı dağıtım sonucu.
class PersonelDagitimSonucu {
  const PersonelDagitimSonucu({
    required this.personelId,
    required this.adSoyad,
    required this.unvan,
    required this.unvanKatsayisi,
    required this.faaliyetPuani,
    required this.bireyselPuan,
    required this.brutHakedis,
    required this.tavanAsimi,
  });

  final String personelId;
  final String adSoyad;
  final String unvan;
  final double unvanKatsayisi;
  final double faaliyetPuani;
  final double bireyselPuan;
  final double brutHakedis;
  final bool tavanAsimi;
}

class DanismanlikProvider extends ChangeNotifier {
  DanismanlikProvider({DanismanlikService? danismanlikService})
      : _danismanlikService = danismanlikService ?? DanismanlikService();

  final DanismanlikService _danismanlikService;

  // ─────────────────────────────────────────────────────────────
  // FORM STATE
  // ─────────────────────────────────────────────────────────────

  DanismanlikTuru _tur = DanismanlikTuru.standart;
  DanismanlikTuru get tur => _tur;

  double _brutTaksitTutari = 0;
  double get brutTaksitTutari => _brutTaksitTutari;

  int _kdvOrani = 20;
  int get kdvOrani => _kdvOrani;

  int _hazinePayiOrani = 1;
  int get hazinePayiOrani => _hazinePayiOrani;

  int _bapPayiOrani = 5;
  int get bapPayiOrani => _bapPayiOrani;

  int _aracGerecPayiOrani = 45;
  int get aracGerecPayiOrani => _aracGerecPayiOrani;

  int _suresi = 1;
  int get suresi => _suresi;

  String _firmaUnvan = '';
  String get firmaUnvan => _firmaUnvan;

  String _isinKonusu = '';
  String get isinKonusu => _isinKonusu;

  String _birimAd = '';
  String get birimAd => _birimAd;

  // Evrak bilgileri
  String _birimEvrakTarihi = '';
  String _birimEvrakSayisi = '';
  String _birimKurulTarihi = '';
  String _birimToplantiSayisi = '';
  String _birimKararNo = '';
  String _ykKararTarihi = '';
  String _ykKararNo = '';

  String get birimEvrakTarihi => _birimEvrakTarihi;
  String get birimEvrakSayisi => _birimEvrakSayisi;
  String get birimKurulTarihi => _birimKurulTarihi;
  String get birimToplantiSayisi => _birimToplantiSayisi;
  String get birimKararNo => _birimKararNo;
  String get ykKararTarihi => _ykKararTarihi;
  String get ykKararNo => _ykKararNo;

  // Personel listesi
  List<PersonelGorevAtama> _personeller = [];
  List<PersonelGorevAtama> get personeller => _personeller;

  // Önizleme sonucu
  OnizlemeSonucu? _onizleme;
  OnizlemeSonucu? get onizleme => _onizleme;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  // ─────────────────────────────────────────────────────────────
  // SETTER'LAR
  // ─────────────────────────────────────────────────────────────

  void setTur(DanismanlikTuru value) {
    _tur = value;
    _hesapla();
  }

  void setBrutTaksitTutari(double value) {
    _brutTaksitTutari = value;
    _hesapla();
  }

  void setKdvOrani(int value) {
    _kdvOrani = value;
    _hesapla();
  }

  void setHazinePayiOrani(int value) {
    _hazinePayiOrani = value;
    _hesapla();
  }

  void setBapPayiOrani(int value) {
    _bapPayiOrani = value;
    _hesapla();
  }

  void setAracGerecPayiOrani(int value) {
    _aracGerecPayiOrani = value;
    _hesapla();
  }

  void setSuresi(int value) {
    _suresi = value;
    _hesapla();
  }

  void setFirmaUnvan(String value) {
    _firmaUnvan = value;
    _hesapla();
  }

  void setIsinKonusu(String value) {
    _isinKonusu = value;
    _hesapla();
  }

  void setBirimAd(String value) {
    _birimAd = value;
    _hesapla();
  }

  void setBirimEvrakTarihi(String value) {
    _birimEvrakTarihi = value;
    _hesapla();
  }

  void setBirimEvrakSayisi(String value) {
    _birimEvrakSayisi = value;
    _hesapla();
  }

  void setBirimKurulTarihi(String value) {
    _birimKurulTarihi = value;
    _hesapla();
  }

  void setBirimToplantiSayisi(String value) {
    _birimToplantiSayisi = value;
    _hesapla();
  }

  void setBirimKararNo(String value) {
    _birimKararNo = value;
    _hesapla();
  }

  void setYkKararTarihi(String value) {
    _ykKararTarihi = value;
    _hesapla();
  }

  void setYkKararNo(String value) {
    _ykKararNo = value;
    _hesapla();
  }

  void personelEkle(PersonelModel personel) {
    // Aynı personel eklenmesin
    if (!_personeller.any((p) => p.personel.id == personel.id)) {
      _personeller.add(PersonelGorevAtama(personel: personel));
      _hesapla();
    }
  }

  void personelCikar(int index) {
    _personeller.removeAt(index);
    _hesapla();
  }

  void personelPuanGuncelle(int index, double puan) {
    _personeller[index].faaliyetPuani = puan;
    _hesapla();
  }

  void personelPayGuncelle(int index, int pay) {
    _personeller[index].payOrani = pay;
    _hesapla();
  }

  void temizle() {
    _tur = DanismanlikTuru.standart;
    _brutTaksitTutari = 0;
    _kdvOrani = 20;
    _hazinePayiOrani = 1;
    _bapPayiOrani = 5;
    _aracGerecPayiOrani = 45;
    _suresi = 1;
    _firmaUnvan = '';
    _isinKonusu = '';
    _birimAd = '';
    _birimEvrakTarihi = '';
    _birimEvrakSayisi = '';
    _birimKurulTarihi = '';
    _birimToplantiSayisi = '';
    _birimKararNo = '';
    _ykKararTarihi = '';
    _ykKararNo = '';
    _personeller = [];
    _onizleme = null;
    _saveError = null;
    notifyListeners();
  }

  Future<bool> kaydet() async {
    if (_isSaving) return false;

    final firma = _firmaUnvan.trim();
    final konu = _isinKonusu.trim();
    if (_brutTaksitTutari <= 0 || firma.isEmpty || konu.isEmpty) {
      _saveError = 'Firma ünvanı, iş konusu ve brüt tutar alanlarını doldurmalısınız.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final model = DanismanlikModel(
        id: '', // Firestore oluştururken atayacak
        birimId: 'merkez', // TODO: Aktif kullanıcının birimini ekle
        firmaId: '',
        firmaUnvan: firma,
        birimKisaAd: _birimAd.trim(),
        danismanlikTuru: _tur,
        konusu: konu,
        toplamTutar: _brutTaksitTutari,
        kdvOrani: _kdvOrani,
        suresi: _suresi,
        durum: DanismanlikDurum.bekliyor,
        ykKararTarihi: _ykKararTarihi.trim().isEmpty ? null : _ykKararTarihi,
        ykKararNo: _ykKararNo.trim().isEmpty ? null : _ykKararNo,
        ykToplantiSayisi: _birimToplantiSayisi.trim().isEmpty ? null : _birimToplantiSayisi,
        hazinePayiOrani: _hazinePayiOrani,
        bapPayiOrani: _bapPayiOrani,
        aracGerecPayiOrani: _aracGerecPayiOrani,
        dagitilabilirOran: _tur == DanismanlikTuru.standart ? 49 : 85,
        personeller: List.from(_personeller),
        createdAt: DateTime.now(),
      );

      await _danismanlikService.create(model);
      return true;
    } catch (_) {
      _saveError = 'Kayıt sırasında bir hata oluştu.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> durumGuncelle(String id, DanismanlikDurum durum) async {
    await _danismanlikService.updateDurum(id, durum);
  }

  Future<void> danismanlikSil(String id) async {
    await _danismanlikService.delete(id);
  }

  // ─────────────────────────────────────────────────────────────
  // HESAPLAMA MOTORU (Canlı Önizleme)
  // ─────────────────────────────────────────────────────────────

  void _hesapla() {
    if (_brutTaksitTutari <= 0) {
      _onizleme = null;
      notifyListeners();
      return;
    }

    final KesintiBilgisi kesinti;
    if (_tur == DanismanlikTuru.standart) {
      kesinti = HesaplamaMotoru.standartKesintiler(
        brutTutar: _brutTaksitTutari,
        kdvOrani: _kdvOrani,
        hazinePayiOrani: _hazinePayiOrani,
        bapPayiOrani: _bapPayiOrani,
        aracGerecPayiOrani: _aracGerecPayiOrani,
      );
    } else {
      kesinti = HesaplamaMotoru.sanayiIsbirligiKesintiler(
        brutTutar: _brutTaksitTutari,
        kdvOrani: _kdvOrani,
      );
    }

    final personelPuanlar = _personeller
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
    double artikBakiye = 0;
    if (toplamPuan > 0 && kesinti.dagitilabilirTutar > 0) {
      katsayi = HesaplamaMotoru.katsayiSimulasyonu(
        kesinti.dagitilabilirTutar,
        toplamPuan,
        personelPuanlar,
      );
      artikBakiye = HesaplamaMotoru.artikBakiyeHesapla(
        kesinti.dagitilabilirTutar,
        katsayi,
        personelPuanlar,
      );
    }

    final dagitimlar = _personeller.map((p) {
      final bireyselPuan = p.faaliyetPuani * p.personel.unvanKatsayisi;
      final brutHakedis = toplamPuan > 0
          ? double.parse((bireyselPuan * katsayi).toStringAsFixed(2))
          : 0.0;

      return PersonelDagitimSonucu(
        personelId: p.personel.id,
        adSoyad: p.personel.adSoyad,
        unvan: p.personel.unvan,
        unvanKatsayisi: p.personel.unvanKatsayisi,
        faaliyetPuani: p.faaliyetPuani,
        bireyselPuan: bireyselPuan,
        brutHakedis: brutHakedis,
        tavanAsimi: false, 
      );
    }).toList();

    final isStandart = _tur == DanismanlikTuru.standart;
    final veriler = _kararMetniVerileriHazirla(katsayi);
    final dogrulama = KararMetniServisi.dogrula(
      isStandart: isStandart,
      veriler: veriler,
    );
    final kararMetni = KararMetniServisi.metinUret(
      isStandart: isStandart,
      veriler: veriler,
    );

    _onizleme = OnizlemeSonucu(
      kesinti: kesinti,
      katsayi: katsayi,
      artikBakiye: artikBakiye,
      personelDagitimlari: dagitimlar,
      kararMetni: kararMetni,
      sablonDogrulama: dogrulama,
    );
    notifyListeners();
  }

  Map<String, String?> _kararMetniVerileriHazirla(double katsayi) {
    final isStandart = _tur == DanismanlikTuru.standart;

    final hocaUnvan = _personeller.isNotEmpty ? _personeller.first.personel.unvan : '';
    final hocaAdSoyad = _personeller.isNotEmpty ? _personeller.first.personel.adSoyad : '';

    if (isStandart) {
      return {
        'BIRIM_AD': _birimAd.isNotEmpty ? _birimAd : null,
        'BIRIM_EVRAK_TARIHI': _birimEvrakTarihi.isNotEmpty ? _birimEvrakTarihi : null,
        'BIRIM_EVRAK_SAYISI': _birimEvrakSayisi.isNotEmpty ? _birimEvrakSayisi : null,
        'BIRIM_KURUL_TARIHI': _birimKurulTarihi.isNotEmpty ? _birimKurulTarihi : null,
        'BIRIM_TOPLANTI_SAYI': _birimToplantiSayisi.isNotEmpty ? _birimToplantiSayisi : null,
        'BIRIM_KARAR_NO': _birimKararNo.isNotEmpty ? _birimKararNo : null,
        'YK_KARAR_TARIHI': _ykKararTarihi.isNotEmpty ? _ykKararTarihi : null,
        'YK_KARAR_NO': _ykKararNo.isNotEmpty ? _ykKararNo : null,
        'FIRMA_UNVAN': _firmaUnvan.isNotEmpty ? _firmaUnvan : null,
        'ISIN_KONUSU': _isinKonusu.isNotEmpty ? _isinKonusu : null,
        'DANISMANLIK_SURESI': _suresi > 0 ? _suresi.toString() : null,
        'HOCA_UNVAN': hocaUnvan.isNotEmpty ? hocaUnvan : null,
        'HOCA_AD_SOYAD': hocaAdSoyad.isNotEmpty ? hocaAdSoyad : null,
        'KATSAYI': katsayi > 0 ? TurkceFormat.katsayi(katsayi) : null,
      };
    } else {
      return {
        'UYK_KARAR_TARIHI': _ykKararTarihi.isNotEmpty ? _ykKararTarihi : null,
        'UYK_TOPLANTI_SAYI': _birimToplantiSayisi.isNotEmpty ? _birimToplantiSayisi : null,
        'UYK_KARAR_NO': _ykKararNo.isNotEmpty ? _ykKararNo : null,
        'FIRMA_UNVAN': _firmaUnvan.isNotEmpty ? _firmaUnvan : null,
        'HOCA_UNVAN': hocaUnvan.isNotEmpty ? hocaUnvan : null,
        'HOCA_AD_SOYAD': hocaAdSoyad.isNotEmpty ? hocaAdSoyad : null,
        'HIZMET_BASLANGIC_TARIHI': null,
        'HIZMET_BITIS_TARIHI': null,
        'DANISMANLIK_SURESI': _suresi > 0 ? _suresi.toString() : null,
        'GELIR_TUTARI': _brutTaksitTutari > 0
            ? TurkceFormat.para(_brutTaksitTutari).replaceAll(' TL', '')
            : null,
        'KATKI_PAYI_TUTARI': _onizleme != null && _onizleme!.kesinti.dagitilabilirTutar > 0
            ? TurkceFormat.para(_onizleme!.kesinti.dagitilabilirTutar).replaceAll(' TL', '')
            : null,
      };
    }
  }
}
