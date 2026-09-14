import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_model.dart';
import '../models/beyanname_konfigurasyonu.dart';
import '../providers/beyanname_provider.dart';
import '../services/beyanname_hesaplama_motoru.dart';

enum _HizliGirisTuru {
  kdv2Tevkifat,
  kdv1,
  muhtasar,
  damga,
  hasilat600,
}

/// Kullanıcının sekmeler arasında kaybolmadan; tek bir ekranda Birimini seçip,
/// KDV 1, KDV 2, Muhtasar, Damga veya 600 Hasılat verilerini anında girip
/// masalara ve Ana Sayfaya işlemesini sağlayan Akıllı Veri Giriş Penceresi.
class HizliVeriGirisiDialog extends StatefulWidget {
  final BeyannameProvider provider;

  const HizliVeriGirisiDialog({super.key, required this.provider});

  static Future<void> goster(BuildContext context, BeyannameProvider provider) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 920,
            height: 720,
            child: HizliVeriGirisiDialog(provider: provider),
          ),
        ),
      ),
    );
  }

  @override
  State<HizliVeriGirisiDialog> createState() => _HizliVeriGirisiDialogState();
}

class _HizliVeriGirisiDialogState extends State<HizliVeriGirisiDialog> {
  _HizliGirisTuru _seciliTur = _HizliGirisTuru.kdv2Tevkifat;
  String? _seciliBirim;
  bool _seriGirisModu = false;

  // Ortak Birim Listesi
  late List<String> _birimler;

  // --- KDV 1 Kontrolleri ---
  final _kdv1Hesap10Ctrl = TextEditingController();
  final _kdv1Hesap20Ctrl = TextEditingController();
  final _kdv1Ind10Ctrl = TextEditingController();
  final _kdv1Ind20Ctrl = TextEditingController();

  // --- KDV 2 Tevkifat Kontrolleri ---
  final _tevkifatFirmaCtrl = TextEditingController();
  final _tevkifatVergiNoCtrl = TextEditingController();
  String _tevkifatTuruEtiket = '9/10';
  int _tevkifatKdvOrani = 20;
  final _tevkifatMatrahCtrl = TextEditingController();
  final _tevkifatKdvCtrl = TextEditingController();
  final _tevkifatTutarCtrl = TextEditingController();

  // --- Muhtasar Kontrolleri ---
  final _muhtasarAdSoyadCtrl = TextEditingController();
  final _muhtasarKisiCtrl = TextEditingController(text: '1');
  final _muhtasarBrutCtrl = TextEditingController();
  final _muhtasarGvCtrl = TextEditingController();
  final _muhtasarDvCtrl = TextEditingController();
  final _muhtasarMatrahCtrl = TextEditingController();

  // --- Damga Kontrolleri ---
  final _damgaTutarCtrl = TextEditingController();

  // --- 600 Hasılat Kontrolleri ---
  final _hasilatAylikCtrl = TextEditingController();
  final _hasilatKrediKartiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _birimListesiniGuncelle();
    if (_birimler.isNotEmpty) {
      _seciliBirim = _birimler.first;
      _mevcutBirimVerileriniYukle();
    }
  }

  void _birimListesiniGuncelle() {
    final map = <String, String>{};
    for (final k in widget.provider.kdv1Satirlari) {
      final key = BirimAdlandirma.canonicalKey(k.birimAdi);
      if (key.isNotEmpty) map[key] = BirimAdlandirma.tamAdGetir(k.birimAdi);
    }
    for (final d in widget.provider.damgaSatirlari) {
      final key = BirimAdlandirma.canonicalKey(d.birimAdi);
      if (key.isNotEmpty) map[key] = BirimAdlandirma.tamAdGetir(d.birimAdi);
    }
    for (final h in widget.provider.hasiat600Satirlari) {
      final key = BirimAdlandirma.canonicalKey(h.birimAdi);
      if (key.isNotEmpty) map[key] = BirimAdlandirma.tamAdGetir(h.birimAdi);
    }
    _birimler = map.values.toList()..sort();
  }

  void _mevcutBirimVerileriniYukle() {
    if (_seciliBirim == null) return;
    final key = BirimAdlandirma.canonicalKey(_seciliBirim!);

    // KDV 1 mevcut verisi
    final k1Index = widget.provider.kdv1Satirlari.indexWhere(
      (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
    );
    if (k1Index != -1) {
      final s = widget.provider.kdv1Satirlari[k1Index];
      _kdv1Hesap10Ctrl.text = s.hesaplananKdv10 > 0 ? s.hesaplananKdv10.toStringAsFixed(2) : '';
      _kdv1Hesap20Ctrl.text = s.hesaplananKdv20 > 0 ? s.hesaplananKdv20.toStringAsFixed(2) : '';
      _kdv1Ind10Ctrl.text = s.indirilecekKdv10 > 0 ? s.indirilecekKdv10.toStringAsFixed(2) : '';
      _kdv1Ind20Ctrl.text = s.indirilecekKdv20 > 0 ? s.indirilecekKdv20.toStringAsFixed(2) : '';
    } else {
      _kdv1Hesap10Ctrl.clear();
      _kdv1Hesap20Ctrl.clear();
      _kdv1Ind10Ctrl.clear();
      _kdv1Ind20Ctrl.clear();
    }

    // Damga mevcut verisi
    final dIndex = widget.provider.damgaSatirlari.indexWhere(
      (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
    );
    if (dIndex != -1) {
      final d = widget.provider.damgaSatirlari[dIndex];
      _damgaTutarCtrl.text = d.damgaVergisi > 0 ? d.damgaVergisi.toStringAsFixed(2) : '';
    } else {
      _damgaTutarCtrl.clear();
    }

    // 600 Hasılat mevcut verisi
    final hIndex = widget.provider.hasiat600Satirlari.indexWhere(
      (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
    );
    if (hIndex != -1) {
      final h = widget.provider.hasiat600Satirlari[hIndex];
      _hasilatAylikCtrl.text = h.aylikHasilat600 > 0 ? h.aylikHasilat600.toStringAsFixed(2) : '';
      _hasilatKrediKartiCtrl.text = h.krediKarti123 > 0 ? h.krediKarti123.toStringAsFixed(2) : '';
    } else {
      _hasilatAylikCtrl.clear();
      _hasilatKrediKartiCtrl.clear();
    }
  }

  @override
  void dispose() {
    _kdv1Hesap10Ctrl.dispose();
    _kdv1Hesap20Ctrl.dispose();
    _kdv1Ind10Ctrl.dispose();
    _kdv1Ind20Ctrl.dispose();
    _tevkifatFirmaCtrl.dispose();
    _tevkifatVergiNoCtrl.dispose();
    _tevkifatMatrahCtrl.dispose();
    _tevkifatKdvCtrl.dispose();
    _tevkifatTutarCtrl.dispose();
    _muhtasarAdSoyadCtrl.dispose();
    _muhtasarKisiCtrl.dispose();
    _muhtasarBrutCtrl.dispose();
    _muhtasarGvCtrl.dispose();
    _muhtasarDvCtrl.dispose();
    _muhtasarMatrahCtrl.dispose();
    _damgaTutarCtrl.dispose();
    _hasilatAylikCtrl.dispose();
    _hasilatKrediKartiCtrl.dispose();
    super.dispose();
  }

  // --- Otomatik Hesaplayıcılar ---
  void _hesaplaTevkifat() {
    final matrah = double.tryParse(_tevkifatMatrahCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (matrah <= 0) {
      _tevkifatKdvCtrl.clear();
      _tevkifatTutarCtrl.clear();
      return;
    }

    // Seçili tevkifat oranını bul
    final tanim = widget.provider.konfig.tevkifatTurleri.firstWhere(
      (t) => t.etiket == _tevkifatTuruEtiket,
      orElse: () => const TevkifatTanimi(etiket: '9/10', pay: 9, payda: 10),
    );

    final kdv = BeyannameHesaplamaMotoru.round(matrah * (_tevkifatKdvOrani / 100.0));
    final tevkifat = BeyannameHesaplamaMotoru.round(kdv * (tanim.pay / tanim.payda));

    _tevkifatKdvCtrl.text = kdv.toStringAsFixed(2);
    _tevkifatTutarCtrl.text = tevkifat.toStringAsFixed(2);
    setState(() {});
  }

  double _parse(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;

  void _kaydetVeUygula() {
    if (_seciliBirim == null || _seciliBirim!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir birim seçiniz.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final provider = widget.provider;
    final birim = _seciliBirim!;
    final key = BirimAdlandirma.canonicalKey(birim);

    // Birim masalarda yoksa otomatik ekle
    provider.addBirim(birim);

    switch (_seciliTur) {
      case _HizliGirisTuru.kdv1:
        final idx = provider.kdv1Satirlari.indexWhere(
          (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
        );
        if (idx != -1) {
          final h10 = _parse(_kdv1Hesap10Ctrl);
          final h20 = _parse(_kdv1Hesap20Ctrl);
          final i10 = _parse(_kdv1Ind10Ctrl);
          final i20 = _parse(_kdv1Ind20Ctrl);

          provider.updateKdv1Satir(
            idx,
            Kdv1BirimSatiri(
              birimId: key,
              birimAdi: birim,
              hesaplananKdv10: h10,
              hesaplananMatrah10: h10 > 0 ? BeyannameHesaplamaMotoru.round(h10 * 10) : 0,
              hesaplananKdv20: h20,
              hesaplananMatrah20: h20 > 0 ? BeyannameHesaplamaMotoru.round(h20 * 5) : 0,
              indirilecekKdv10: i10,
              indirilecekMatrah10: i10 > 0 ? BeyannameHesaplamaMotoru.round(i10 * 10) : 0,
              indirilecekKdv20: i20,
              indirilecekMatrah20: i20 > 0 ? BeyannameHesaplamaMotoru.round(i20 * 5) : 0,
            ),
          );
        }
        break;

      case _HizliGirisTuru.kdv2Tevkifat:
        final matrah = _parse(_tevkifatMatrahCtrl);
        final kdv = _parse(_tevkifatKdvCtrl);
        final tevkifat = _parse(_tevkifatTutarCtrl);

        if (matrah <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen geçerli bir matrah tutarı giriniz.'), backgroundColor: AppColors.warning),
          );
          return;
        }

        provider.addTevkifatKaydi(
          TevkifatFirmaKaydi(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            firmaAdi: _tevkifatFirmaCtrl.text.trim().isEmpty ? 'Tevkifatlı Fatura' : _tevkifatFirmaCtrl.text.trim(),
            vergiTcNo: _tevkifatVergiNoCtrl.text.trim(),
            tevkifatTuru: TevkifatTuru.fromString(_tevkifatTuruEtiket),
            tevkifatEtiketi: _tevkifatTuruEtiket,
            kdvOrani: _tevkifatKdvOrani,
            matrahTutari: matrah,
            kdvTutari: kdv,
            tevkifatTutari: tevkifat,
            birimAdi: birim,
          ),
        );

        _tevkifatFirmaCtrl.clear();
        _tevkifatVergiNoCtrl.clear();
        _tevkifatMatrahCtrl.clear();
        _tevkifatKdvCtrl.clear();
        _tevkifatTutarCtrl.clear();
        break;

      case _HizliGirisTuru.muhtasar:
        final brut = _parse(_muhtasarBrutCtrl);
        final gv = _parse(_muhtasarGvCtrl);
        final dv = _parse(_muhtasarDvCtrl);
        final matrah = _parse(_muhtasarMatrahCtrl);
        final kisi = int.tryParse(_muhtasarKisiCtrl.text) ?? 1;
        final net = BeyannameHesaplamaMotoru.round(brut - gv - dv);

        provider.addMuhtasarSatir(
          MuhtasarSatiri(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            birimAdi: birim,
            adSoyad: _muhtasarAdSoyadCtrl.text.trim(),
            kisiSayisi: kisi,
            brutUcret: brut,
            gelirVergisi: gv,
            damgaVergisi: dv,
            netOdenen: net,
            aylikGelirVergisiMatrahi: matrah,
          ),
        );

        _muhtasarAdSoyadCtrl.clear();
        _muhtasarBrutCtrl.clear();
        _muhtasarGvCtrl.clear();
        _muhtasarDvCtrl.clear();
        _muhtasarMatrahCtrl.clear();
        break;

      case _HizliGirisTuru.damga:
        final idx = provider.damgaSatirlari.indexWhere(
          (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
        );
        if (idx != -1) {
          provider.updateDamgaSatir(idx, _parse(_damgaTutarCtrl));
        }
        break;

      case _HizliGirisTuru.hasilat600:
        final idx = provider.hasiat600Satirlari.indexWhere(
          (s) => BirimAdlandirma.canonicalKey(s.birimAdi) == key,
        );
        if (idx != -1) {
          provider.updateHasiatSatir(
            idx,
            aylik: _parse(_hasilatAylikCtrl),
            krediKarti: _parse(_hasilatKrediKartiCtrl),
          );
        }
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$birim için işlem başarıyla masalara ve Ana Sayfaya aktarıldı.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );

    if (!_seriGirisModu) {
      Navigator.pop(context);
    } else {
      _mevcutBirimVerileriniYukle();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: AppColors.surface,
        leading: const Icon(Icons.flash_on_rounded, color: AppColors.warning),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akıllı Beyanname Veri Giriş Sihirbazı',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              'Birimini seçip verinizi girin; KDV 1, KDV 2, Muhtasar ve Ana Sayfa otomatik hesaplansın.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================== 1. ADIM: BİRİM SEÇİMİ ====================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '1. İŞLEM YAPILACAK BİRİMİ SEÇİN:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _seciliBirim,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          items: _birimler.map((b) {
                            final kisaAd = BirimAdlandirma.kisaAdGetir(b);
                            final tamAd = BirimAdlandirma.tamAdGetir(b);
                            return DropdownMenuItem(
                              value: b,
                              child: Tooltip(
                                message: '🏢 $tamAd',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        kisaAd,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        tamAd,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _seciliBirim = val;
                              _mevcutBirimVerileriniYukle();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _yeniBirimEkleDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Yeni Birim', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          side: const BorderSide(color: AppColors.borderStrong),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==================== 2. ADIM: VERGİ / MASASI TÜRÜ SEÇİMİ ====================
            const Text(
              '2. GİRİLECEK VERGİ TÜRÜ:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 0.3),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _turKarti(
                  tur: _HizliGirisTuru.kdv2Tevkifat,
                  baslik: 'KDV 2 Tevkifat',
                  altBaslik: 'Fatura & Firma',
                  ikon: Icons.receipt_long_rounded,
                  renk: const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                _turKarti(
                  tur: _HizliGirisTuru.kdv1,
                  baslik: 'KDV 1 Girişi',
                  altBaslik: '%10 & %20',
                  ikon: Icons.balance_rounded,
                  renk: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                _turKarti(
                  tur: _HizliGirisTuru.muhtasar,
                  baslik: 'Muhtasar',
                  altBaslik: 'Bordro / Personel',
                  ikon: Icons.badge_rounded,
                  renk: const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                _turKarti(
                  tur: _HizliGirisTuru.damga,
                  baslik: 'Damga Vergisi',
                  altBaslik: '360.03.05 Mizan',
                  ikon: Icons.pie_chart_rounded,
                  renk: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                _turKarti(
                  tur: _HizliGirisTuru.hasilat600,
                  baslik: '600 Hasılat',
                  altBaslik: 'Aylık & 123 Pos',
                  ikon: Icons.trending_up_rounded,
                  renk: const Color(0xFF0284C7),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ==================== 3. ADIM: DİNAMİK FORM ALANI ====================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: _buildDinamikForm(),
            ),

            const SizedBox(height: 16),

            // Alt Butonlar ve Seri Giriş Modu
            Row(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _seriGirisModu,
                      onChanged: (v) => setState(() => _seriGirisModu = v ?? false),
                    ),
                    const Text(
                      'Seri Giriş Modu (Kaydettikten sonra formu açık tut ve sonraki faturaya geç)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _kaydetVeUygula,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Masaya ve Ana Sayfaya Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionPrimary,
                    foregroundColor: AppColors.textOnDark,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Segment Kartı ---
  Widget _turKarti({
    required _HizliGirisTuru tur,
    required String baslik,
    required String altBaslik,
    required IconData ikon,
    required Color renk,
  }) {
    final isSelected = _seciliTur == tur;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _seciliTur = tur),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? renk.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? renk : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(ikon, color: isSelected ? renk : AppColors.textMuted, size: 20),
              const SizedBox(height: 4),
              Text(
                baslik,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? renk : AppColors.textPrimary,
                ),
              ),
              Text(
                altBaslik,
                style: TextStyle(fontSize: 9.5, color: isSelected ? renk : AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dinamik Form Alanı ---
  Widget _buildDinamikForm() {
    switch (_seciliTur) {
      case _HizliGirisTuru.kdv2Tevkifat:
        return _buildKdv2Form();
      case _HizliGirisTuru.kdv1:
        return _buildKdv1Form();
      case _HizliGirisTuru.muhtasar:
        return _buildMuhtasarForm();
      case _HizliGirisTuru.damga:
        return _buildDamgaForm();
      case _HizliGirisTuru.hasilat600:
        return _build600Form();
    }
  }

  // 1. KDV 2 TEVKİFAT FORMU
  Widget _buildKdv2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KDV 2 TEVKİFATLI FATURA GİRİŞİ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _tevkifatFirmaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Firma / Kişi Adı',
                  hintText: 'örn: ABC Ltd. Şti.',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _tevkifatVergiNoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Vergi No / TC Kimlik',
                  hintText: '10 veya 11 haneli',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Tevkifat Türü
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tevkifatTuruEtiket,
                decoration: const InputDecoration(
                  labelText: 'Tevkifat Türü & Oranı',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: widget.provider.konfig.tevkifatTurleri.map((t) {
                  final yuzde = (t.oran * 100).round();
                  return DropdownMenuItem(
                    value: t.etiket,
                    child: Text('${t.etiket} (%$yuzde)', style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _tevkifatTuruEtiket = v!);
                  _hesaplaTevkifat();
                },
              ),
            ),
            const SizedBox(width: 10),
            // KDV Oranı
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _tevkifatKdvOrani,
                decoration: const InputDecoration(
                  labelText: 'KDV Oranı',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: widget.provider.konfig.kdvOranlari.map((o) {
                  return DropdownMenuItem(
                    value: o.oran,
                    child: Text('%${o.oran} KDV', style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _tevkifatKdvOrani = v!);
                  _hesaplaTevkifat();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tevkifatMatrahCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _hesaplaTevkifat(),
                decoration: const InputDecoration(
                  labelText: 'Fatura Matrah Tutarı (TL)',
                  hintText: '0,00',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_lira_rounded, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _tevkifatKdvCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Hesaplanan KDV (Otomatik)',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _tevkifatTutarCtrl,
                readOnly: true,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                decoration: InputDecoration(
                  labelText: 'Tevkifat Tutarı (Otomatik)',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFFEF3C7),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. KDV 1 FORMU
  Widget _buildKdv1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KDV 1 BİRİM MATRAH VE VERGİ GİRİŞİ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Hesaplanan KDV Tutarları (Satışlar / Çıkışlar):',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kdv1Hesap10Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hesaplanan KDV %10 (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _kdv1Hesap20Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hesaplanan KDV %20 (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'İndirilecek KDV Tutarları (Alımlar / Giderler):',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kdv1Ind10Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'İndirilecek KDV %10 (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _kdv1Ind20Ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'İndirilecek KDV %20 (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 3. MUHTASAR FORMU
  Widget _buildMuhtasarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MUHTASAR PERSONEL BORDRO KAYDI',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _muhtasarAdSoyadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Personel Adı Soyadı veya Grup Başlığı',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _muhtasarKisiCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kişi Sayısı',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _muhtasarBrutCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Brüt Ücret (TL)', isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _muhtasarGvCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Gelir Vergisi (TL)', isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _muhtasarDvCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Damga Vergisi (TL)', isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _muhtasarMatrahCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Aylık GV Matrahı (TL)', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. DAMGA VERGİSİ FORMU
  Widget _buildDamgaForm() {
    final damga = _parse(_damgaTutarCtrl);
    final matrah = damga > 0 ? BeyannameHesaplamaMotoru.matrahFromDamga(damga) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '360.03.05 ÖDEMELERDEN KESİLEN DAMGA VERGİSİ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _damgaTutarCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Mizan Damga Vergisi Tutarı (TL)',
                  hintText: 'örn: 104,28',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hesaplanan Matrah (Binde 9,48):', style: TextStyle(fontSize: 10, color: Color(0xFF5B21B6))),
                    Text(
                      TurkceFormat.para(matrah),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 5. 600 HASILAT FORMU
  Widget _build600Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '600 HASILAT VE 123 KREDİ KARTI GİRİŞİ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hasilatAylikCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Bu Ayki 600 Hasılat Tutarı (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _hasilatKrediKartiCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '123 Kredi Kartı Tutarı (TL)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _yeniBirimEkleDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Birim Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Birim Adı / Kısaltması', isDense: true),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                widget.provider.addBirim(val);
                _birimListesiniGuncelle();
                setState(() {
                  _seciliBirim = BirimAdlandirma.tamAdGetir(val);
                  _mevcutBirimVerileriniYukle();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
