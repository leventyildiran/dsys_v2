import 'package:flutter/foundation.dart';

/// Terminal satırının anlamı. Renk eşlemesi yalnızca terminal widget'ında yapılır.
enum FaturaLogSeviyesi { bilgi, katman, basarili, uyari, hata, maliyet }

/// Fatura okuma terminaline düşen tek bir log satırı.
class FaturaOkumaLog {
  final DateTime zaman;
  final String mesaj;
  final FaturaLogSeviyesi seviye;

  const FaturaOkumaLog({
    required this.zaman,
    required this.mesaj,
    this.seviye = FaturaLogSeviyesi.bilgi,
  });

  String get formatliZaman {
    String iki(int v) => v.toString().padLeft(2, '0');
    return '${iki(zaman.hour)}:${iki(zaman.minute)}:${iki(zaman.second)}';
  }
}

/// Kullanıcı terminalden "Durdur" dediğinde orkestratörün fırlattığı istisna.
class FaturaOkumaIptalEdildi implements Exception {
  const FaturaOkumaIptalEdildi();
  @override
  String toString() => 'Okuma kullanıcı tarafından durduruldu.';
}

/// Bir yükleme işleminin (bir veya birden çok dosya) canlı durumu.
///
/// Orkestratör buraya log ve sayaç yazar; [FaturaOkumaTerminali] dinler.
/// Widget'tan bağımsızdır; testlerde doğrudan kullanılabilir.
class FaturaOkumaOturumu extends ChangeNotifier {
  FaturaOkumaOturumu({this.konsolaYaz = true});

  /// true ise her log satırı debugPrint ile de yazılır.
  final bool konsolaYaz;

  /// Ücretsiz API 10 denemede yanıt veremezse, ücretli API'ye geçilmeden önce kullanıcıya sorulacak onay fonksiyonu.
  Future<bool> Function({
    required String dosyaAdi,
    required String yerelDurum,
    required double tahminiMaliyetTl,
  })? ucretliOnayIstegi;

  final List<FaturaOkumaLog> _loglar = [];
  List<FaturaOkumaLog> get loglar => List.unmodifiable(_loglar);

  final Stopwatch _sure = Stopwatch();

  bool _calisiyor = false;
  bool get calisiyor => _calisiyor;

  bool _iptalIstendi = false;
  bool get iptalIstendi => _iptalIstendi;

  double _ilerleme = 0;
  double get ilerleme => _ilerleme;

  String _aktifKatman = 'Hazır';
  String get aktifKatman => _aktifKatman;

  int _toplamDosya = 0;
  int get toplamDosya => _toplamDosya;

  int _aktifDosyaIndex = 0;
  int get aktifDosyaIndex => _aktifDosyaIndex;

  int _faturaSayisi = 0;
  int get faturaSayisi => _faturaSayisi;

  int _toplamToken = 0;
  int get toplamToken => _toplamToken;

  double _tahminiMaliyetTl = 0;
  double get tahminiMaliyetTl => _tahminiMaliyetTl;

  int _apiCagriSayisi = 0;
  int get apiCagriSayisi => _apiCagriSayisi;

  int _ucretsizOkunanDosya = 0;
  int get ucretsizOkunanDosya => _ucretsizOkunanDosya;

  int _hataliDosya = 0;
  int get hataliDosya => _hataliDosya;

  Duration get gecenSure => _sure.elapsed;

  // ─── Yaşam döngüsü ─────────────────────────────────────

  void baslat({int toplamDosya = 1}) {
    _loglar.clear();
    _toplamDosya = toplamDosya;
    _aktifDosyaIndex = 0;
    _faturaSayisi = 0;
    _toplamToken = 0;
    _tahminiMaliyetTl = 0;
    _apiCagriSayisi = 0;
    _ucretsizOkunanDosya = 0;
    _hataliDosya = 0;
    _ilerleme = 0;
    _iptalIstendi = false;
    _calisiyor = true;
    _aktifKatman = 'Başlatılıyor';
    _sure
      ..reset()
      ..start();
    notifyListeners();
  }

  void dosyaBasla(int index, String dosyaAdi) {
    _aktifDosyaIndex = index;
    _ilerleme = _toplamDosya == 0 ? 0 : index / _toplamDosya;
    log(
      '━━━ Dosya ${index + 1}/$_toplamDosya: $dosyaAdi ━━━',
      seviye: FaturaLogSeviyesi.katman,
    );
  }

  /// Dosya içi ilerlemeyi (0..1) genel ilerlemeye yansıtır.
  void dosyaIciIlerleme(double oran) {
    if (_toplamDosya == 0) return;
    final pay = 1 / _toplamDosya;
    _ilerleme = ((_aktifDosyaIndex + oran.clamp(0.0, 1.0)) * pay).clamp(0.0, 1.0);
    notifyListeners();
  }

  void katmanDegisti(String katman) {
    _aktifKatman = katman;
    notifyListeners();
  }

  void log(String mesaj, {FaturaLogSeviyesi seviye = FaturaLogSeviyesi.bilgi}) {
    _loglar.add(
      FaturaOkumaLog(zaman: DateTime.now(), mesaj: mesaj, seviye: seviye),
    );
    if (konsolaYaz) debugPrint('[FaturaOkuma] $mesaj');
    notifyListeners();
  }

  void apiKullanimiEkle({required int token, required double maliyetTl}) {
    _apiCagriSayisi++;
    _toplamToken += token;
    _tahminiMaliyetTl += maliyetTl;
    notifyListeners();
  }

  void faturaEklendi(int adet, {required bool ucretsiz}) {
    _faturaSayisi += adet;
    if (ucretsiz) _ucretsizOkunanDosya++;
    notifyListeners();
  }

  void dosyaHatali() {
    _hataliDosya++;
    notifyListeners();
  }

  void iptalEt() {
    if (!_calisiyor) return;
    _iptalIstendi = true;
    log('⏹ Durdurma istendi, mevcut adım bitince duracak…',
        seviye: FaturaLogSeviyesi.uyari);
  }

  /// Orkestratör uzun adımlar arasında çağırır.
  void iptalKontrol() {
    if (_iptalIstendi) throw const FaturaOkumaIptalEdildi();
  }

  void tamamla() {
    _sure.stop();
    _calisiyor = false;
    _ilerleme = 1;
    _aktifKatman = _hataliDosya > 0 && _faturaSayisi == 0 ? 'Hata' : 'Tamamlandı';
    final sn = (gecenSure.inMilliseconds / 1000).toStringAsFixed(1);
    log(
      '■ ÖZET: $_faturaSayisi fatura · $_apiCagriSayisi API çağrısı · '
      '$_toplamToken token · Tahmini maliyet: ${maliyetMetni(_tahminiMaliyetTl)} · $sn sn',
      seviye: _faturaSayisi > 0
          ? FaturaLogSeviyesi.basarili
          : FaturaLogSeviyesi.hata,
    );
  }

  static String maliyetMetni(double tl) {
    if (tl <= 0) return '0,00 TL';
    if (tl < 0.01) return '< 0,01 TL';
    return '${tl.toStringAsFixed(2).replaceAll('.', ',')} TL';
  }

  @override
  void dispose() {
    _sure.stop();
    super.dispose();
  }
}
