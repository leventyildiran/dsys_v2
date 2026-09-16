import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/turkce_format.dart';
import '../models/beyanname_konfigurasyonu.dart';
import '../providers/beyanname_provider.dart';
import '../services/beyanname_konfigurasyon_servisi.dart';
import 'widgets/konfig_bolumleri.dart';

/// Kurum bazlı beyanname yapılandırma ekranı.
///
/// [SistemAyarlariScreen] içine gömülü çalışır (kendi `Scaffold`'u yoktur).
/// Ayarları Firestore'dan okur/yazar; böylece her kurum (tenant) kendi KDV
/// oranlarını, tevkifat türlerini, damga oranını ve görünen blokları yönetebilir.
///
/// Sistem her alanı otomatik önerir (varsayılan değerler) ama kullanıcı her
/// aşamada elle değiştirebilir; "Varsayılana Dön" ile kuruma özel kayıt silinir.
class BeyannameKonfigurasyonScreen extends StatefulWidget {
  const BeyannameKonfigurasyonScreen({super.key});

  @override
  State<BeyannameKonfigurasyonScreen> createState() =>
      _BeyannameKonfigurasyonScreenState();
}

class _BeyannameKonfigurasyonScreenState
    extends State<BeyannameKonfigurasyonScreen> {
  final BeyannameKonfigurasyonServisi _servis = BeyannameKonfigurasyonServisi();
  final TextEditingController _damgaController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String _kurumId = '';
  List<KdvOranTanimi> _kdvOranlari = const [];
  List<TevkifatTanimi> _tevkifatlar = const [];
  BeyannameBloklari _bloklar = const BeyannameBloklari();
  List<AsgariUcretYilTablosu> _asgariUcretTablolari = const [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _damgaController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Yükleme / kaydetme
  // ---------------------------------------------------------------------------

  Future<void> _yukle() async {
    final konfig = await _servis.getir();
    if (!mounted) return;
    setState(() {
      _konfigUygula(konfig);
      _isLoading = false;
    });
  }

  void _konfigUygula(BeyannameKonfigurasyonu konfig) {
    _kurumId = konfig.kurumId;
    _kdvOranlari = List<KdvOranTanimi>.of(konfig.kdvOranlari);
    _tevkifatlar = List<TevkifatTanimi>.of(konfig.tevkifatTurleri);
    _damgaController.text = _bindeMetni(konfig.damgaBinde);
    _bloklar = konfig.bloklar;
    _asgariUcretTablolari =
        List<AsgariUcretYilTablosu>.of(konfig.asgariUcretTablolari);
  }

  BeyannameKonfigurasyonu _topla() {
    final duzeltilmisTablolar = _asgariUcretTablolari.map((t) {
      if (t.yil <= 0) {
        return t.copyWith(yil: DateTime.now().year);
      }
      return t;
    }).toList();

    return BeyannameKonfigurasyonu(
      kurumId: _kurumId,
      kdvOranlari: _kdvOranlari.where((e) => e.oran > 0).toList(),
      tevkifatTurleri: _tevkifatlar.where((e) => e.payda > 0).toList(),
      damgaBinde: _bindeOku(_damgaController.text),
      bloklar: _bloklar,
      asgariUcretTablolari: duzeltilmisTablolar,
    );
  }

  Future<void> _kaydet() async {
    final provider = context.read<BeyannameProvider>();
    setState(() => _isSaving = true);
    try {
      await provider.konfigKaydet(_topla());
      if (mounted) {
        _bildir('Beyanname yapılandırması kaydedildi.', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _bildir('Kaydedilemedi: $e', AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _varsayilanaDon() async {
    final onay = await _onayIste();
    if (onay != true) return;
    if (!mounted) return;
    final provider = context.read<BeyannameProvider>();
    setState(() => _isSaving = true);
    try {
      await provider.konfigVarsayilanaDon();
      if (!mounted) return;
      setState(() => _konfigUygula(BeyannameKonfigurasyonu.varsayilan));
      _bildir('Varsayılan yapılandırmaya dönüldü.', AppColors.info);
    } catch (e) {
      if (mounted) {
        _bildir('Sıfırlanamadı: $e', AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _onayIste() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılana dönülsün mü?'),
        content: const Text(
          'Bu kuruma özel beyanname yapılandırması silinecek ve sistem '
          'varsayılan değerleri kullanılacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionDestructive,
              foregroundColor: AppColors.textOnDark,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Varsayılana Dön'),
          ),
        ],
      ),
    );
  }

  void _bildir(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: renk),
    );
  }

  String _bindeMetni(double deger) => deger.toString();

  double _bindeOku(String metin) {
    return TurkceFormat.parseSayi(
      metin,
      fallback: BeyannameKonfigurasyonu.varsayilanDamgaBinde,
    );
  }

  // ---------------------------------------------------------------------------
  // Liste işlemleri
  // ---------------------------------------------------------------------------

  void _kdvEkle() {
    setState(() {
      _kdvOranlari = [
        ..._kdvOranlari,
        const KdvOranTanimi(oran: 20, etiket: null),
      ];
    });
  }

  void _kdvDegistir(int index, KdvOranTanimi yeni) {
    setState(() {
      final liste = List<KdvOranTanimi>.of(_kdvOranlari);
      liste[index] = yeni;
      _kdvOranlari = liste;
    });
  }

  void _kdvSil(int index) {
    setState(() {
      final liste = List<KdvOranTanimi>.of(_kdvOranlari)..removeAt(index);
      _kdvOranlari = liste;
    });
  }

  void _tevkifatEkle() {
    setState(() {
      _tevkifatlar = [
        ..._tevkifatlar,
        const TevkifatTanimi(etiket: '9/10', pay: 9, payda: 10),
      ];
    });
  }

  void _tevkifatDegistir(int index, TevkifatTanimi yeni) {
    setState(() {
      final liste = List<TevkifatTanimi>.of(_tevkifatlar);
      liste[index] = yeni;
      _tevkifatlar = liste;
    });
  }

  void _tevkifatSil(int index) {
    setState(() {
      final liste = List<TevkifatTanimi>.of(_tevkifatlar)..removeAt(index);
      _tevkifatlar = liste;
    });
  }

  void _yilEkle() {
    setState(() {
      int sonrakiYil = DateTime.now().year;
      if (_asgariUcretTablolari.isNotEmpty) {
        final gecerliYillar = _asgariUcretTablolari
            .map((e) => e.yil)
            .where((y) => y > 0)
            .toList();
        if (gecerliYillar.isNotEmpty) {
          sonrakiYil = gecerliYillar.reduce((a, b) => a > b ? a : b) + 1;
        }
      }
      _asgariUcretTablolari = [
        ..._asgariUcretTablolari,
        AsgariUcretYilTablosu(yil: sonrakiYil),
      ];
    });
  }

  void _yilDegistir(int index, AsgariUcretYilTablosu yeni) {
    setState(() {
      final liste = List<AsgariUcretYilTablosu>.of(_asgariUcretTablolari);
      liste[index] = yeni;
      _asgariUcretTablolari = liste;
    });
  }

  void _yilSil(int index) {
    setState(() {
      final liste = List<AsgariUcretYilTablosu>.of(_asgariUcretTablolari)
        ..removeAt(index);
      _asgariUcretTablolari = liste;
    });
  }

  // ---------------------------------------------------------------------------
  // Görünüm
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _baslik(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bilgiBandi(),
                  const SizedBox(height: 20),
                  _damgaBolumu(),
                  const SizedBox(height: 16),
                  _kdvBolumu(),
                  const SizedBox(height: 16),
                  _tevkifatBolumu(),
                  const SizedBox(height: 16),
                  _asgariUcretBolumu(),
                  const SizedBox(height: 16),
                  _blokBolumu(),
                ],
              ),
            ),
          ),
          _eylemCubugu(),
        ],
      ),
    );
  }

  Widget _baslik() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Beyanname Yapılandırması',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bu kurumun beyanname oranları, tevkifat türleri, damga oranı '
                  've birim sorumluluk profilleri.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bilgiBandi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.notZemin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.notCerceve),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: AppColors.notMetin, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Buradaki değerler kuruma özeldir ve yalnızca aktif kurumu etkiler. '
              'Kaydedilen değerler beyanname tablolarında, hesaplamalarda ve '
              'doğrulamada anında kullanılır. Kayıt yoksa sistem varsayılan '
              'değerleri (KDV %10/%20, tevkifat 9/10-7/10-5/10, damga binde 9,48) '
              'uygular.',
              style: TextStyle(fontSize: 13, color: AppColors.notMetin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _damgaBolumu() {
    return KonfigBolumKarti(
      ikon: Icons.percent_rounded,
      baslik: 'Damga Vergisi',
      aciklama:
          'Damga vergisi oranı "binde" cinsinden girilir. Varsayılan binde 9,48.',
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: _damgaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Oran (binde)',
                hintText: '9,48',
                helperText: 'Örn: 9,48',
                suffixText: '‰',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kdvBolumu() {
    return KonfigBolumKarti(
      ikon: Icons.percent,
      baslik: 'KDV Oranları',
      aciklama:
          'Beyanname tablolarında ve doğrulamada kullanılacak KDV oranları.',
      sagUstEylem: OutlinedButton.icon(
        onPressed: _kdvEkle,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Oran Ekle'),
      ),
      child: KdvOranlariEditor(
        oranlar: _kdvOranlari,
        onDegisti: _kdvDegistir,
        onSil: _kdvSil,
      ),
    );
  }

  Widget _tevkifatBolumu() {
    return KonfigBolumKarti(
      ikon: Icons.call_split,
      baslik: 'Tevkifat Türleri',
      aciklama: 'Serbest pay/payda tanımı (örn. 9/10, 7/10, 5/10).',
      sagUstEylem: OutlinedButton.icon(
        onPressed: _tevkifatEkle,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Tür Ekle'),
      ),
      child: TevkifatEditor(
        tevkifatlar: _tevkifatlar,
        onDegisti: _tevkifatDegistir,
        onSil: _tevkifatSil,
      ),
    );
  }

  Widget _asgariUcretBolumu() {
    return KonfigBolumKarti(
      ikon: Icons.calendar_month_outlined,
      baslik: 'Asgari Ücret Vergi İstisnası',
      aciklama:
          'Yıllık istisna tabloları (aylık gelir ve damga vergisi). Boşken '
          'sistem yerleşik 2025 tablosunu kullanır; yeni yıl eklenebilir.',
      sagUstEylem: OutlinedButton.icon(
        onPressed: _yilEkle,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Yıl Ekle'),
      ),
      child: AsgariUcretTablolariEditor(
        tablolar: _asgariUcretTablolari,
        onDegisti: _yilDegistir,
        onSil: _yilSil,
      ),
    );
  }

  Widget _blokBolumu() {
    return KonfigBolumKarti(
      ikon: Icons.view_agenda_outlined,
      baslik: 'Beyanname Blokları',
      aciklama:
          'Kurumda karşılığı olmayan bölümleri kapatabilirsiniz (kapatılan blok '
          'gösterilmez).',
      child: BeyannameBloklariEditor(
        bloklar: _bloklar,
        onChanged: (yeni) => setState(() => _bloklar = yeni),
      ),
    );
  }

  Widget _eylemCubugu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _varsayilanaDon,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Varsayılana Dön'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.actionDestructive,
              side: const BorderSide(color: AppColors.dangerBorder),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _kaydet,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnDark,
                      ),
                    )
                  : const Icon(Icons.save, color: AppColors.textOnDark),
              label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: AppColors.textOnDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
