import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/beyanname_model.dart';
import '../services/beyanname_hesaplama_motoru.dart';
import '../../birim/services/birim_service.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_konfigurasyonu.dart';
import '../services/beyanname_konfigurasyon_servisi.dart';
import '../models/beyanname_belge_model.dart';
import '../models/beyanname_denetim_rapor_model.dart';
import '../services/beyanname_ai_ajan_servisi.dart';
import '../services/beyanname_denetim_servisi.dart';
import '../services/mizan_deterministik_parser.dart';
import '../../../core/turkce_format.dart';

class BeyannameProvider with ChangeNotifier {
  FirebaseFirestore? _firestoreHarici;
  FirebaseFirestore get _firestore =>
      _firestoreHarici ??= FirebaseFirestore.instance;

  BirimService? _birimServiceHarici;
  BirimService get _birimService => _birimServiceHarici ??= BirimService();

  BeyannameKonfigurasyonServisi? _konfigServisiHarici;
  BeyannameKonfigurasyonServisi get _konfigServisi =>
      _konfigServisiHarici ??= BeyannameKonfigurasyonServisi();

  /// Yapılandırma dışarıdan (constructor) verildiyse Firestore'dan ezilmez.
  bool _konfigHarici = false;

  /// Kurum bazlı yapılandırma. Varsayılan değer mevcut tek-kurum
  /// davranışıyla birebir aynıdır (bkz. [BeyannameKonfigurasyonu.varsayilan]).
  /// Faz 1'de Firestore'dan kurum bazında yüklenip değiştirilecektir.
  BeyannameKonfigurasyonu _konfig = BeyannameKonfigurasyonu.varsayilan;
  BeyannameKonfigurasyonu get konfig => _konfig;

  /// Yapılandırmayı dışarıdan (örn. test veya anlık güncelleme) uygular.
  /// Bu çağrı yapıldıktan sonra başlangıçtaki Firestore okuması ezmez.
  void konfigAyarla(BeyannameKonfigurasyonu yeni) {
    _konfig = yeni;
    _konfigHarici = true;
    notifyListeners();
  }

  /// Kurum yapılandırmasını Firestore'dan yeniden okur.
  Future<void> konfigYenile() async {
    if (_konfigHarici) return;
    final yeni = await _konfigServisi.getir();
    _konfig = yeni;
    notifyListeners();
  }

  /// Kurum yapılandırmasını kaydeder ve bellekteki değeri günceller.
  Future<void> konfigKaydet(BeyannameKonfigurasyonu yeni) async {
    await _konfigServisi.kaydet(yeni);
    _konfig = yeni;
    _konfigHarici = true;
    notifyListeners();
  }

  /// Kuruma özel kaydı silip varsayılan yapılandırmaya döner.
  Future<void> konfigVarsayilanaDon() async {
    await _konfigServisi.varsayilanaDon();
    _konfig = BeyannameKonfigurasyonu.varsayilan;
    _konfigHarici = false;
    notifyListeners();
  }

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
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  // --- Kayıtlı Dönem ve Düzenleme Kilidi (Resmi Kayıt Koruma Mekanizması) ---
  bool _isDonemKayitli = false;
  bool get isDonemKayitli => _isDonemKayitli;

  bool _duzenlemeKilidiAcik = true;
  bool get duzenlemeKilidiAcik => _duzenlemeKilidiAcik;

  void kilidiAc() {
    _duzenlemeKilidiAcik = true;
    notifyListeners();
  }

  void kilitle() {
    _duzenlemeKilidiAcik = false;
    notifyListeners();
  }

  // --- Otomatik Taslak Kaydetme (Auto-Save / Elektrik & İnternet Kesintisi Koruması) ---
  bool _isAutoSaving = false;
  bool get isAutoSaving => _isAutoSaving;

  DateTime? _sonTaslakZamani;
  DateTime? get sonTaslakZamani => _sonTaslakZamani;

  Timer? _autoSaveDebounceTimer;

  void _tetikleYerelTaslakKaydi() {
    _autoSaveDebounceTimer?.cancel();
    _autoSaveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _yerelTaslagiKaydet();
    });
  }

  Future<void> _yerelTaslagiKaydet() async {
    try {
      _isAutoSaving = true;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final model = BeyannameDonemModel(
        id: _docId(_seciliYil, _seciliAy),
        yil: _seciliYil,
        ay: _seciliAy,
        baslik: '$_seciliYil / ${_seciliAy.toString().padLeft(2, '0')} Beyannamesi',
        guncellenmeTarihi: DateTime.now(),
        oncekiAydanDevredenKdv: _oncekiAydanDevredenKdv,
        kdv1Satirlari: _kdv1Satirlari,
        tevkifatKayitlari: _tevkifatKayitlari,
        muhtasarSatirlari: _muhtasarSatirlari,
        damgaSatirlari: _damgaSatirlari,
        hasiat600Satirlari: _hasiat600Satirlari,
      );
      await prefs.setString('beyanname_draft_${model.id}', jsonEncode(model.toMap()));
      _sonTaslakZamani = model.guncellenmeTarihi;
    } catch (e) {
      debugPrint('Yerel taslak kaydetme hatası: $e');
    } finally {
      _isAutoSaving = false;
      notifyListeners();
    }
  }

  /// Toplu Temizle / Sıfırla (Mevcut dönemin verilerini, tablolarını ve belgelerini sıfırlar)
  Future<void> donemiSifirla() async {
    _isLoading = true;
    notifyListeners();
    try {
      _autoSaveDebounceTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('beyanname_draft_${_docId(_seciliYil, _seciliAy)}');
      _sonTaslakZamani = null;
      _oncekiAydanDevredenKdv = 0.0;
      _tevkifatKayitlari.clear();
      _muhtasarSatirlari.clear();
      _yuklenenBelgeler.clear();
      _sonAjanRaporu = null;
      _aiAjanLoglari.clear();
      _aiAjanIlerleme = 0.0;
      _varsayilanSatirlariOlustur();
      _guncelleDamga301();
    } catch (e) {
      _errorMessage = 'Sıfırlama hatası: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Canlı Hesaplama Sonuçları
  Kdv1KonsolideSonuc get kdv1Sonuc =>
      BeyannameHesaplamaMotoru.hesaplaKdv1(
        _kdv1Satirlari,
        oncekiDonemdenDevredenKdv: _oncekiAydanDevredenKdv,
      );

  Kdv2KonsolideSonuc get kdv2Sonuc =>
      BeyannameHesaplamaMotoru.hesaplaKdv2(
        _tevkifatKayitlari,
        konfig: _konfig,
      );

  MuhtasarKonsolideSonuc get muhtasarSonuc =>
      BeyannameHesaplamaMotoru.hesaplaMuhtasar(
        satirlar: _muhtasarSatirlari,
        muhtasarKesilenDamgaVergisi301: _muhtasarKesilenDamgaVergisi301,
        yil: _seciliYil,
        ay: _seciliAy,
        konfig: _konfig,
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

  // Birim İcmal Tablosu (Kanonik Tekilleştirilmiş)
  List<BirimVergiIcmalSatiri> get birimIcmalListesi {
    final Map<String, String> keyToTamAd = {};

    for (final k in _kdv1Satirlari) {
      final key = BirimAdlandirma.canonicalKey(k.birimAdi);
      if (key.isNotEmpty && !keyToTamAd.containsKey(key)) {
        keyToTamAd[key] = BirimAdlandirma.tamAdGetir(k.birimAdi);
      }
    }
    for (final t in _tevkifatKayitlari) {
      if (t.birimAdi != null && t.birimAdi!.isNotEmpty) {
        final key = BirimAdlandirma.canonicalKey(t.birimAdi);
        if (key.isNotEmpty && !keyToTamAd.containsKey(key)) {
          keyToTamAd[key] = BirimAdlandirma.tamAdGetir(t.birimAdi);
        }
      }
    }
    for (final m in _muhtasarSatirlari) {
      final key = BirimAdlandirma.canonicalKey(m.birimAdi);
      if (key.isNotEmpty && !keyToTamAd.containsKey(key)) {
        keyToTamAd[key] = BirimAdlandirma.tamAdGetir(m.birimAdi);
      }
    }
    for (final d in _damgaSatirlari) {
      final key = BirimAdlandirma.canonicalKey(d.birimAdi);
      if (key.isNotEmpty && !keyToTamAd.containsKey(key)) {
        keyToTamAd[key] = BirimAdlandirma.tamAdGetir(d.birimAdi);
      }
    }

    final sortedKeys = keyToTamAd.keys.toList()..sort((a, b) => keyToTamAd[a]!.compareTo(keyToTamAd[b]!));
    final list = <BirimVergiIcmalSatiri>[];

    for (final key in sortedKeys) {
      final tamAd = keyToTamAd[key]!;

      final kdv1 = _kdv1Satirlari
          .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)
          .fold(0.0, (s, x) => s + x.netOdenecekKdv);
      final damga = _damgaSatirlari
          .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)
          .fold(0.0, (s, x) => s + x.damgaVergisi);
      final mGelir = _muhtasarSatirlari
          .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)
          .fold(0.0, (s, x) => s + x.gelirVergisi);
      final mDamga = _muhtasarSatirlari
          .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)
          .fold(0.0, (s, x) => s + x.damgaVergisi);

      // Tevkifatlar — kovalar konfigürasyondaki tevkifat tanımlarından
      // dinamik üretilir (etiket bazlı). Kayıtta özel etiket varsa o da
      // listeye eklenir; böylece kurum kendi tevkifat türünü tanımlayabilir.
      final tevkifatEtiketleri = <String>[
        for (final t in _konfig.tevkifatTurleri) t.etiket,
      ];
      for (final x in _tevkifatKayitlari) {
        if (x.birimAdi != null &&
            BirimAdlandirma.canonicalKey(x.birimAdi!) == key &&
            !tevkifatEtiketleri.contains(x.etiket)) {
          tevkifatEtiketleri.add(x.etiket);
        }
      }
      final kdv2TevkifatTutar = <String, double>{};
      for (final e in tevkifatEtiketleri) {
        final toplam = _tevkifatKayitlari
            .where((x) =>
                x.birimAdi != null &&
                BirimAdlandirma.canonicalKey(x.birimAdi!) == key &&
                x.etiket == e)
            .fold(0.0, (s, x) => s + x.tevkifatTutari);
        kdv2TevkifatTutar[e] = BeyannameHesaplamaMotoru.round(toplam);
      }

      list.add(
        BirimVergiIcmalSatiri(
          birimAdi: tamAd,
          kdv1Tutari: BeyannameHesaplamaMotoru.round(kdv1),
          // Excel "Birim Bazlı Vergiler" sayfasında "DAMGA V.B." kolonu
          // boş/0'dır; 301 damgası yalnızca "MUHTASAR ÖDEMELERİNDE KESİLEN
          // DAMGA" kolonunda yer alır. Buraya 0 yazılmazsa aynı damga hem
          // damgaVb hem muhtasarKesilenDamga alanına düşüp çift sayılır.
          damgaVb: 0.0,
          muhtasarGelir: BeyannameHesaplamaMotoru.round(mGelir),
          muhtasarDamga: BeyannameHesaplamaMotoru.round(mDamga),
          muhtasarKesilenDamga: BeyannameHesaplamaMotoru.round(damga),
          kdv2TevkifatTutar: kdv2TevkifatTutar,
        ),
      );
    }
    return list;
  }

  BeyannameProvider({BeyannameKonfigurasyonu? konfig}) {
    if (konfig != null) {
      _konfig = konfig;
      _konfigHarici = true;
    }
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Kurum yapılandırmasını yükle (dışarıdan verilmediyse).
      // Hata olsa bile varsayılan ile devam edilir; uygulama bloke olmaz.
      if (!_konfigHarici) {
        _konfig = await _konfigServisi.getir();
      }
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
      BeyannameDonemModel? draftModel;
      try {
        final prefs = await SharedPreferences.getInstance();
        final draftJson = prefs.getString('beyanname_draft_${_docId(yil, ay)}');
        if (draftJson != null && draftJson.isNotEmpty) {
          draftModel = BeyannameDonemModel.fromMap(jsonDecode(draftJson));
        }
      } catch (e) {
        debugPrint('Taslak okuma hatası: $e');
      }

      BeyannameDonemModel? firestoreModel;
      try {
        final doc = await _firestore
            .collection('beyannameler')
            .doc(_docId(yil, ay))
            .get();
        if (doc.exists && doc.data() != null) {
          firestoreModel = BeyannameDonemModel.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore okuma hatası: $e');
      }

      if (firestoreModel != null) {
        _isDonemKayitli = true;
        _duzenlemeKilidiAcik = false;
      } else {
        _isDonemKayitli = false;
        _duzenlemeKilidiAcik = true;
      }

      if (draftModel != null && firestoreModel != null) {
        if (draftModel.guncellenmeTarihi.isAfter(firestoreModel.guncellenmeTarihi)) {
          _applyModel(draftModel);
          _sonTaslakZamani = draftModel.guncellenmeTarihi;
        } else {
          _applyModel(firestoreModel);
          _sonTaslakZamani = firestoreModel.guncellenmeTarihi;
        }
      } else if (draftModel != null) {
        _applyModel(draftModel);
        _sonTaslakZamani = draftModel.guncellenmeTarihi;
      } else if (firestoreModel != null) {
        _applyModel(firestoreModel);
        _sonTaslakZamani = firestoreModel.guncellenmeTarihi;
      } else {
        _varsayilanSatirlariOlustur();
        if (ay > 1) {
          try {
            await gecmisAylariSenkronizeEt(sessiz: true);
          } catch (_) {}
        }
      }
      _guncelleDamga301();
    } catch (e) {
      _errorMessage = 'Dönem yüklenirken hata: $e';
      _varsayilanSatirlariOlustur();
      if (ay > 1) {
        try {
          await gecmisAylariSenkronizeEt(sessiz: true);
        } catch (_) {}
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyModel(BeyannameDonemModel model) {
    _oncekiAydanDevredenKdv = model.oncekiAydanDevredenKdv;

    // KDV 1 Satırlarını kanonik tekilleştir
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
  }

  void _varsayilanSatirlariOlustur() {
    final Map<String, String> canonicalUnits = {};
    if (_sistemBirimleri.isNotEmpty) {
      for (final b in _sistemBirimleri) {
        final rawName = b.ad.isNotEmpty ? b.ad : b.kisaAd;
        final key = BirimAdlandirma.canonicalKey(rawName);
        final tamAd = BirimAdlandirma.tamAdGetir(rawName);
        if (key.isNotEmpty && tamAd.isNotEmpty) {
          canonicalUnits[key] = tamAd;
        }
      }
    }
    // Kurumun `birimler` koleksiyonundan birim geldiyse onu esas al; yalnızca
    // hiç birim tanımlı değilse (boş sistem) sabit varsayılanlara düş.
    // Böylece her kurum kendi birim listesiyle çalışır (çok kiracılı).
    if (canonicalUnits.isEmpty) {
      for (final b in BirimModel.varsayilanBirimler) {
        final key = BirimAdlandirma.canonicalKey(b.ad);
        if (!canonicalUnits.containsKey(key)) {
          canonicalUnits[key] = b.ad;
        }
      }
    }

    final varsayilanBirimler = canonicalUnits.values.toList()..sort();

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
    // 301 (ödemelerden kesilen damga) tüm damga satırlarını kapsar; masalar
    // her birimi eksiksiz hesaplar (ayrıştırma yalnızca özet görünümündedir).
    _muhtasarKesilenDamgaVergisi301 =
        _damgaSatirlari.fold(0.0, (s, x) => s + x.damgaVergisi);
  }

  // --- Birim Ekleme & Çıkarma (Silme) ---
  void addBirim(String birimAdi) {
    final tamAd = BirimAdlandirma.tamAdGetir(birimAdi);
    final key = BirimAdlandirma.canonicalKey(tamAd);
    if (key.isEmpty) return;

    // Eğer zaten varsa ekleme
    final exists = _kdv1Satirlari.any((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key);
    if (!exists) {
      _kdv1Satirlari.add(Kdv1BirimSatiri(birimId: key, birimAdi: tamAd));
    }
    if (!_damgaSatirlari.any((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)) {
      _damgaSatirlari.add(DamgaVergisiBirimSatiri(birimAdi: tamAd, damgaVergisi: 0, matrah: 0));
    }
    if (!_hasiat600Satirlari.any((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key)) {
      _hasiat600Satirlari.add(Hasiat600BirimSatiri(birimAdi: tamAd));
    }

    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  void removeBirim(String birimAdi) {
    final key = BirimAdlandirma.canonicalKey(birimAdi);
    if (key.isEmpty) return;

    _kdv1Satirlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key);
    _damgaSatirlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key);
    _hasiat600Satirlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key);
    _tevkifatKayitlari.removeWhere((x) => x.birimAdi != null && BirimAdlandirma.canonicalKey(x.birimAdi!) == key);
    _muhtasarSatirlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == key);

    _guncelleDamga301();
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  // --- KDV 1 Metotları ---
  void updateKdv1Satir(int index, Kdv1BirimSatiri satir) {
    if (index >= 0 && index < _kdv1Satirlari.length) {
      _kdv1Satirlari[index] = satir;
      _tetikleYerelTaslakKaydi();
      notifyListeners();
    }
  }

  void addKdv1Birim(String birimAdi) => addBirim(birimAdi);

  void removeKdv1Satir(int index) {
    if (index >= 0 && index < _kdv1Satirlari.length) {
      final s = _kdv1Satirlari[index];
      removeBirim(s.birimAdi);
    }
  }

  // --- KDV 2 Tevkifat Metotları ---
  void addTevkifatKaydi(TevkifatFirmaKaydi kayit) {
    _tevkifatKayitlari.add(kayit);
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  void updateTevkifatKaydi(int index, TevkifatFirmaKaydi kayit) {
    if (index >= 0 && index < _tevkifatKayitlari.length) {
      _tevkifatKayitlari[index] = kayit;
      _tetikleYerelTaslakKaydi();
      notifyListeners();
    }
  }

  void removeTevkifatKaydi(int index) {
    if (index >= 0 && index < _tevkifatKayitlari.length) {
      _tevkifatKayitlari.removeAt(index);
      _tetikleYerelTaslakKaydi();
      notifyListeners();
    }
  }

  // --- Muhtasar Metotları ---
  void addMuhtasarSatir(MuhtasarSatiri satir) {
    _muhtasarSatirlari.add(satir);
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  void updateMuhtasarSatir(int index, MuhtasarSatiri satir) {
    if (index >= 0 && index < _muhtasarSatirlari.length) {
      _muhtasarSatirlari[index] = satir;
      _tetikleYerelTaslakKaydi();
      notifyListeners();
    }
  }

  void removeMuhtasarSatir(int index) {
    if (index >= 0 && index < _muhtasarSatirlari.length) {
      _muhtasarSatirlari.removeAt(index);
      _tetikleYerelTaslakKaydi();
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
      _tetikleYerelTaslakKaydi();
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

      if (aylik != null && kumulatif != null) {
        // Hem aylık hem kümülatif aynı anda verildiyse önceki ayları türet
        if (oncekiAylar == null && newKumulatif >= newAylik) {
          newOnceki = BeyannameHesaplamaMotoru.round(newKumulatif - newAylik);
        }
      } else if (aylik != null) {
        // Kullanıcı önce Kümülatif girmiş (önceki=0 iken aylık=kümülatif olmuş) ve
        // şimdi Bu Ay'ı giriyorsa: Kümülatif'i ezme, Önceki Aylar = Kümülatif - Bu Ay yap.
        final kumulatifOncedenGirilmis = cur.oncekiAylarHasilat600 == 0 &&
            cur.kumulatifHasilat600 > newAylik &&
            (cur.aylikHasilat600 == 0 ||
                (cur.aylikHasilat600 - cur.kumulatifHasilat600).abs() < 0.01);
        if (kumulatifOncedenGirilmis) {
          newOnceki = BeyannameHesaplamaMotoru.round(newKumulatif - newAylik);
        } else {
          newKumulatif = BeyannameHesaplamaMotoru.round(newOnceki + newAylik);
        }
      } else if (kumulatif != null) {
        // Kullanıcı önce Bu Ay'ı girmiş (önceki=0 iken) ve şimdi Kümülatif giriyorsa:
        // Bu Ay'ı ezme, Önceki Aylar = Kümülatif - Bu Ay yap.
        if (newOnceki == 0 && cur.aylikHasilat600 > 0 && newKumulatif >= cur.aylikHasilat600) {
          newOnceki = BeyannameHesaplamaMotoru.round(newKumulatif - cur.aylikHasilat600);
          newAylik = cur.aylikHasilat600;
        } else {
          newAylik = BeyannameHesaplamaMotoru.round(newKumulatif - newOnceki);
          if (newAylik < 0) newAylik = 0.0;
        }
      } else if (oncekiAylar != null) {
        // Kullanıcı önce Kümülatif girmiş ve şimdi Önceki Aylar'ı giriyorsa:
        // Kümülatif'i koru, Bu Ay = Kümülatif - Önceki Aylar yap.
        final kumulatifOncedenGirilmis = cur.oncekiAylarHasilat600 == 0 &&
            cur.kumulatifHasilat600 > 0 &&
            (cur.aylikHasilat600 - cur.kumulatifHasilat600).abs() < 0.01 &&
            cur.kumulatifHasilat600 >= newOnceki;
        if (kumulatifOncedenGirilmis) {
          newAylik = BeyannameHesaplamaMotoru.round(newKumulatif - newOnceki);
        } else {
          newKumulatif = BeyannameHesaplamaMotoru.round(newOnceki + newAylik);
        }
      }

      _hasiat600Satirlari[index] = cur.copyWith(
        oncekiAylarHasilat600: newOnceki,
        aylikHasilat600: newAylik,
        kumulatifHasilat600: newKumulatif,
        krediKarti123: krediKarti ?? cur.krediKarti123,
      );
      _tetikleYerelTaslakKaydi();
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
        oncekiAydanDevredenKdv: _oncekiAydanDevredenKdv,
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

      _isDonemKayitli = true;
      _duzenlemeKilidiAcik = false;

      // Yerel taslağı da güncelle ve senkronize et
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('beyanname_draft_${model.id}', jsonEncode(model.toMap()));
      _sonTaslakZamani = model.guncellenmeTarihi;

      return true;
    } catch (e) {
      _errorMessage = 'Kaydedilirken hata oluştu: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Geriye Dönük Vergi & Birim Arama Servisleri ---
  Future<List<BeyannameDonemModel>> tumGecmisDonemleriYukle() async {
    try {
      final snapshot = await _firestore.collection('beyannameler').get();
      final list = <BeyannameDonemModel>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(BeyannameDonemModel.fromMap(doc.data()));
        } catch (_) {}
      }
      // Cari (açık olan) dönemi de ekle (eğer henüz veritabanına kaydedilmediyse bile aramada çıksın)
      final cariId = _docId(_seciliYil, _seciliAy);
      final alreadyInList = list.any((d) => d.id == cariId);
      if (!alreadyInList) {
        list.add(
          BeyannameDonemModel(
            id: cariId,
            yil: _seciliYil,
            ay: _seciliAy,
            baslik: '$_seciliYil / ${_seciliAy.toString().padLeft(2, '0')} (Cari Dönem)',
            guncellenmeTarihi: DateTime.now(),
            oncekiAydanDevredenKdv: _oncekiAydanDevredenKdv,
            kdv1Satirlari: _kdv1Satirlari,
            tevkifatKayitlari: _tevkifatKayitlari,
            muhtasarSatirlari: _muhtasarSatirlari,
            damgaSatirlari: _damgaSatirlari,
            hasiat600Satirlari: _hasiat600Satirlari,
          ),
        );
      }

      // Yıl ve aya göre azalan sırala
      list.sort((a, b) {
        if (a.yil != b.yil) return b.yil.compareTo(a.yil);
        return b.ay.compareTo(a.ay);
      });
      return list;
    } catch (e) {
      debugPrint('Geçmiş dönemler yüklenirken hata: $e');
      return [];
    }
  }

  /// Belirli bir yılın hedef ayından önceki (1..hedefAy-1) kayıtlı aylarını toplayarak
  /// Mizan Mutabakatı özetini oluşturur.
  Future<GecmisDonemHasilatOzeti> gecmisAylariHesapla(int yil, int hedefAy) async {
    if (hedefAy <= 1) {
      return GecmisDonemHasilatOzeti(
        yil: yil,
        hedefAy: hedefAy,
        bulunanAylar: const [],
        birimHasilatToplami: const {},
        birimKrediKartiToplami: const {},
        toplamHasilat: 0.0,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final List<int> bulunanAylar = [];
    final Map<String, double> birimHasilatToplami = {};
    final Map<String, double> birimKrediKartiToplami = {};
    double? sonAydanDevredenKdv;

    for (int ay = 1; ay < hedefAy; ay++) {
      final docKey = _docId(yil, ay);
      BeyannameDonemModel? model;

      // 1. Önce yerel taslaktan oku (en güncel çalışma olabilir)
      try {
        final draftJson = prefs.getString('beyanname_draft_$docKey');
        if (draftJson != null && draftJson.isNotEmpty) {
          model = BeyannameDonemModel.fromMap(jsonDecode(draftJson));
        }
      } catch (_) {}

      // 2. Firestore'dan oku
      try {
        final doc = await _firestore.collection('beyannameler').doc(docKey).get();
        if (doc.exists && doc.data() != null) {
          final fModel = BeyannameDonemModel.fromMap(doc.data()!);
          if (model == null || fModel.guncellenmeTarihi.isAfter(model.guncellenmeTarihi)) {
            model = fModel;
          }
        }
      } catch (_) {}

      if (model != null) {
        bulunanAylar.add(ay);
        for (final h in model.hasiat600Satirlari) {
          final key = BirimAdlandirma.canonicalKey(h.birimAdi);
          if (key.isNotEmpty) {
            birimHasilatToplami[key] = (birimHasilatToplami[key] ?? 0.0) + h.aylikHasilat600;
            birimKrediKartiToplami[key] = (birimKrediKartiToplami[key] ?? 0.0) + h.krediKarti123;
          }
        }

        // Eğer hedef ayın hemen bir önceki ayı ise, devreden KDV'yi de al
        if (ay == hedefAy - 1) {
          final k1Sonuc = BeyannameHesaplamaMotoru.hesaplaKdv1(
            model.kdv1Satirlari,
            oncekiDonemdenDevredenKdv: model.oncekiAydanDevredenKdv,
          );
          if (k1Sonuc.sonrakiDonemeDevredenKdv > 0) {
            sonAydanDevredenKdv = k1Sonuc.sonrakiDonemeDevredenKdv;
          }
        }
      }
    }

    final double toplam = birimHasilatToplami.values.fold(0.0, (s, v) => s + v);

    return GecmisDonemHasilatOzeti(
      yil: yil,
      hedefAy: hedefAy,
      bulunanAylar: bulunanAylar,
      birimHasilatToplami: birimHasilatToplami,
      birimKrediKartiToplami: birimKrediKartiToplami,
      toplamHasilat: toplam,
      sonAydanDevredenKdv: sonAydanDevredenKdv,
    );
  }

  /// Geçmiş aylardan hasılatı otomatik çekip 600 Masası ve Devreden KDV'ye yansıtır
  Future<GecmisDonemHasilatOzeti> gecmisAylariSenkronizeEt({bool sessiz = false}) async {
    final ozet = await gecmisAylariHesapla(_seciliYil, _seciliAy);
    if (ozet.bosMu) {
      return ozet;
    }

    // 1. 600 Hasılat satırlarını güncelle
    for (int i = 0; i < _hasiat600Satirlari.length; i++) {
      final h = _hasiat600Satirlari[i];
      final key = BirimAdlandirma.canonicalKey(h.birimAdi);
      final gecmisHasilat = ozet.birimHasilatToplami[key] ?? 0.0;
      final yeniKumulatif = BeyannameHesaplamaMotoru.round(gecmisHasilat + h.aylikHasilat600);

      _hasiat600Satirlari[i] = h.copyWith(
        oncekiAylarHasilat600: gecmisHasilat,
        kumulatifHasilat600: yeniKumulatif,
      );
    }

    // 2. Bir önceki aydan devreden KDV varsa ve cari KDV 1 devri sıfırsa otomatik doldur
    if (_oncekiAydanDevredenKdv == 0 && (ozet.sonAydanDevredenKdv ?? 0) > 0) {
      _oncekiAydanDevredenKdv = ozet.sonAydanDevredenKdv!;
    }

    _tetikleYerelTaslakKaydi();
    notifyListeners();
    return ozet;
  }

  List<BirimGecmisVergiKaydi> birimGecmisiFiltrele(
    List<BeyannameDonemModel> donemler, {
    String? seciliBirimAdi,
    int? seciliYil,
  }) {
    final sonuclar = <BirimGecmisVergiKaydi>[];
    final targetKey = seciliBirimAdi != null && seciliBirimAdi.isNotEmpty
        ? BirimAdlandirma.canonicalKey(seciliBirimAdi)
        : null;

    for (final donem in donemler) {
      if (seciliYil != null && donem.yil != seciliYil) continue;

      // O dönemin birimlerini bul
      final birimKeys = <String>{};
      for (final k in donem.kdv1Satirlari) {
        final key = BirimAdlandirma.canonicalKey(k.birimAdi);
        if (key.isNotEmpty) birimKeys.add(key);
      }
      for (final d in donem.damgaSatirlari) {
        final key = BirimAdlandirma.canonicalKey(d.birimAdi);
        if (key.isNotEmpty) birimKeys.add(key);
      }

      for (final bKey in birimKeys) {
        if (targetKey != null && targetKey != bKey) continue;

        final kdv1Satiri = donem.kdv1Satirlari
            .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == bKey);
        final kdv1Tutar = kdv1Satiri.fold(0.0, (s, x) => s + x.netOdenecekKdv);

        final tevkifat = donem.tevkifatKayitlari
            .where((x) => x.birimAdi != null && BirimAdlandirma.canonicalKey(x.birimAdi!) == bKey)
            .fold(0.0, (s, x) => s + x.tevkifatTutari);

        final muhtasarGelir = donem.muhtasarSatirlari
            .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == bKey)
            .fold(0.0, (s, x) => s + x.gelirVergisi);

        final muhtasarDamga = donem.muhtasarSatirlari
            .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == bKey)
            .fold(0.0, (s, x) => s + x.damgaVergisi);

        final damga360 = donem.damgaSatirlari
            .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == bKey)
            .fold(0.0, (s, x) => s + x.damgaVergisi);

        final hasiatSatiri = donem.hasiat600Satirlari
            .where((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == bKey);
        final aylikHasilat = hasiatSatiri.fold(0.0, (s, x) => s + x.aylikHasilat600);
        final krediKarti = hasiatSatiri.fold(0.0, (s, x) => s + x.krediKarti123);

        sonuclar.add(
          BirimGecmisVergiKaydi(
            yil: donem.yil,
            ay: donem.ay,
            donemBaslik: donem.baslik,
            birimAdi: BirimAdlandirma.tamAdGetir(bKey),
            kdv1NetOdenecek: BeyannameHesaplamaMotoru.round(kdv1Tutar),
            kdv2Tevkifat: BeyannameHesaplamaMotoru.round(tevkifat),
            muhtasarGelirVergisi: BeyannameHesaplamaMotoru.round(muhtasarGelir),
            muhtasarDamgaVergisi: BeyannameHesaplamaMotoru.round(muhtasarDamga),
            damgaVergisi360: BeyannameHesaplamaMotoru.round(damga360),
            hasilat600Aylik: BeyannameHesaplamaMotoru.round(aylikHasilat),
            krediKarti123: BeyannameHesaplamaMotoru.round(krediKarti),
          ),
        );
      }
    }
    return sonuclar;
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
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  // =========================================================================
  // AKILLI MİZAN & BELGE AJANI (AI DESTEKLİ BEYANNAME HAZIRLAMA)
  // =========================================================================
  BeyannameAiAjanServisi? _aiAjanServisiInstance;
  BeyannameAiAjanServisi get _aiAjanServisi =>
      _aiAjanServisiInstance ??= BeyannameAiAjanServisi();

  /// Denetim kartındaki "Canlı Mütalaa Al" butonu için AI yorumu.
  Future<String> denetimMutalaasiAl(MutabakatKontrolKaydi k) {
    return _aiAjanServisi.denetimMutalaasiAl(
      birimAdi: k.birimAdi,
      baslik: k.baslik,
      aciklama: k.aciklama,
      beklenen: k.beklenenDeger,
      bulunan: k.bulunanDeger,
      fark: k.fark,
    );
  }

  /// Birim bazında yüklenen belgeler (birimAdi -> {slotTuru -> Belge})
  final Map<String, Map<BirimBelgeSlotTuru, BirimYuklenenBelge>> _yuklenenBelgeler = {};
  Map<String, Map<BirimBelgeSlotTuru, BirimYuklenenBelge>> get yuklenenBelgeler => _yuklenenBelgeler;

  /// Birim bazında yüklenen tüm belgelerin listesi (kartlarda aşağıya doğru listeleme için)
  final Map<String, List<BirimYuklenenBelge>> _birimBelgeListeleri = {};
  Map<String, List<BirimYuklenenBelge>> get birimBelgeListeleri => _birimBelgeListeleri;

  List<BirimYuklenenBelge> getBirimBelgeleri(String birimAdi) {
    return _birimBelgeListeleri[birimAdi] ?? [];
  }

  bool _isAiAjanCalisiyor = false;
  bool get isAiAjanCalisiyor => _isAiAjanCalisiyor;

  bool _isTopluYuklemeDurduruldu = false;

  double _aiAjanIlerleme = 0.0;
  double get aiAjanIlerleme => _aiAjanIlerleme;

  final List<AjanLogMesaji> _aiAjanLoglari = [];
  List<AjanLogMesaji> get aiAjanLoglari => List.unmodifiable(_aiAjanLoglari);

  void aiAjanLoglariniTemizle() {
    _aiAjanLoglari.clear();
    notifyListeners();
  }

  BeyannameAjanRaporu? _sonAjanRaporu;
  BeyannameAjanRaporu? get sonAjanRaporu => _sonAjanRaporu;

  /// Her birimin bağımsız, kalıcı ve üzerine yazılmayan son analiz çıktısı.
  final Map<String, BirimMizanAnalizSonucu> _birimAnalizSonuclari = {};
  Map<String, BirimMizanAnalizSonucu> get birimAnalizSonuclari =>
      Map.unmodifiable(_birimAnalizSonuclari);

  /// Birim bazlı çapraz denetim ve hata kayıtları (Birime özel rapor için)
  final Map<String, List<MutabakatKontrolKaydi>> _birimDenetimKayitlari = {};

  /// Birim bazlı "Nereden Nereye" şeffaf denetim izi kayıtları
  final Map<String, List<NeredenNereyeKaydi>> _birimNeredenNereye = {};

  /// Belirli bir birimin analiz sonucunu getirir (Canonical key toleranslı)
  BirimMizanAnalizSonucu? getBirimAnalizSonucu(String birimAdi) {
    if (_birimAnalizSonuclari.containsKey(birimAdi)) {
      return _birimAnalizSonuclari[birimAdi];
    }
    final cKey = BirimAdlandirma.canonicalKey(birimAdi);
    for (final e in _birimAnalizSonuclari.entries) {
      if (BirimAdlandirma.canonicalKey(e.key) == cKey) return e.value;
    }
    return null;
  }

  /// Birime ait denetim kayıtları
  List<MutabakatKontrolKaydi> getBirimDenetimKayitlari(String birimAdi) {
    if (_birimDenetimKayitlari.containsKey(birimAdi)) {
      return _birimDenetimKayitlari[birimAdi]!;
    }
    final cKey = BirimAdlandirma.canonicalKey(birimAdi);
    for (final e in _birimDenetimKayitlari.entries) {
      if (BirimAdlandirma.canonicalKey(e.key) == cKey) return e.value;
    }
    return const [];
  }

  /// Birime ait nereden nereye kayıtları
  List<NeredenNereyeKaydi> getBirimNeredenNereye(String birimAdi) {
    if (_birimNeredenNereye.containsKey(birimAdi)) {
      return _birimNeredenNereye[birimAdi]!;
    }
    final cKey = BirimAdlandirma.canonicalKey(birimAdi);
    for (final e in _birimNeredenNereye.entries) {
      if (BirimAdlandirma.canonicalKey(e.key) == cKey) return e.value;
    }
    return const [];
  }

  /// Yalnızca bu birime ait bağımsız, izole edilmiş denetim raporunu üretir
  BeyannameAjanRaporu? getBirimRaporu(String birimAdi) {
    final sonuc = getBirimAnalizSonucu(birimAdi);
    if (sonuc == null) return null;
    final denetimler = getBirimDenetimKayitlari(birimAdi);
    final neredenNereye = getBirimNeredenNereye(birimAdi);
    final belgeler = getBirimBelgeleri(birimAdi);

    return BeyannameAjanRaporu(
      id: 'rapor_${BirimAdlandirma.canonicalKey(birimAdi)}_${_seciliYil}_$_seciliAy',
      yil: _seciliYil,
      ay: _seciliAy,
      olusturulmaTarihi: sonuc.analizTarihi,
      analizEdilenBirimler: [birimAdi],
      toplamDosyaSayisi: belgeler.length,
      birimSonuclari: {birimAdi: sonuc},
      neredenNereyeListesi: neredenNereye,
      denetimKontrolleri: denetimler,
    );
  }

  /// Yalnızca tek bir birimin analiz sonuçlarını beyanname masalarına (KDV1, Damga, 600, Tevkifat)
  /// diğer birimleri etkilemeden, çift sayma yapmadan (idempotent) aktarır.
  void birimVerileriniMasayaAktar(String birimAdi) {
    final sonuc = getBirimAnalizSonucu(birimAdi);
    if (sonuc == null) return;

    final tekBirimRaporu = BeyannameAjanRaporu(
      id: 'aktar_${BirimAdlandirma.canonicalKey(birimAdi)}_${DateTime.now().millisecondsSinceEpoch}',
      yil: _seciliYil,
      ay: _seciliAy,
      olusturulmaTarihi: DateTime.now(),
      analizEdilenBirimler: [birimAdi],
      toplamDosyaSayisi: getBirimBelgeleri(birimAdi).length,
      birimSonuclari: {birimAdi: sonuc},
      neredenNereyeListesi: getBirimNeredenNereye(birimAdi),
      denetimKontrolleri: getBirimDenetimKayitlari(birimAdi),
    );

    aiAjanVerileriniUygula(tekBirimRaporu, uzerineEkle: false);
  }

  /// Tekil bir faturayı AI ile analiz eder
  Future<Map<String, dynamic>?> tekilFaturaAiCozumle(BirimYuklenenBelge belge) {
    return _aiAjanServisi.tekilFaturaAiCozumle(belge);
  }

  /// Tekil çözümlenen veya düzenlenen faturayı birimin analiz sonucuna ve KDV 2 masasına kaydeder.
  void tekilFaturaKaydet({
    required String birimAdi,
    required Map<String, dynamic> faturaMap,
    bool masayaAktar = true,
  }) {
    final fAdi = (faturaMap['firmaAdi'] as String? ?? 'Firma').trim();
    final vNo = (faturaMap['vergiTcNo'] as String? ?? '').trim();
    final mtr = TurkceFormat.parseSayi(faturaMap['matrahTutari']);
    final kdv = TurkceFormat.parseSayi(faturaMap['kdvTutari']);
    final tvk = TurkceFormat.parseSayi(faturaMap['tevkifatTutari']);
    final oran = (faturaMap['tevkifatOrani'] as String? ?? '9/10').trim();
    final kdvOrani = (faturaMap['kdvOrani'] as num?)?.toInt() ?? 20;

    // 1. Birimin analiz sonucundaki tevkifat listesini güncelle
    final mevcutSonuc = getBirimAnalizSonucu(birimAdi);
    if (mevcutSonuc != null) {
      final yeniTevkifatlar = List<Map<String, dynamic>>.from(mevcutSonuc.tevkifatFaturalari);
      final idx = yeniTevkifatlar.indexWhere((t) =>
          (TurkceFormat.parseSayi(t['matrahTutari']) - mtr).abs() < 1.0 &&
          (t['vergiTcNo'] == vNo || t['firmaAdi']?.toString().toLowerCase() == fAdi.toLowerCase()));
      if (idx >= 0) {
        yeniTevkifatlar[idx] = Map<String, dynamic>.from(faturaMap);
      } else {
        yeniTevkifatlar.add(Map<String, dynamic>.from(faturaMap));
      }
      _birimAnalizSonuclari[birimAdi] = BirimMizanAnalizSonucu(
        birimAdi: birimAdi,
        analizTarihi: DateTime.now(),
        hasilat600Aylik: mevcutSonuc.hasilat600Aylik,
        hasilat600Kumulatif: mevcutSonuc.hasilat600Kumulatif,
        krediKarti123: mevcutSonuc.krediKarti123,
        hesaplananKdvMatrah10: mevcutSonuc.hesaplananKdvMatrah10,
        hesaplananKdv10: mevcutSonuc.hesaplananKdv10,
        hesaplananKdvMatrah20: mevcutSonuc.hesaplananKdvMatrah20,
        hesaplananKdv20: mevcutSonuc.hesaplananKdv20,
        indirilecekKdvMatrah10: mevcutSonuc.indirilecekKdvMatrah10,
        indirilecekKdv10: mevcutSonuc.indirilecekKdv10,
        indirilecekKdvMatrah20: mevcutSonuc.indirilecekKdvMatrah20,
        indirilecekKdv20: mevcutSonuc.indirilecekKdv20,
        damgaVergisi360: mevcutSonuc.damgaVergisi360,
        damgaMatrah: mevcutSonuc.damgaMatrah,
        muhtasarGelir360: mevcutSonuc.muhtasarGelir360,
        muhtasarDamga360: mevcutSonuc.muhtasarDamga360,
        devredenKdv190: mevcutSonuc.devredenKdv190,
        tevkifatFaturalari: yeniTevkifatlar,
        yardimciMizanKullanildi: mevcutSonuc.yardimciMizanKullanildi,
        yardimciMizan391Toplam: mevcutSonuc.yardimciMizan391Toplam,
        yardimciMizan191Toplam: mevcutSonuc.yardimciMizan191Toplam,
        yardimciMizan600Toplam: mevcutSonuc.yardimciMizan600Toplam,
        aciklama: mevcutSonuc.aciklama,
      );
    }

    // 2. KDV 2 Masasına Ekle/Güncelle (Mükerrerlik engellenir)
    if (masayaAktar && mtr > 0) {
      final existingIndex = _tevkifatKayitlari.indexWhere((x) =>
          BirimAdlandirma.canonicalKey(x.birimAdi ?? '') == BirimAdlandirma.canonicalKey(birimAdi) &&
          ((x.matrahTutari - mtr).abs() < 1.0 || (vNo.isNotEmpty && x.vergiTcNo == vNo)));

      final kayit = TevkifatFirmaKaydi(
        id: existingIndex >= 0
            ? _tevkifatKayitlari[existingIndex].id
            : 'tvk_ai_${BirimAdlandirma.canonicalKey(birimAdi)}_${DateTime.now().microsecondsSinceEpoch}',
        firmaAdi: fAdi,
        vergiTcNo: vNo,
        tevkifatTuru: TevkifatTuru.fromString(oran),
        tevkifatEtiketi: oran,
        kdvOrani: kdvOrani,
        matrahTutari: mtr,
        kdvTutari: kdv,
        tevkifatTutari: tvk,
        birimAdi: birimAdi,
      );

      if (existingIndex >= 0) {
        _tevkifatKayitlari[existingIndex] = kayit;
      } else {
        _tevkifatKayitlari.add(kayit);
      }
    }

    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  bool _isAiUzmanAnaliziYukleniyor = false;
  bool get isAiUzmanAnaliziYukleniyor => _isAiUzmanAnaliziYukleniyor;

  String? _sonAiUzmanAnalizi;
  String? get sonAiUzmanAnalizi => _sonAiUzmanAnalizi;

  /// Canlı logları ve denetim raporunu AI Baş Denetçiye inceletir
  Future<String> aiUzmanGunlukAnaliziCalistir() async {
    _isAiUzmanAnaliziYukleniyor = true;
    notifyListeners();
    try {
      final sonuc = await _aiAjanServisi.gunlukVeDenetimAiUzmanAnalizi(
        yil: _seciliYil,
        ay: _seciliAy,
        loglar: _aiAjanLoglari,
        rapor: _sonAjanRaporu,
      );
      _sonAiUzmanAnalizi = sonuc;
      return sonuc;
    } finally {
      _isAiUzmanAnaliziYukleniyor = false;
      notifyListeners();
    }
  }

  StreamSubscription<AjanLogMesaji>? _aiAjanSubscription;

  int get toplamYuklenenBelgeSayisi {
    int sayi = 0;
    for (final l in _birimBelgeListeleri.values) {
      sayi += l.length;
    }
    if (sayi == 0) {
      for (final m in _yuklenenBelgeler.values) {
        sayi += m.length;
      }
    }
    return sayi;
  }

  BirimYuklenenBelge? getBelge(String birimAdi, BirimBelgeSlotTuru slotTuru) {
    // Önce liste yapısından ilgili slotu ara
    final listeden = _birimBelgeListeleri[birimAdi]?.where((b) => b.slotTuru == slotTuru).firstOrNull;
    if (listeden != null) return listeden;
    return _yuklenenBelgeler[birimAdi]?[slotTuru];
  }

  void belgeYukle({
    required String birimAdi,
    required BirimBelgeSlotTuru slotTuru,
    required String dosyaAdi,
    required int dosyaBoyutu,
    required String dosyaUzantisi,
    Uint8List? dosyaBytes,
  }) {
    final docId = 'belge_${DateTime.now().microsecondsSinceEpoch}';
    final belge = BirimYuklenenBelge(
      id: docId,
      birimAdi: birimAdi,
      slotTuru: slotTuru,
      dosyaAdi: dosyaAdi,
      dosyaBoyutu: dosyaBoyutu,
      dosyaUzantisi: dosyaUzantisi,
      yuklenmeTarihi: DateTime.now(),
      dosyaBytes: dosyaBytes,
    );

    // 1. Liste yapısını güncelle (aşağıya doğru listeleme)
    if (!_birimBelgeListeleri.containsKey(birimAdi)) {
      _birimBelgeListeleri[birimAdi] = [];
    }
    // Sadece AYNI DOSYA ADI varsa güncelle, farklı isimli belgeleri yeni satır olarak ekle
    final mevcutIndex = _birimBelgeListeleri[birimAdi]!.indexWhere(
      (b) => b.dosyaAdi == dosyaAdi,
    );
    if (mevcutIndex >= 0) {
      _birimBelgeListeleri[birimAdi]![mevcutIndex] = belge;
    } else {
      _birimBelgeListeleri[birimAdi]!.add(belge);
    }

    // 2. Geriye dönük uyumluluk map'ini güncelle
    if (!_yuklenenBelgeler.containsKey(birimAdi)) {
      _yuklenenBelgeler[birimAdi] = {};
    }
    _yuklenenBelgeler[birimAdi]![slotTuru] = belge;

    notifyListeners();
  }

  /// Tekil bir belgeyi id bazında listeden ve yuvasından siler
  void tekilBelgeSil({
    required String birimAdi,
    required String belgeId,
  }) {
    final liste = _birimBelgeListeleri[birimAdi];
    if (liste != null) {
      final silinecekIndex = liste.indexWhere((b) => b.id == belgeId);
      if (silinecekIndex >= 0) {
        final silinen = liste.removeAt(silinecekIndex);
        if (_yuklenenBelgeler[birimAdi]?[silinen.slotTuru]?.id == belgeId) {
          _yuklenenBelgeler[birimAdi]?.remove(silinen.slotTuru);
          final ayniSlotYedek = liste.where((b) => b.slotTuru == silinen.slotTuru).firstOrNull;
          if (ayniSlotYedek != null) {
            _yuklenenBelgeler[birimAdi]![silinen.slotTuru] = ayniSlotYedek;
          }
        }
        notifyListeners();
      }
    }
  }

  /// Kullanıcının yüklenen bir belgenin slot türünü (örn: Aylık Mizan -> Yıllık Mizan) değiştirmesini sağlar
  void belgeSlotDegistir({
    required String birimAdi,
    required String belgeId,
    required BirimBelgeSlotTuru yeniSlot,
  }) {
    final liste = _birimBelgeListeleri[birimAdi];
    if (liste != null) {
      final index = liste.indexWhere((b) => b.id == belgeId);
      if (index >= 0) {
        final eski = liste[index];
        final guncel = BirimYuklenenBelge(
          id: eski.id,
          birimAdi: eski.birimAdi,
          slotTuru: yeniSlot,
          dosyaAdi: eski.dosyaAdi,
          dosyaBoyutu: eski.dosyaBoyutu,
          dosyaUzantisi: eski.dosyaUzantisi,
          yuklenmeTarihi: eski.yuklenmeTarihi,
          dosyaBytes: eski.dosyaBytes,
        );
        liste[index] = guncel;
        if (!_yuklenenBelgeler.containsKey(birimAdi)) {
          _yuklenenBelgeler[birimAdi] = {};
        }
        _yuklenenBelgeler[birimAdi]![yeniSlot] = guncel;
        notifyListeners();
      }
    }
  }

  void belgeSil({
    required String birimAdi,
    required BirimBelgeSlotTuru slotTuru,
  }) {
    _yuklenenBelgeler[birimAdi]?.remove(slotTuru);
    _birimBelgeListeleri[birimAdi]?.removeWhere((b) => b.slotTuru == slotTuru);
    notifyListeners();
  }

  void birimBelgeleriniTemizle(String birimAdi) {
    birimiTamamenSifirla(birimAdi, masalariDaTemizle: false);
  }

  /// Yalnızca ilgili birimin beyanname masalarındaki (KDV 1, Damga, 600, Tevkifat)
  /// kayıtlarını sıfırlar / geri çeker; yüklenen evrakları ve analiz sonuçlarını korur.
  void birimMasalariniGeriCek(String birimAdi) {
    final cKey = BirimAdlandirma.canonicalKey(birimAdi);

    // 1. KDV 1 Masası -> Sıfırla
    final kdvIdx = _kdv1Satirlari.indexWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == cKey);
    if (kdvIdx >= 0) {
      final s = _kdv1Satirlari[kdvIdx];
      _kdv1Satirlari[kdvIdx] = Kdv1BirimSatiri(
        birimId: s.birimId,
        birimAdi: s.birimAdi,
      );
    }

    // 2. Damga Vergisi Masası -> Sıfırla
    final damgaIdx = _damgaSatirlari.indexWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == cKey);
    if (damgaIdx >= 0) {
      final s = _damgaSatirlari[damgaIdx];
      _damgaSatirlari[damgaIdx] = DamgaVergisiBirimSatiri(
        birimAdi: s.birimAdi,
        damgaVergisi: 0.0,
        matrah: 0.0,
      );
    }

    // 3. 600 Hasılat & 123 POS Masası -> Sıfırla
    final hasIdx = _hasiat600Satirlari.indexWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == cKey);
    if (hasIdx >= 0) {
      final s = _hasiat600Satirlari[hasIdx];
      _hasiat600Satirlari[hasIdx] = Hasiat600BirimSatiri(
        birimAdi: s.birimAdi,
      );
    }

    // 4. KDV 2 Tevkifat Faturaları -> İlgili birimin faturalarını temizle
    _tevkifatKayitlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi ?? '') == cKey);

    // 5. Muhtasar Masası -> İlgili birimin satırlarını temizle
    _muhtasarSatirlari.removeWhere((x) => BirimAdlandirma.canonicalKey(x.birimAdi) == cKey);

    _guncelleDamga301();
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  /// Belirli bir birimin yüklenen belgelerini, analiz sonuçlarını ve
  /// istenirse beyanname masalarındaki (KDV 1, Damga, 600, Tevkifat) satırlarını tamamen sıfırlar / geri çeker.
  void birimiTamamenSifirla(String birimAdi, {bool masalariDaTemizle = true}) {
    final cKey = BirimAdlandirma.canonicalKey(birimAdi);

    // 1. Belgeleri ve analiz çıktılarını temizle
    _yuklenenBelgeler.remove(birimAdi);
    _birimBelgeListeleri.remove(birimAdi);
    _birimAnalizSonuclari.remove(birimAdi);
    _birimDenetimKayitlari.remove(birimAdi);
    _birimNeredenNereye.remove(birimAdi);

    // Canonical key ile de temizle
    _yuklenenBelgeler.removeWhere((k, _) => BirimAdlandirma.canonicalKey(k) == cKey);
    _birimBelgeListeleri.removeWhere((k, _) => BirimAdlandirma.canonicalKey(k) == cKey);
    _birimAnalizSonuclari.removeWhere((k, _) => BirimAdlandirma.canonicalKey(k) == cKey);
    _birimDenetimKayitlari.removeWhere((k, _) => BirimAdlandirma.canonicalKey(k) == cKey);
    _birimNeredenNereye.removeWhere((k, _) => BirimAdlandirma.canonicalKey(k) == cKey);

    // 2. Konsolide rapordan bu birimi çıkar
    if (_sonAjanRaporu != null) {
      final guncelSonuclar = Map<String, BirimMizanAnalizSonucu>.from(_birimAnalizSonuclari);
      final guncelBirimler = guncelSonuclar.keys.toList();

      _sonAjanRaporu = _sonAjanRaporu!.copyWith(
        analizEdilenBirimler: guncelBirimler,
        birimSonuclari: guncelSonuclar,
      );
    }

    // 3. Masalardaki verileri sıfırla / temizle
    if (masalariDaTemizle) {
      birimMasalariniGeriCek(birimAdi);
    } else {
      _tetikleYerelTaslakKaydi();
      notifyListeners();
    }
  }

  /// Bir belgenin birimini değiştirir (Örn: Yanlışlıkla TÖMER'e yüklenen evrakı DİŞ HEKİMLİĞİ'ne taşır)
  void belgeBiriminiDegistir({
    required String eskiBirimAdi,
    required String yeniBirimAdi,
    required String belgeId,
  }) {
    final eskiListe = _birimBelgeListeleri[eskiBirimAdi];
    if (eskiListe == null) return;

    final idx = eskiListe.indexWhere((b) => b.id == belgeId);
    if (idx < 0) return;

    final eskiBelge = eskiListe.removeAt(idx);
    _yuklenenBelgeler[eskiBirimAdi]?.remove(eskiBelge.slotTuru);

    final yeniBelge = BirimYuklenenBelge(
      id: eskiBelge.id,
      birimAdi: yeniBirimAdi,
      slotTuru: eskiBelge.slotTuru,
      dosyaAdi: eskiBelge.dosyaAdi,
      dosyaBoyutu: eskiBelge.dosyaBoyutu,
      dosyaUzantisi: eskiBelge.dosyaUzantisi,
      yuklenmeTarihi: DateTime.now(),
      dosyaBytes: eskiBelge.dosyaBytes,
    );

    _birimBelgeListeleri.putIfAbsent(yeniBirimAdi, () => []).add(yeniBelge);
    _yuklenenBelgeler.putIfAbsent(yeniBirimAdi, () => {})[eskiBelge.slotTuru] = yeniBelge;

    notifyListeners();
  }

  void tumBelgeleriTemizle() {
    _yuklenenBelgeler.clear();
    _birimBelgeListeleri.clear();
    _birimAnalizSonuclari.clear();
    _birimDenetimKayitlari.clear();
    _birimNeredenNereye.clear();
    _sonAjanRaporu = null;
    _aiAjanLoglari.clear();
    _aiAjanIlerleme = 0.0;
    notifyListeners();
  }

  /// Çoklu seçilen dosyaları (PDF/Excel) sırayla akıllıca tarar, birim ve yuvasını tespit eder
  /// ve canlı olarak siyah terminal ekranına adım adım akış logları yazdırır.
  Future<List<String>> topluBelgeOtomatikEslestirVeYukle({
    required List<({String dosyaAdi, int dosyaBoyutu, String dosyaUzantisi, Uint8List? dosyaBytes})> dosyalar,
    required List<String> aktifBirimler,
    String? varsayilanBirimAdi,
    void Function(int current, int total, String dosyaAdi)? onProgress,
  }) async {
    final eslesenOzetler = <String>[];
    if (dosyalar.isEmpty) return eslesenOzetler;

    _isAiAjanCalisiyor = true;
    _isTopluYuklemeDurduruldu = false;
    _aiAjanIlerleme = 0.0;
    _aiAjanLoglari.clear();

    _aiAjanLoglari.add(
      AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⚡ AKILLI TOPLU EVRAK TARAMA & AYRIŞTIRMA BAŞLATILDI (${dosyalar.length} Evrak Sıraya Alındı)',
        seviye: AjanLogSeviyesi.bilgi,
      ),
    );
    notifyListeners();

    for (int i = 0; i < dosyalar.length; i++) {
      if (_isTopluYuklemeDurduruldu) {
        _aiAjanLoglari.add(
          AjanLogMesaji(
            zaman: DateTime.now(),
            mesaj: '⏹️ Toplu evrak yükleme kullanıcı tarafından durduruldu ($i/${dosyalar.length} evrak işlendi).',
            isHata: true,
          ),
        );
        break;
      }

      final d = dosyalar[i];
      onProgress?.call(i + 1, dosyalar.length, d.dosyaAdi);

      _aiAjanIlerleme = (i + 0.3) / dosyalar.length;
      _aiAjanLoglari.add(
        AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📄 [${i + 1}/${dosyalar.length}] "${d.dosyaAdi}" taranıyor ve analiz ediliyor...',
          seviye: AjanLogSeviyesi.bilgi,
        ),
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 30));

      final geciciBelge = BirimYuklenenBelge(
        id: 'tmp_${DateTime.now().microsecondsSinceEpoch}',
        birimAdi: varsayilanBirimAdi ?? (aktifBirimler.isNotEmpty ? aktifBirimler.first : 'Birim'),
        slotTuru: BirimBelgeSlotTuru.aylikMizan,
        dosyaAdi: d.dosyaAdi,
        dosyaBoyutu: d.dosyaBoyutu,
        dosyaUzantisi: d.dosyaUzantisi,
        yuklenmeTarihi: DateTime.now(),
        dosyaBytes: d.dosyaBytes,
      );

      // Sınıflandırma ve birim tespiti için sadece ilk 2 sayfa taranır (Hızlı, hafif & donmasız)
      final metin = await _aiAjanServisi.belgeMetniniCikar(geciciBelge, maxPagesOverride: 2);
      final sinif = MizanDeterministikParser.otomatikBelgeSiniflandir(
        dosyaAdi: d.dosyaAdi,
        metin: metin,
        aktifBirimler: aktifBirimler,
      );

      final hedefBirim = (varsayilanBirimAdi != null && varsayilanBirimAdi.isNotEmpty)
          ? varsayilanBirimAdi
          : (sinif.birimAdi ?? (aktifBirimler.isNotEmpty ? aktifBirimler.first : 'Genel'));
      var hedefSlot = sinif.slotTuru;

      // Eğer birimin o slotu doluysa ve başka bir slot boşsa akıllı dağıt
      final mevcutListeler = _birimBelgeListeleri[hedefBirim] ?? [];
      final hasAylik = mevcutListeler.any((b) => b.slotTuru == BirimBelgeSlotTuru.aylikMizan);
      final hasYillik = mevcutListeler.any((b) => b.slotTuru == BirimBelgeSlotTuru.yillikMizan);
      final hasYardimci = mevcutListeler.any((b) => b.slotTuru == BirimBelgeSlotTuru.yardimciMizan);

      if (hedefSlot == BirimBelgeSlotTuru.aylikMizan && hasAylik && !hasYillik) {
        hedefSlot = BirimBelgeSlotTuru.yillikMizan;
      } else if (hedefSlot == BirimBelgeSlotTuru.aylikMizan && hasAylik && hasYillik) {
        hedefSlot = BirimBelgeSlotTuru.diger;
      } else if (hedefSlot == BirimBelgeSlotTuru.yillikMizan && hasYillik && !hasAylik) {
        hedefSlot = BirimBelgeSlotTuru.aylikMizan;
      } else if (hedefSlot == BirimBelgeSlotTuru.yillikMizan && hasYillik && hasAylik) {
        hedefSlot = BirimBelgeSlotTuru.diger;
      } else if (hedefSlot == BirimBelgeSlotTuru.yardimciMizan && hasYardimci && !hasAylik && d.dosyaAdi.toLowerCase().contains('aylik')) {
        // "Tarımsal Yardımcı Defter Aylık.pdf" gibi bir dosya varsa ve aylık mizan henüz yoksa aylık mizan yuvasına ata
        hedefSlot = BirimBelgeSlotTuru.aylikMizan;
      } else if (hedefSlot == BirimBelgeSlotTuru.yardimciMizan && hasYardimci) {
        // İkinci bir yardımcı defter gelirse üzerine yazmasın, Diğer/Ekstra olarak da listelensin
        hedefSlot = BirimBelgeSlotTuru.diger;
      }

      belgeYukle(
        birimAdi: hedefBirim,
        slotTuru: hedefSlot,
        dosyaAdi: d.dosyaAdi,
        dosyaBoyutu: d.dosyaBoyutu,
        dosyaUzantisi: d.dosyaUzantisi,
        dosyaBytes: d.dosyaBytes,
      );

      final kisaBirim = BirimAdlandirma.kisaAdGetir(hedefBirim);
      _aiAjanIlerleme = (i + 1) / dosyalar.length;
      _aiAjanLoglari.add(
        AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '🏛️ Birim: $kisaBirim  |  📂 Yuva: ${hedefSlot.baslik}  →  [${d.dosyaAdi}] başarıyla yerleştirildi.',
          isBasarili: true,
          birimAdi: kisaBirim,
        ),
      );
      eslesenOzetler.add('$kisaBirim → ${hedefSlot.baslik} (${d.dosyaAdi})');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 30));
    }

    _isAiAjanCalisiyor = false;
    _aiAjanIlerleme = 1.0;
    _aiAjanLoglari.add(
      AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '🎉 TOPLU TARAMA VE AYRIŞTIRMA TAMAMLANDI! Toplam ${eslesenOzetler.length} evrak ilgili birim listelerine aşağıya doğru yerleştirildi.',
        isBasarili: true,
      ),
    );
    notifyListeners();

    return eslesenOzetler;
  }

  /// Rapor içerisindeki bir tevkifat faturasını (örn. VKN veya tutar düzeltmesi) günceller
  /// ve denetim raporunu anında yeniden hesaplar.
  void raporTevkifatFaturasiGuncelle({
    required String birimAdi,
    required int faturaIndex,
    required Map<String, dynamic> yeniFatura,
  }) {
    final mevcutRapor = _sonAjanRaporu;
    if (mevcutRapor == null) return;
    final birimSonuc = mevcutRapor.birimSonuclari[birimAdi];
    if (birimSonuc == null) return;
    if (faturaIndex < 0 || faturaIndex >= birimSonuc.tevkifatFaturalari.length) return;

    final yeniListe = List<Map<String, dynamic>>.from(birimSonuc.tevkifatFaturalari);
    yeniListe[faturaIndex] = Map<String, dynamic>.from(yeniFatura);

    final guncelMap = birimSonuc.toMap();
    guncelMap['tevkifatFaturalari'] = yeniListe;
    if (birimSonuc.hamJson != null) {
      guncelMap['is191TersBakiye'] = birimSonuc.hamJson!['is191TersBakiye'];
      guncelMap['is391TersBakiye'] = birimSonuc.hamJson!['is391TersBakiye'];
      guncelMap['is600TersBakiye'] = birimSonuc.hamJson!['is600TersBakiye'];
    }
    final guncelBirimSonuc = BirimMizanAnalizSonucu.fromMap(guncelMap);

    final yeniBirimSonuclari = Map<String, BirimMizanAnalizSonucu>.from(mevcutRapor.birimSonuclari);
    yeniBirimSonuclari[birimAdi] = guncelBirimSonuc;

    final birimOncekiAylar = <String, double>{};
    for (final h in _hasiat600Satirlari) {
      birimOncekiAylar[h.birimAdi] = h.oncekiAylarHasilat600;
      final cKey = BirimAdlandirma.canonicalKey(h.birimAdi);
      if (cKey.isNotEmpty) {
        birimOncekiAylar[cKey] = h.oncekiAylarHasilat600;
      }
    }

    final yeniRapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
      yil: mevcutRapor.yil,
      ay: mevcutRapor.ay,
      birimSonuclari: yeniBirimSonuclari,
      toplamDosyaSayisi: mevcutRapor.toplamDosyaSayisi,
      birimOncekiAylarHasilat: birimOncekiAylar,
      oncekiAydanDevredenKdv: _oncekiAydanDevredenKdv,
    );

    _sonAjanRaporu = yeniRapor.copyWith(
      uygulandiMi: mevcutRapor.uygulandiMi,
      uygulanmaTarihi: mevcutRapor.uygulanmaTarihi,
    );

    if (mevcutRapor.uygulandiMi) {
      aiAjanVerileriniUygula(_sonAjanRaporu!);
    } else {
      notifyListeners();
    }
  }

  /// Sıralı AI Ajan analizini başlatır (ister tüm birimler, ister sadece tek bir birim)
  void aiAjanAnaliziBaslat({
    String? sadeceBuBirim,
    bool hizliDeterministikMod = false,
    bool otomatikMasalaraAktar = false,
  }) {
    if (_isAiAjanCalisiyor) return;

    _isAiAjanCalisiyor = true;
    _aiAjanIlerleme = 0.0;
    _aiAjanLoglari.clear();
    _sonAjanRaporu = null;
    notifyListeners();

    // Önceki aylar hasılat haritası
    final birimOncekiAylar = <String, double>{};
    for (final h in _hasiat600Satirlari) {
      birimOncekiAylar[h.birimAdi] = h.oncekiAylarHasilat600;
      final cKey = BirimAdlandirma.canonicalKey(h.birimAdi);
      if (cKey.isNotEmpty) {
        birimOncekiAylar[cKey] = h.oncekiAylarHasilat600;
      }
    }

    _aiAjanSubscription?.cancel();
    final stream = _aiAjanServisi.siraliAnalizBaslat(
      yil: _seciliYil,
      ay: _seciliAy,
      yuklenenBelgeler: _yuklenenBelgeler,
      birimBelgeListeleri: _birimBelgeListeleri,
      birimOncekiAylarHasilat: birimOncekiAylar,
      oncekiAydanDevredenKdv: _oncekiAydanDevredenKdv,
      sadeceBuBirim: sadeceBuBirim,
      hizliDeterministikMod: hizliDeterministikMod,
      onTamamlandi: (rapor) {
        _isAiAjanCalisiyor = false;
        _aiAjanIlerleme = 1.0;

        // 1. Birim sonuçlarını kalıcı haritaya ekle / güncelle
        for (final entry in rapor.birimSonuclari.entries) {
          _birimAnalizSonuclari[entry.key] = entry.value;
        }

        // 2. Birim denetim kontrollerini ve nereden-nereye kayıtlarını ayrıştırıp sakla
        for (final b in rapor.birimSonuclari.keys) {
          _birimDenetimKayitlari[b] = [];
          _birimNeredenNereye[b] = [];
        }
        for (final k in rapor.denetimKontrolleri) {
          _birimDenetimKayitlari.putIfAbsent(k.birimAdi, () => []).add(k);
        }
        for (final nn in rapor.neredenNereyeListesi) {
          _birimNeredenNereye.putIfAbsent(nn.birimAdi, () => []).add(nn);
        }

        // 3. Konsolide _sonAjanRaporu'nu güncelle (Tüm analiz edilen birimleri kapsasın)
        final tumBirimSonuclari = Map<String, BirimMizanAnalizSonucu>.from(_birimAnalizSonuclari);
        final tumDenetimler = <MutabakatKontrolKaydi>[];
        for (final list in _birimDenetimKayitlari.values) {
          tumDenetimler.addAll(list);
        }
        final tumNeredenNereye = <NeredenNereyeKaydi>[];
        for (final list in _birimNeredenNereye.values) {
          tumNeredenNereye.addAll(list);
        }

        _sonAjanRaporu = BeyannameAjanRaporu(
          id: rapor.id,
          yil: _seciliYil,
          ay: _seciliAy,
          olusturulmaTarihi: rapor.olusturulmaTarihi,
          analizEdilenBirimler: tumBirimSonuclari.keys.toList(),
          toplamDosyaSayisi: toplamYuklenenBelgeSayisi,
          birimSonuclari: tumBirimSonuclari,
          neredenNereyeListesi: tumNeredenNereye.isNotEmpty ? tumNeredenNereye : rapor.neredenNereyeListesi,
          denetimKontrolleri: tumDenetimler.isNotEmpty ? tumDenetimler : rapor.denetimKontrolleri,
          uygulandiMi: rapor.uygulandiMi,
          uygulanmaTarihi: rapor.uygulanmaTarihi,
        );

        if (otomatikMasalaraAktar) {
          aiAjanVerileriniUygula(rapor, uzerineEkle: false);
        } else {
          notifyListeners();
        }
      },
      onHata: (hata) {
        _isAiAjanCalisiyor = false;
        notifyListeners();
      },
    );

    _aiAjanSubscription = stream.listen(
      (log) {
        _aiAjanLoglari.add(log);
        _aiAjanIlerleme = log.ilerlemeYuzdesi;
        notifyListeners();
      },
      onError: (err) {
        _isAiAjanCalisiyor = false;
        _aiAjanLoglari.add(AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '❌ Kritik Hata: $err',
          ilerlemeYuzdesi: 1.0,
          isHata: true,
        ));
        notifyListeners();
      },
    );
  }

  void aiAjanDurdur() {
    _isTopluYuklemeDurduruldu = true;
    _aiAjanSubscription?.cancel();
    _isAiAjanCalisiyor = false;
    _aiAjanLoglari.add(AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '⏹️ İşlem kullanıcı tarafından durduruldu.',
      ilerlemeYuzdesi: _aiAjanIlerleme,
      isHata: true,
    ));
    notifyListeners();
  }

  /// AI Ajanının bulduğu verileri manuel alanları ezmeden/kullanıcı onayıyla beyanname masalarına aktarır.
  /// [uzerineEkle] true ise, masada zaten var olan birimin tutarlarının üzerine ekleme yapar (ek fatura/evrak senaryosu).
  /// [uzerineEkle] false ise (varsayılan), birim masada varsa güncel mizan değerleriyle yeniler; yoksa yeni satır olarak ekler.
  void aiAjanVerileriniUygula(BeyannameAjanRaporu rapor, {bool uzerineEkle = false}) {
    // 0. 190 Devreden KDV: Mizanlarda 190 devreden KDV varsa ve henüz girilmemişse otomatik aktar
    final toplamMizan190 = rapor.birimSonuclari.values.fold(0.0, (s, x) => s + x.devredenKdv190);
    if (toplamMizan190 > 0 && (_oncekiAydanDevredenKdv == 0 || !uzerineEkle)) {
      _oncekiAydanDevredenKdv = toplamMizan190;
    }

    // Birim analiz sonuçlarını ve denetim kayıtlarını da güncelle
    for (final entry in rapor.birimSonuclari.entries) {
      _birimAnalizSonuclari[entry.key] = entry.value;
    }
    for (final k in rapor.denetimKontrolleri) {
      _birimDenetimKayitlari.putIfAbsent(k.birimAdi, () => []).add(k);
    }
    for (final nn in rapor.neredenNereyeListesi) {
      _birimNeredenNereye.putIfAbsent(nn.birimAdi, () => []).add(nn);
    }

    for (final entry in rapor.birimSonuclari.entries) {
      final birimAdi = entry.key;
      final sonuc = entry.value;
      final bool mizanVerisiVar = sonuc.hasilat600Aylik > 0 ||
          sonuc.hasilat600Kumulatif > 0 ||
          sonuc.toplamHesaplananKdv > 0 ||
          sonuc.toplamIndirilecekKdv > 0 ||
          sonuc.damgaVergisi360 > 0;

      // 1. KDV 1 Masasını Güncelle veya Ekle
      final kdvIndex = _kdv1Satirlari.indexWhere(
        (x) => BirimAdlandirma.canonicalKey(x.birimAdi) == BirimAdlandirma.canonicalKey(birimAdi),
      );
      if (kdvIndex >= 0) {
        final mevcut = _kdv1Satirlari[kdvIndex];
        if (uzerineEkle) {
          _kdv1Satirlari[kdvIndex] = mevcut.copyWith(
            hesaplananMatrah1: mevcut.hesaplananMatrah1 + sonuc.hesaplananKdvMatrah1,
            hesaplananKdv1: mevcut.hesaplananKdv1 + sonuc.hesaplananKdv1,
            hesaplananMatrah10: mevcut.hesaplananMatrah10 + sonuc.hesaplananKdvMatrah10,
            hesaplananKdv10: mevcut.hesaplananKdv10 + sonuc.hesaplananKdv10,
            hesaplananMatrah20: mevcut.hesaplananMatrah20 + sonuc.hesaplananKdvMatrah20,
            hesaplananKdv20: mevcut.hesaplananKdv20 + sonuc.hesaplananKdv20,
            indirilecekMatrah1: mevcut.indirilecekMatrah1 + sonuc.indirilecekKdvMatrah1,
            indirilecekKdv1: mevcut.indirilecekKdv1 + sonuc.indirilecekKdv1,
            indirilecekMatrah10: mevcut.indirilecekMatrah10 + sonuc.indirilecekKdvMatrah10,
            indirilecekKdv10: mevcut.indirilecekKdv10 + sonuc.indirilecekKdv10,
            indirilecekMatrah20: mevcut.indirilecekMatrah20 + sonuc.indirilecekKdvMatrah20,
            indirilecekKdv20: mevcut.indirilecekKdv20 + sonuc.indirilecekKdv20,
          );
        } else if (mizanVerisiVar) {
          _kdv1Satirlari[kdvIndex] = mevcut.copyWith(
            hesaplananMatrah1: sonuc.hesaplananKdvMatrah1,
            hesaplananKdv1: sonuc.hesaplananKdv1,
            hesaplananMatrah10: sonuc.hesaplananKdvMatrah10,
            hesaplananKdv10: sonuc.hesaplananKdv10,
            hesaplananMatrah20: sonuc.hesaplananKdvMatrah20,
            hesaplananKdv20: sonuc.hesaplananKdv20,
            indirilecekMatrah1: sonuc.indirilecekKdvMatrah1,
            indirilecekKdv1: sonuc.indirilecekKdv1,
            indirilecekMatrah10: sonuc.indirilecekKdvMatrah10,
            indirilecekKdv10: sonuc.indirilecekKdv10,
            indirilecekMatrah20: sonuc.indirilecekKdvMatrah20,
            indirilecekKdv20: sonuc.indirilecekKdv20,
          );
        }
      } else {
        _kdv1Satirlari.add(Kdv1BirimSatiri(
          birimId: BirimAdlandirma.canonicalKey(birimAdi),
          birimAdi: birimAdi,
          hesaplananMatrah1: sonuc.hesaplananKdvMatrah1,
          hesaplananKdv1: sonuc.hesaplananKdv1,
          hesaplananMatrah10: sonuc.hesaplananKdvMatrah10,
          hesaplananKdv10: sonuc.hesaplananKdv10,
          hesaplananMatrah20: sonuc.hesaplananKdvMatrah20,
          hesaplananKdv20: sonuc.hesaplananKdv20,
          indirilecekMatrah1: sonuc.indirilecekKdvMatrah1,
          indirilecekKdv1: sonuc.indirilecekKdv1,
          indirilecekMatrah10: sonuc.indirilecekKdvMatrah10,
          indirilecekKdv10: sonuc.indirilecekKdv10,
          indirilecekMatrah20: sonuc.indirilecekKdvMatrah20,
          indirilecekKdv20: sonuc.indirilecekKdv20,
        ));
      }

      // 2. Damga Vergisi Masasını Güncelle veya Ekle
      final damgaIndex = _damgaSatirlari.indexWhere(
        (x) => BirimAdlandirma.canonicalKey(x.birimAdi) == BirimAdlandirma.canonicalKey(birimAdi),
      );
      if (damgaIndex >= 0) {
        final mevcut = _damgaSatirlari[damgaIndex];
        if (uzerineEkle && sonuc.damgaVergisi360 > 0) {
          final yeniDamga = mevcut.damgaVergisi + sonuc.damgaVergisi360;
          _damgaSatirlari[damgaIndex] = DamgaVergisiBirimSatiri(
            birimAdi: mevcut.birimAdi,
            damgaVergisi: yeniDamga,
            matrah: BeyannameHesaplamaMotoru.matrahFromDamga(yeniDamga),
          );
        } else if (mizanVerisiVar) {
          final yeniDamga = sonuc.damgaVergisi360;
          final yeniMatrah = yeniDamga <= 0
              ? 0.0
              : (sonuc.damgaMatrah > 0
                  ? sonuc.damgaMatrah
                  : BeyannameHesaplamaMotoru.matrahFromDamga(yeniDamga));
          _damgaSatirlari[damgaIndex] = DamgaVergisiBirimSatiri(
            birimAdi: mevcut.birimAdi,
            damgaVergisi: yeniDamga,
            matrah: yeniMatrah,
          );
        }
      } else if (sonuc.damgaVergisi360 > 0) {
        final matrah = sonuc.damgaMatrah > 0
            ? sonuc.damgaMatrah
            : BeyannameHesaplamaMotoru.matrahFromDamga(sonuc.damgaVergisi360);

        _damgaSatirlari.add(DamgaVergisiBirimSatiri(
          birimAdi: birimAdi,
          damgaVergisi: sonuc.damgaVergisi360,
          matrah: matrah,
        ));
      }

      // 3. 600 Hasılat & 123 Masasını Güncelle veya Ekle
      final hIndex = _hasiat600Satirlari.indexWhere(
        (x) => BirimAdlandirma.canonicalKey(x.birimAdi) == BirimAdlandirma.canonicalKey(birimAdi),
      );
      if (hIndex >= 0) {
        final mevcut = _hasiat600Satirlari[hIndex];
        if (uzerineEkle) {
          final ekAylik = sonuc.hasilat600Aylik;
          final yeniAylik = mevcut.aylikHasilat600 + ekAylik;
          final yeniKumulatif = mevcut.kumulatifHasilat600 + ekAylik;
          final yeniPos = mevcut.krediKarti123 + sonuc.krediKarti123;
          _hasiat600Satirlari[hIndex] = mevcut.copyWith(
            aylikHasilat600: yeniAylik,
            kumulatifHasilat600: yeniKumulatif,
            krediKarti123: yeniPos,
          );
        } else if (mizanVerisiVar) {
          final aylik = sonuc.hasilat600Aylik;
          final kumulatif = sonuc.hasilat600Kumulatif > 0
              ? sonuc.hasilat600Kumulatif
              : (mevcut.oncekiAylarHasilat600 + aylik);
          final pos = sonuc.krediKarti123;
          final oncekiAylar = (kumulatif >= aylik && sonuc.hasilat600Kumulatif > 0)
              ? BeyannameHesaplamaMotoru.round(kumulatif - aylik)
              : mevcut.oncekiAylarHasilat600;

          _hasiat600Satirlari[hIndex] = mevcut.copyWith(
            oncekiAylarHasilat600: oncekiAylar,
            aylikHasilat600: aylik,
            kumulatifHasilat600: kumulatif,
            krediKarti123: pos,
          );
        }
      } else {
        final aylik = sonuc.hasilat600Aylik;
        final kumulatif = sonuc.hasilat600Kumulatif > 0 ? sonuc.hasilat600Kumulatif : aylik;
        final onceki = (kumulatif > aylik) ? BeyannameHesaplamaMotoru.round(kumulatif - aylik) : 0.0;

        _hasiat600Satirlari.add(Hasiat600BirimSatiri(
          birimAdi: birimAdi,
          oncekiAylarHasilat600: onceki,
          aylikHasilat600: aylik,
          kumulatifHasilat600: kumulatif,
          krediKarti123: sonuc.krediKarti123,
        ));
      }

      // 4. KDV 2 Tevkifat Faturaları:
      // Çift işlemeyi ve mükerrer faturaları kesin olarak önlemek için, bu birime ait önceki AI tarafından eklenen
      // faturaları temizle ve güncel liste ile yenile (100% IDEMPOTENT).
      if (!uzerineEkle && sonuc.tevkifatFaturalari.isNotEmpty) {
        _tevkifatKayitlari.removeWhere((x) =>
            BirimAdlandirma.canonicalKey(x.birimAdi ?? '') == BirimAdlandirma.canonicalKey(birimAdi) &&
            x.id.startsWith('tvk_ai_'));
      }

      for (final tf in sonuc.tevkifatFaturalari) {
        final fAdi = tf['firmaAdi'] as String? ?? 'Firma';
        final vNo = (tf['vergiTcNo'] as String? ?? '').trim();
        final mtr = TurkceFormat.parseSayi(tf['matrahTutari']);
        final kdv = TurkceFormat.parseSayi(tf['kdvTutari']);
        final tvk = TurkceFormat.parseSayi(tf['tevkifatTutari']);
        final oran = (tf['tevkifatOrani'] as String? ?? '9/10').trim();

        int tespitEdilenKdvOrani = 20;
        if (mtr > 0 && kdv > 0) {
          final oranHesap = (kdv / mtr * 100).round();
          if (const [1, 8, 10, 18, 20].contains(oranHesap)) {
            tespitEdilenKdvOrani = oranHesap;
          }
        }

        if (mtr > 0) {
          final existingIndex = _tevkifatKayitlari.indexWhere(
            (x) =>
                BirimAdlandirma.canonicalKey(x.birimAdi ?? '') == BirimAdlandirma.canonicalKey(birimAdi) &&
                (x.matrahTutari - mtr).abs() < 1.0 &&
                (x.vergiTcNo == vNo || x.firmaAdi.toLowerCase() == fAdi.toLowerCase()),
          );
          final kayit = TevkifatFirmaKaydi(
            id: existingIndex >= 0
                ? _tevkifatKayitlari[existingIndex].id
                : 'tvk_ai_${BirimAdlandirma.canonicalKey(birimAdi)}_${DateTime.now().microsecondsSinceEpoch}',
            firmaAdi: fAdi,
            vergiTcNo: vNo,
            tevkifatTuru: TevkifatTuru.fromString(oran),
            tevkifatEtiketi: oran,
            kdvOrani: tespitEdilenKdvOrani,
            matrahTutari: mtr,
            kdvTutari: kdv,
            tevkifatTutari: tvk,
            birimAdi: birimAdi,
          );
          if (existingIndex >= 0) {
            _tevkifatKayitlari[existingIndex] = kayit;
          } else {
            _tevkifatKayitlari.add(kayit);
          }
        }
      }

      // 5. Muhtasar Masasını Güncelle veya Ekle (360 Stopaj Gelir Vergisi & Ücret Damga Vergisi)
      if (sonuc.muhtasarGelir360 > 0 || sonuc.muhtasarDamga360 > 0) {
        final muhtasarIndex = _muhtasarSatirlari.indexWhere(
          (x) => BirimAdlandirma.canonicalKey(x.birimAdi) == BirimAdlandirma.canonicalKey(birimAdi),
        );
        final gv = sonuc.muhtasarGelir360;
        final dv = sonuc.muhtasarDamga360;
        final brut = dv > 0 ? (dv / 0.00759) : (gv > 0 ? gv / 0.15 : 0.0);
        final net = (brut - gv - dv > 0) ? (brut - gv - dv) : 0.0;

        if (muhtasarIndex >= 0) {
          final m = _muhtasarSatirlari[muhtasarIndex];
          if (uzerineEkle) {
            _muhtasarSatirlari[muhtasarIndex] = m.copyWith(
              gelirVergisi: m.gelirVergisi + gv,
              damgaVergisi: m.damgaVergisi + dv,
              brutUcret: BeyannameHesaplamaMotoru.round(m.brutUcret + brut),
              netOdenen: BeyannameHesaplamaMotoru.round(m.netOdenen + net),
            );
          } else {
            _muhtasarSatirlari[muhtasarIndex] = m.copyWith(
              gelirVergisi: gv,
              damgaVergisi: dv,
              brutUcret: BeyannameHesaplamaMotoru.round(brut),
              netOdenen: BeyannameHesaplamaMotoru.round(net),
            );
          }
        } else {
          _muhtasarSatirlari.add(MuhtasarSatiri(
            id: 'mht_ai_${BirimAdlandirma.canonicalKey(birimAdi)}_${DateTime.now().microsecondsSinceEpoch}',
            birimAdi: birimAdi,
            adSoyad: '$birimAdi Bordro / 360 Mizan İcmali',
            gelirVergisi: gv,
            damgaVergisi: dv,
            brutUcret: BeyannameHesaplamaMotoru.round(brut),
            netOdenen: BeyannameHesaplamaMotoru.round(net),
            aylikGelirVergisiMatrahi: BeyannameHesaplamaMotoru.round(brut),
          ));
        }
      }
    }

    _guncelleDamga301();
    _sonAjanRaporu = rapor.copyWith(
      uygulandiMi: true,
      uygulanmaTarihi: DateTime.now(),
    );
    _tetikleYerelTaslakKaydi();
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveDebounceTimer?.cancel();
    _aiAjanSubscription?.cancel();
    super.dispose();
  }
}
