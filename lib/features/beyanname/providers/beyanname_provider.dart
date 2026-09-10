import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/beyanname_model.dart';
import '../services/beyanname_hesaplama_motoru.dart';
import '../../birim/services/birim_service.dart';
import '../../birim/models/birim_model.dart';

class BeyannameProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BirimService _birimService = BirimService();

  int _seciliYil = DateTime.now().year;
  int _seciliAy = DateTime.now().month;

  int get seciliYil => _seciliYil;
  int get seciliAy => _seciliAy;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<BirimModel> _sistemBirimleri = [];
  List<BirimModel> get sistemBirimleri => _sistemBirimleri;

  // Veri Listeleri
  List<Kdv1BirimSatiri> _kdv1Satirlari = [];
  List<TevkifatFirmaKaydi> _tevkifatKayitlari = [];
  List<MuhtasarSatiri> _muhtasarSatirlari = [];
  List<DamgaVergisiBirimSatiri> _damgaSatirlari = [];
  List<Hasiat600BirimSatiri> _hasiat600Satirlari = [];

  // Damga 301 kodu tutarı (ödemelerden kesilen)
  double _muhtasarKesilenDamgaVergisi301 = 0.0;
  double get muhtasarKesilenDamgaVergisi301 => _muhtasarKesilenDamgaVergisi301;

  List<Kdv1BirimSatiri> get kdv1Satirlari => _kdv1Satirlari;
  List<TevkifatFirmaKaydi> get tevkifatKayitlari => _tevkifatKayitlari;
  List<MuhtasarSatiri> get muhtasarSatirlari => _muhtasarSatirlari;
  List<DamgaVergisiBirimSatiri> get damgaSatirlari => _damgaSatirlari;
  List<Hasiat600BirimSatiri> get hasiat600Satirlari => _hasiat600Satirlari;

  // Devreden KDV (Önceki Aydan)
  double _oncekiAydanDevredenKdv = 0.0;
  double get oncekiAydanDevredenKdv => _oncekiAydanDevredenKdv;

  void setOncekiAydanDevredenKdv(double val) {
    _oncekiAydanDevredenKdv = val;
    notifyListeners();
  }

  // Canlı Hesaplama Sonuçları
  Kdv1KonsolideSonuc get kdv1Sonuc =>
      BeyannameHesaplamaMotoru.hesaplaKdv1(
        _kdv1Satirlari,
        oncekiDonemdenDevredenKdv: _oncekiAydanDevredenKdv,
      );

  Kdv2KonsolideSonuc get kdv2Sonuc =>
      BeyannameHesaplamaMotoru.hesaplaKdv2(_tevkifatKayitlari);

  MuhtasarKonsolideSonuc get muhtasarSonuc =>
      BeyannameHesaplamaMotoru.hesaplaMuhtasar(
        satirlar: _muhtasarSatirlari,
        muhtasarKesilenDamgaVergisi301: _muhtasarKesilenDamgaVergisi301,
        yil: _seciliYil,
        ay: _seciliAy,
      );

  double get damgaToplamMatrah =>
      _damgaSatirlari.fold(0.0, (s, x) => s + x.matrah);
  double get damgaToplamVergi =>
      _damgaSatirlari.fold(0.0, (s, x) => s + x.damgaVergisi);

  double get hasiat600ToplamKumulatif =>
      _hasiat600Satirlari.fold(0.0, (s, x) => s + x.kumulatifHasilat600);
  double get hasiat600ToplamAylik =>
      _hasiat600Satirlari.fold(0.0, (s, x) => s + x.aylikHasilat600);
  double get krediKarti123Toplam =>
      _hasiat600Satirlari.fold(0.0, (s, x) => s + x.krediKarti123);

  // Birim İcmal Tablosu
  List<BirimVergiIcmalSatiri> get birimIcmalListesi {
    final birimSet = <String>{};
    for (final k in _kdv1Satirlari) {
      final tam = BirimAdlandirma.tamAdGetir(k.birimAdi);
      if (tam.isNotEmpty) birimSet.add(tam);
    }
    for (final t in _tevkifatKayitlari) {
      if (t.birimAdi != null && t.birimAdi!.isNotEmpty) {
        final tam = BirimAdlandirma.tamAdGetir(t.birimAdi!);
        if (tam.isNotEmpty) birimSet.add(tam);
      }
    }
    for (final m in _muhtasarSatirlari) {
      final tam = BirimAdlandirma.tamAdGetir(m.birimAdi);
      if (tam.isNotEmpty) birimSet.add(tam);
    }
    for (final d in _damgaSatirlari) {
      final tam = BirimAdlandirma.tamAdGetir(d.birimAdi);
      if (tam.isNotEmpty) birimSet.add(tam);
    }

    final sortedBirimler = birimSet.toList()..sort();
    final list = <BirimVergiIcmalSatiri>[];

    for (final b in sortedBirimler) {
      final kdv1 = _kdv1Satirlari
          .where((x) => BirimAdlandirma.tamAdGetir(x.birimAdi) == b)
          .fold(0.0, (s, x) => s + x.netOdenecekKdv);
      final damga = _damgaSatirlari
          .where((x) => BirimAdlandirma.tamAdGetir(x.birimAdi) == b)
          .fold(0.0, (s, x) => s + x.damgaVergisi);
      final mGelir = _muhtasarSatirlari
          .where((x) => BirimAdlandirma.tamAdGetir(x.birimAdi) == b)
          .fold(0.0, (s, x) => s + x.gelirVergisi);
      final mDamga = _muhtasarSatirlari
          .where((x) => BirimAdlandirma.tamAdGetir(x.birimAdi) == b)
          .fold(0.0, (s, x) => s + x.damgaVergisi);

      // Tevkifatlar
      final dokuzOn = _tevkifatKayitlari
          .where((x) => x.birimAdi != null && BirimAdlandirma.tamAdGetir(x.birimAdi!) == b && x.tevkifatTuru == TevkifatTuru.dokuzBoluOn)
          .fold(0.0, (s, x) => s + x.tevkifatTutari);
      final yediOn = _tevkifatKayitlari
          .where((x) => x.birimAdi != null && BirimAdlandirma.tamAdGetir(x.birimAdi!) == b && x.tevkifatTuru == TevkifatTuru.yediBoluOn)
          .fold(0.0, (s, x) => s + x.tevkifatTutari);
      final besOn = _tevkifatKayitlari
          .where((x) => x.birimAdi != null && BirimAdlandirma.tamAdGetir(x.birimAdi!) == b && x.tevkifatTuru == TevkifatTuru.besBoluOn)
          .fold(0.0, (s, x) => s + x.tevkifatTutari);

      list.add(
        BirimVergiIcmalSatiri(
          birimAdi: b,
          kdv1Tutari: BeyannameHesaplamaMotoru.round(kdv1),
          damgaVb: BeyannameHesaplamaMotoru.round(damga),
          muhtasarGelir: BeyannameHesaplamaMotoru.round(mGelir),
          muhtasarDamga: BeyannameHesaplamaMotoru.round(mDamga),
          muhtasarKesilenDamga: BeyannameHesaplamaMotoru.round(damga),
          kdv2DokuzBoluOn: BeyannameHesaplamaMotoru.round(dokuzOn),
          kdv2YediBoluOn: BeyannameHesaplamaMotoru.round(yediOn),
          kdv2BesBoluOn: BeyannameHesaplamaMotoru.round(besOn),
        ),
      );
    }
    return list;
  }

  BeyannameProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sistemBirimleri = await _birimService.getAll();
      await donemYukle(_seciliYil, _seciliAy);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void donemDegistir(int yil, int ay) {
    _seciliYil = yil;
    _seciliAy = ay;
    donemYukle(yil, ay);
  }

  String _docId(int yil, int ay) => '${yil}_${ay.toString().padLeft(2, '0')}';

  Future<void> donemYukle(int yil, int ay) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('beyannameler')
          .doc(_docId(yil, ay))
          .get();

      if (doc.exists && doc.data() != null) {
        final model = BeyannameDonemModel.fromMap(doc.data()!);

        // Eski veya mükerrer kayıtları standartlaştır ve tekilleştir
        final Map<String, Kdv1BirimSatiri> kdv1Map = {};
        for (final k in model.kdv1Satirlari) {
          final tamAd = BirimAdlandirma.tamAdGetir(k.birimAdi);
          final key = BirimAdlandirma.canonicalKey(tamAd);
          if (kdv1Map.containsKey(key)) {
            final ex = kdv1Map[key]!;
            kdv1Map[key] = ex.copyWith(
              hesaplananKdv10: ex.hesaplananKdv10 + k.hesaplananKdv10,
              hesaplananMatrah10: ex.hesaplananMatrah10 + k.hesaplananMatrah10,
              hesaplananKdv20: ex.hesaplananKdv20 + k.hesaplananKdv20,
              hesaplananMatrah20: ex.hesaplananMatrah20 + k.hesaplananMatrah20,
              indirilecekKdv10: ex.indirilecekKdv10 + k.indirilecekKdv10,
              indirilecekMatrah10: ex.indirilecekMatrah10 + k.indirilecekMatrah10,
              indirilecekKdv20: ex.indirilecekKdv20 + k.indirilecekKdv20,
              indirilecekMatrah20: ex.indirilecekMatrah20 + k.indirilecekMatrah20,
            );
          } else {
            kdv1Map[key] = k.copyWith(birimAdi: tamAd);
          }
        }
        _kdv1Satirlari = kdv1Map.values.toList();

        _tevkifatKayitlari = model.tevkifatKayitlari.map((t) => t.copyWith(
          birimAdi: t.birimAdi != null ? BirimAdlandirma.tamAdGetir(t.birimAdi!) : null,
        )).toList();

        _muhtasarSatirlari = model.muhtasarSatirlari.map((m) => m.copyWith(
          birimAdi: BirimAdlandirma.tamAdGetir(m.birimAdi),
        )).toList();

        final Map<String, DamgaVergisiBirimSatiri> damgaMap = {};
        for (final d in model.damgaSatirlari) {
          final tamAd = BirimAdlandirma.tamAdGetir(d.birimAdi);
          final key = BirimAdlandirma.canonicalKey(tamAd);
          if (damgaMap.containsKey(key)) {
            final ex = damgaMap[key]!;
            damgaMap[key] = ex.copyWith(
              damgaVergisi: ex.damgaVergisi + d.damgaVergisi,
              matrah: ex.matrah + d.matrah,
            );
          } else {
            damgaMap[key] = d.copyWith(birimAdi: tamAd);
          }
        }
        _damgaSatirlari = damgaMap.values.toList();

        final Map<String, Hasiat600BirimSatiri> hasiatMap = {};
        for (final h in model.hasiat600Satirlari) {
          final tamAd = BirimAdlandirma.tamAdGetir(h.birimAdi);
          final key = BirimAdlandirma.canonicalKey(tamAd);
          if (hasiatMap.containsKey(key)) {
            final ex = hasiatMap[key]!;
            hasiatMap[key] = ex.copyWith(
              oncekiAylarHasilat600: ex.oncekiAylarHasilat600 + h.oncekiAylarHasilat600,
              aylikHasilat600: ex.aylikHasilat600 + h.aylikHasilat600,
              kumulatifHasilat600: ex.kumulatifHasilat600 + h.kumulatifHasilat600,
              krediKarti123: ex.krediKarti123 + h.krediKarti123,
            );
          } else {
            hasiatMap[key] = h.copyWith(birimAdi: tamAd);
          }
        }
        _hasiat600Satirlari = hasiatMap.values.toList();
      } else {
        // İlk kez açılıyorsa sistem birimleriyle varsayılan satırları başlat
        _varsayilanSatirlariOlustur();
      }
      _guncelleDamga301();
    } catch (e) {
      _errorMessage = 'Dönem yüklenirken hata: $e';
      _varsayilanSatirlariOlustur();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _varsayilanSatirlariOlustur() {
    final Set<String> uniqueUnits = {};
    if (_sistemBirimleri.isNotEmpty) {
      for (final b in _sistemBirimleri) {
        final tamAd = BirimAdlandirma.tamAdGetir(b.ad.isNotEmpty ? b.ad : b.kisaAd);
        if (tamAd.isNotEmpty) uniqueUnits.add(tamAd);
      }
    } else {
      for (final b in BirimModel.varsayilanBirimler) {
        uniqueUnits.add(b.ad);
      }
    }

    final varsayilanBirimler = uniqueUnits.toList()..sort();

    _kdv1Satirlari = varsayilanBirimler
        .map((b) => Kdv1BirimSatiri(
              birimId: BirimAdlandirma.canonicalKey(b),
              birimAdi: b,
            ))
        .toList();

    _tevkifatKayitlari = [];
    _muhtasarSatirlari = [];

    _damgaSatirlari = varsayilanBirimler
        .map((b) => DamgaVergisiBirimSatiri(birimAdi: b, damgaVergisi: 0, matrah: 0))
        .toList();

    _hasiat600Satirlari = varsayilanBirimler
        .map((b) => Hasiat600BirimSatiri(birimAdi: b))
        .toList();
  }

  void _guncelleDamga301() {
    _muhtasarKesilenDamgaVergisi301 =
        _damgaSatirlari.fold(0.0, (s, x) => s + x.damgaVergisi);
  }

  // --- KDV 1 Metotları ---
  void updateKdv1Satir(int index, Kdv1BirimSatiri satir) {
    if (index >= 0 && index < _kdv1Satirlari.length) {
      _kdv1Satirlari[index] = satir;
      notifyListeners();
    }
  }

  void addKdv1Birim(String birimAdi) {
    _kdv1Satirlari.add(Kdv1BirimSatiri(
      birimId: birimAdi.toLowerCase(),
      birimAdi: birimAdi,
    ));
    notifyListeners();
  }

  void removeKdv1Satir(int index) {
    if (index >= 0 && index < _kdv1Satirlari.length) {
      _kdv1Satirlari.removeAt(index);
      notifyListeners();
    }
  }

  // --- KDV 2 Tevkifat Metotları ---
  void addTevkifatKaydi(TevkifatFirmaKaydi kayit) {
    _tevkifatKayitlari.add(kayit);
    notifyListeners();
  }

  void updateTevkifatKaydi(int index, TevkifatFirmaKaydi kayit) {
    if (index >= 0 && index < _tevkifatKayitlari.length) {
      _tevkifatKayitlari[index] = kayit;
      notifyListeners();
    }
  }

  void removeTevkifatKaydi(int index) {
    if (index >= 0 && index < _tevkifatKayitlari.length) {
      _tevkifatKayitlari.removeAt(index);
      notifyListeners();
    }
  }

  // --- Muhtasar Metotları ---
  void addMuhtasarSatir(MuhtasarSatiri satir) {
    _muhtasarSatirlari.add(satir);
    notifyListeners();
  }

  void updateMuhtasarSatir(int index, MuhtasarSatiri satir) {
    if (index >= 0 && index < _muhtasarSatirlari.length) {
      _muhtasarSatirlari[index] = satir;
      notifyListeners();
    }
  }

  void removeMuhtasarSatir(int index) {
    if (index >= 0 && index < _muhtasarSatirlari.length) {
      _muhtasarSatirlari.removeAt(index);
      notifyListeners();
    }
  }

  // --- Damga Vergisi Metotları ---
  void updateDamgaSatir(int index, double damgaTutari) {
    if (index >= 0 && index < _damgaSatirlari.length) {
      final cur = _damgaSatirlari[index];
      final matrah = BeyannameHesaplamaMotoru.matrahFromDamga(damgaTutari);
      _damgaSatirlari[index] = DamgaVergisiBirimSatiri(
        birimAdi: cur.birimAdi,
        damgaVergisi: damgaTutari,
        matrah: matrah,
      );
      _guncelleDamga301();
      notifyListeners();
    }
  }

  // --- 600 Hasılat Metotları ---
  void updateHasiatSatir(
    int index, {
    double? oncekiAylar,
    double? aylik,
    double? kumulatif,
    double? krediKarti,
  }) {
    if (index >= 0 && index < _hasiat600Satirlari.length) {
      final cur = _hasiat600Satirlari[index];
      double newOnceki = oncekiAylar ?? cur.oncekiAylarHasilat600;
      double newAylik = aylik ?? cur.aylikHasilat600;
      double newKumulatif = kumulatif ?? cur.kumulatifHasilat600;

      // Aylık girildiyse: kümülatif = önceki + aylık
      if (aylik != null) {
        newKumulatif = BeyannameHesaplamaMotoru.round(newOnceki + newAylik);
      } else if (kumulatif != null) {
        // Kümülatif girildiyse: aylık = kümülatif - önceki
        newAylik = BeyannameHesaplamaMotoru.round(newKumulatif - newOnceki);
        if (newAylik < 0) newAylik = 0.0;
      } else if (oncekiAylar != null) {
        newKumulatif = BeyannameHesaplamaMotoru.round(newOnceki + newAylik);
      }

      _hasiat600Satirlari[index] = cur.copyWith(
        oncekiAylarHasilat600: newOnceki,
        aylikHasilat600: newAylik,
        kumulatifHasilat600: newKumulatif,
        krediKarti123: krediKarti ?? cur.krediKarti123,
      );
      notifyListeners();
    }
  }

  // --- Kaydetme ---
  Future<bool> kaydet() async {
    _isLoading = true;
    notifyListeners();

    try {
      final model = BeyannameDonemModel(
        id: _docId(_seciliYil, _seciliAy),
        yil: _seciliYil,
        ay: _seciliAy,
        baslik: '$_seciliYil / ${_seciliAy.toString().padLeft(2, '0')} Beyannamesi',
        guncellenmeTarihi: DateTime.now(),
        kdv1Satirlari: _kdv1Satirlari,
        tevkifatKayitlari: _tevkifatKayitlari,
        muhtasarSatirlari: _muhtasarSatirlari,
        damgaSatirlari: _damgaSatirlari,
        hasiat600Satirlari: _hasiat600Satirlari,
      );

      await _firestore
          .collection('beyannameler')
          .doc(model.id)
          .set(model.toMap());

      return true;
    } catch (e) {
      _errorMessage = 'Kaydedilirken hata oluştu: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Örnek Excel Verilerini Tek Tıkla Yükle (Eylül 2025 Test/Demo Verisi)
  void ornekEylulVerisiniYukle() {
    final dtsAd = BirimAdlandirma.tamAdGetir('DTS');
    final ubatamAd = BirimAdlandirma.tamAdGetir('UBATAM');
    final tomerAd = BirimAdlandirma.tamAdGetir('TÖMER');
    final usemAd = BirimAdlandirma.tamAdGetir('USEM');
    final dosimAd = BirimAdlandirma.tamAdGetir('DÖSİM');
    final tadaumAd = BirimAdlandirma.tamAdGetir('TADAUM');
    final disAd = BirimAdlandirma.tamAdGetir('Diş Hekimliği');

    // 1. KDV 1
    _kdv1Satirlari = [
      Kdv1BirimSatiri(
        birimId: 'dts',
        birimAdi: dtsAd,
        hesaplananKdv20: 1000.0,
        hesaplananMatrah20: 5000.0,
      ),
      Kdv1BirimSatiri(
        birimId: 'ubatam',
        birimAdi: ubatamAd,
        hesaplananKdv20: 63372.28,
        hesaplananMatrah20: 316861.40,
        indirilecekKdv10: 414.50,
        indirilecekMatrah10: 4145.00,
        indirilecekKdv20: 18351.18,
        indirilecekMatrah20: 91755.90,
      ),
      Kdv1BirimSatiri(
        birimId: 'tomer',
        birimAdi: tomerAd,
        indirilecekKdv10: 980.0,
        indirilecekMatrah10: 9800.0,
        indirilecekKdv20: 5039.0,
        indirilecekMatrah20: 25195.0,
      ),
      Kdv1BirimSatiri(
        birimId: 'usem',
        birimAdi: usemAd,
        indirilecekKdv10: 625.0,
        indirilecekMatrah10: 6250.0,
        indirilecekKdv20: 950.0,
        indirilecekMatrah20: 4750.0,
      ),
      Kdv1BirimSatiri(birimId: 'dosim', birimAdi: dosimAd),
      Kdv1BirimSatiri(birimId: 'tadaum', birimAdi: tadaumAd),
      Kdv1BirimSatiri(birimId: 'dis', birimAdi: disAd),
    ];

    // 2. KDV 2 Tevkifat
    _tevkifatKayitlari = [
      TevkifatFirmaKaydi(
        id: '1',
        firmaAdi: 'GRAND DENTAL DİŞ PROTEZ LAB. HİZ.TİC.LTD.ŞTİ.',
        vergiTcNo: '4110649065',
        tevkifatTuru: TevkifatTuru.dokuzBoluOn,
        kdvOrani: 10,
        matrahTutari: 540000.0,
        kdvTutari: 54000.0,
        tevkifatTutari: 48600.0,
        birimAdi: disAd,
      ),
      TevkifatFirmaKaydi(
        id: '2',
        firmaAdi: 'METASOFT BİLGİ TEKNOLOJİLERİ A.Ş.',
        vergiTcNo: '6191268620',
        tevkifatTuru: TevkifatTuru.dokuzBoluOn,
        kdvOrani: 20,
        matrahTutari: 113872.0,
        kdvTutari: 22774.40,
        tevkifatTutari: 20496.96,
        birimAdi: disAd,
      ),
      TevkifatFirmaKaydi(
        id: '3',
        firmaAdi: 'MİROĞLU ÇEVRE SANAYİ TİCARET A.Ş.',
        vergiTcNo: '6210490464',
        tevkifatTuru: TevkifatTuru.dokuzBoluOn,
        kdvOrani: 20,
        matrahTutari: 39753.44,
        kdvTutari: 7950.69,
        tevkifatTutari: 7155.62,
        birimAdi: disAd,
      ),
      TevkifatFirmaKaydi(
        id: '4',
        firmaAdi: 'KONE ASANSÖR SANAYİ VE TİCARET ANONİM ŞİRKETİ',
        vergiTcNo: '8340057092',
        tevkifatTuru: TevkifatTuru.yediBoluOn,
        kdvOrani: 20,
        matrahTutari: 2394.0,
        kdvTutari: 478.80,
        tevkifatTutari: 335.16,
        birimAdi: disAd,
      ),
      TevkifatFirmaKaydi(
        id: '5',
        firmaAdi: 'UŞAK NK MÜHENDİSLİK ELEKTRİK OTOMOTİV SANAYİ VE TİC. LİMİTED ŞİRKETİ',
        vergiTcNo: '8960855757',
        tevkifatTuru: TevkifatTuru.yediBoluOn,
        kdvOrani: 20,
        matrahTutari: 36250.0,
        kdvTutari: 7250.0,
        tevkifatTutari: 5075.0,
        birimAdi: disAd,
      ),
      TevkifatFirmaKaydi(
        id: '6',
        firmaAdi: 'UŞAK NOKTA ENERJİ YAPI MÜH. TEKS. TAR. VE HAYV. SAN. VE TİC. LTD. ŞTİ.',
        vergiTcNo: '8960706737',
        tevkifatTuru: TevkifatTuru.yediBoluOn,
        kdvOrani: 20,
        matrahTutari: 20499.0,
        kdvTutari: 4099.80,
        tevkifatTutari: 2869.86,
        birimAdi: disAd,
      ),
    ];

    // 3. Muhtasar
    _muhtasarSatirlari = [
      MuhtasarSatiri(
        id: '1',
        birimAdi: dosimAd,
        adSoyad: 'Ercan BİLGEÇ',
        kisiSayisi: 1,
        brutUcret: 18388.47,
        gelirVergisi: 0.0,
        damgaVergisi: 417.35,
        netOdenen: 73903.70,
        aylikGelirVergisiMatrahi: 18388.47,
      ),
      MuhtasarSatiri(
        id: '2',
        birimAdi: ubatamAd,
        adSoyad: 'Erkan HALAY',
        kisiSayisi: 1,
        brutUcret: 22562.90,
        gelirVergisi: 4512.58,
        damgaVergisi: 171.25,
        netOdenen: 17879.07,
        aylikGelirVergisiMatrahi: 18633.64,
      ),
      MuhtasarSatiri(
        id: '3',
        birimAdi: ubatamAd,
        adSoyad: 'Erkan HALAY (Ek)',
        kisiSayisi: 0,
        brutUcret: 20668.53,
        gelirVergisi: 4133.71,
        damgaVergisi: 156.87,
        netOdenen: 16377.95,
        aylikGelirVergisiMatrahi: 18633.64,
      ),
      MuhtasarSatiri(
        id: '4',
        birimAdi: ubatamAd,
        adSoyad: 'Ayşe ŞEVKAN MACİT',
        kisiSayisi: 1,
        brutUcret: 3196.64,
        gelirVergisi: 566.74,
        damgaVergisi: 24.26,
        netOdenen: 2605.64,
        aylikGelirVergisiMatrahi: 18865.12,
      ),
      MuhtasarSatiri(
        id: '5',
        birimAdi: dtsAd,
        adSoyad: 'CEYDA SIKI',
        kisiSayisi: 1,
        brutUcret: 18374.40,
        gelirVergisi: 2756.16,
        damgaVergisi: 139.46,
        netOdenen: 15478.78,
        aylikGelirVergisiMatrahi: 18150.82,
      ),
      MuhtasarSatiri(
        id: '6',
        birimAdi: ubatamAd,
        adSoyad: 'Ayşe ŞEVKAN MACİT (Ek)',
        kisiSayisi: 1,
        brutUcret: 1186.58,
        gelirVergisi: 237.32,
        damgaVergisi: 9.01,
        netOdenen: 940.25,
        aylikGelirVergisiMatrahi: 18865.12,
      ),
      MuhtasarSatiri(
        id: '7',
        birimAdi: dtsAd,
        adSoyad: 'EREN ÖNER',
        kisiSayisi: 1,
        brutUcret: 6210.00,
        gelirVergisi: 0.0,
        damgaVergisi: 47.13,
        netOdenen: 6162.87,
        aylikGelirVergisiMatrahi: 18555.24,
      ),
      MuhtasarSatiri(
        id: '8',
        birimAdi: dtsAd,
        adSoyad: 'NESLİHAN ÖPÖZ VURAL',
        kisiSayisi: 1,
        brutUcret: 6060.00,
        gelirVergisi: 0.0,
        damgaVergisi: 45.99,
        netOdenen: 6014.01,
        aylikGelirVergisiMatrahi: 18073.11,
      ),
      MuhtasarSatiri(
        id: '9',
        birimAdi: dtsAd,
        adSoyad: 'GÜLÇİN ÇAVDAR',
        kisiSayisi: 1,
        brutUcret: 18374.40,
        gelirVergisi: 2756.16,
        damgaVergisi: 139.46,
        netOdenen: 15478.78,
        aylikGelirVergisiMatrahi: 18163.69,
      ),
      MuhtasarSatiri(
        id: '10',
        birimAdi: dtsAd,
        adSoyad: 'CEYDA SIKI (Ek)',
        kisiSayisi: 0,
        brutUcret: 6060.00,
        gelirVergisi: 0.0,
        damgaVergisi: 45.99,
        netOdenen: 6014.01,
        aylikGelirVergisiMatrahi: 18150.82,
      ),
      MuhtasarSatiri(
        id: '11',
        birimAdi: usemAd,
        adSoyad: 'TOLGA YEŞİL',
        kisiSayisi: 1,
        brutUcret: 7488.00,
        gelirVergisi: 1497.60,
        damgaVergisi: 56.83,
        netOdenen: 5933.57,
        aylikGelirVergisiMatrahi: 18865.76,
      ),
    ];

    // 4. Damga Vergisi (Binde 9,48)
    _damgaSatirlari = [
      DamgaVergisiBirimSatiri(
        birimAdi: usemAd,
        damgaVergisi: 104.28,
        matrah: BeyannameHesaplamaMotoru.matrahFromDamga(104.28),
      ),
      DamgaVergisiBirimSatiri(
        birimAdi: ubatamAd,
        damgaVergisi: 761.70,
        matrah: BeyannameHesaplamaMotoru.matrahFromDamga(761.70),
      ),
      DamgaVergisiBirimSatiri(birimAdi: dosimAd, damgaVergisi: 0, matrah: 0),
      DamgaVergisiBirimSatiri(birimAdi: tadaumAd, damgaVergisi: 0, matrah: 0),
      DamgaVergisiBirimSatiri(birimAdi: dtsAd, damgaVergisi: 0, matrah: 0),
    ];

    // 5. 600 Hasılat (Önceki 8 Ay + Bu Ay = Kümülatif)
    _oncekiAydanDevredenKdv = 0.0;
    _hasiat600Satirlari = [
      Hasiat600BirimSatiri(
        birimAdi: usemAd,
        oncekiAylarHasilat600: 190000.0,
        aylikHasilat600: 32000.0,
        kumulatifHasilat600: 222000.0,
      ),
      Hasiat600BirimSatiri(
        birimAdi: ubatamAd,
        oncekiAylarHasilat600: 3500000.0,
        aylikHasilat600: 519893.70,
        kumulatifHasilat600: 4019893.70,
      ),
      Hasiat600BirimSatiri(
        birimAdi: tomerAd,
        oncekiAylarHasilat600: 2500000.0,
        aylikHasilat600: 345000.91,
        kumulatifHasilat600: 2845000.91,
      ),
      Hasiat600BirimSatiri(
        birimAdi: dosimAd,
        oncekiAylarHasilat600: 150000.0,
        aylikHasilat600: 29500.0,
        kumulatifHasilat600: 179500.0,
      ),
      Hasiat600BirimSatiri(
        birimAdi: tadaumAd,
        oncekiAylarHasilat600: 20000.0,
        aylikHasilat600: 1150.0,
        kumulatifHasilat600: 21150.0,
      ),
      Hasiat600BirimSatiri(
        birimAdi: dtsAd,
        oncekiAylarHasilat600: 1200000.0,
        aylikHasilat600: 274481.72,
        kumulatifHasilat600: 1474481.72,
      ),
      Hasiat600BirimSatiri(
        birimAdi: disAd,
        oncekiAylarHasilat600: 95391836.62,
        aylikHasilat600: 10691249.01,
        kumulatifHasilat600: 106083085.63,
        krediKarti123: 2357688.27,
      ),
    ];

    _guncelleDamga301();
    notifyListeners();
  }
}
