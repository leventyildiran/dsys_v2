import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/turkce_format.dart';
import '../providers/beyanname_provider.dart';
import '../models/beyanname_model.dart';
import '../services/beyanname_hesaplama_motoru.dart';
import '../services/beyanname_rapor_servisi.dart';
import '../services/beyanname_excel_servisi.dart';
import '../widgets/editable_cell.dart';
import '../../birim/models/birim_model.dart';
import '../../personel/models/personel_model.dart';
import '../../personel/services/personel_service.dart';
import '../../../core/models/firma_model.dart';
import '../../fatura/components/firma_secici_dialog.dart';
import 'hizli_veri_girisi_dialog.dart';
import 'vergi_arama_dialog.dart';

class BeyannameHesaplaScreen extends StatefulWidget {
  const BeyannameHesaplaScreen({super.key});

  @override
  State<BeyannameHesaplaScreen> createState() => _BeyannameHesaplaScreenState();
}

class _BeyannameHesaplaScreenState extends State<BeyannameHesaplaScreen> {
  int _activeTabIndex = 0;
  final ScrollController _scrollController = ScrollController();

  final List<String> _aylar = const [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  final List<String> _tabTitles = const [
    '📊 Ana Sayfa (Excel Özeti)',
    '📋 Birim Bazlı Vergiler',
    '📑 KDV 1 Masası',
    '✂️ KDV 2 Tevkifat',
    '👥 Muhtasar Bordro',
    '🏷️ Damga (360.03.05)',
    '📈 600 Hasılat & 123',
  ];

  final List<Color> _tabColors = const [
    Color(0xFF1E40AF), // 0. Ana Sayfa (Mavi / Kurumsal)
    Color(0xFF15803D), // 1. Birim Bazlı Vergiler (Yeşil)
    Color(0xFF2563EB), // 2. KDV 1 (Kraliyet Mavisi)
    Color(0xFFD97706), // 3. KDV 2 (Sıcak Kehribar)
    Color(0xFF059669), // 4. Muhtasar (Zümrüt Yeşili)
    Color(0xFF7C3AED), // 5. Damga (Asil Mor)
    Color(0xFF0284C7), // 6. 600 Hasılat (Camgöbeği)
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BeyannameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildExcelHeader(context, provider),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryKpiBanner(provider),
                if (provider.isDonemKayitli) _buildKilitDurumBari(context, provider),
                _buildExcelTabs(),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      child: _buildActiveTabContent(provider),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ==================== KAYITLI DÖNEM KORUMA / KİLİT UYARISI ====================
  Widget _buildKilitDurumBari(BuildContext context, BeyannameProvider provider) {
    final ayAd = _aylar[provider.seciliAy - 1];
    final isLocked = !provider.duzenlemeKilidiAcik;

    if (isLocked) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warningSubtle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.warning),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ Bu beyanname ($ayAd ${provider.seciliYil}) sisteme resmi olarak kaydedilmiştir. Veriler korumalı moddadır.',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
              ),
            ),
            SizedBox(
              height: 26,
              child: ElevatedButton.icon(
                onPressed: () => _showKilidiAcDialog(context, provider),
                icon: const Icon(Icons.lock_open_rounded, size: 13),
                label: const Text('Kilidi Aç ve Düzenle', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.infoSubtle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.info),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_open_rounded, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🔓 Düzenleme Modu Açık: Kayıtlı $ayAd ${provider.seciliYil} beyannamesi üzerinde değişiklik yapıyorsunuz. Değişiklikleri kalıcı kılmak için "Kaydet"e basınız.',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info),
              ),
            ),
            SizedBox(
              height: 26,
              child: OutlinedButton.icon(
                onPressed: () => provider.kilitle(),
                icon: const Icon(Icons.lock_outline_rounded, size: 13),
                label: const Text('Tekrar Kilitle', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showKilidiAcDialog(BuildContext context, BeyannameProvider provider) async {
    final ayAd = _aylar[provider.seciliAy - 1];
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Kayıtlı Beyannameyi Düzenle'),
          ],
        ),
        content: Text(
          '$ayAd ${provider.seciliYil} beyannamesi daha önce sisteme kaydedilmiştir.\n\nYine de bu dönem üzerinde değişiklik yapmak istiyor musunuz?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır, Korumada Kalsın'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Kilidi Aç ve Düzenle'),
          ),
        ],
      ),
    );
    if (onay == true) {
      provider.kilidiAc();
    }
  }

  Future<void> _donemiTemizleDialog(BuildContext context, BeyannameProvider provider) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Dönemi Sıfırla / Temizle'),
          ],
        ),
        content: const Text('Bu aya ait girilmiş tüm veriler ve yerel taslak temizlenecektir. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Temizle'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await provider.donemiSifirla();
    }
  }

  Future<void> _defterdarlikExcelIndir(BuildContext context, BeyannameProvider provider) async {
    try {
      await BeyannameExcelServisi.defterdarlikExceliniIndir(provider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${_aylar[provider.seciliAy - 1]} ${provider.seciliYil} Defterdarlık Exceli (.xlsx) başarıyla indirildi.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel üretilirken hata: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _beyannameKaydet(BuildContext context, BeyannameProvider provider) async {
    final ok = await provider.kaydet();
    if (context.mounted) {
      final msg = ok
          ? 'Beyanname başarıyla kaydedildi.'
          : (provider.errorMessage != null && provider.errorMessage!.isNotEmpty
              ? 'Kayıt Hatası: ${provider.errorMessage}'
              : 'Kayıt sırasında bir hata oluştu! Lütfen tekrar deneyiniz.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
          duration: Duration(seconds: ok ? 2 : 5),
        ),
      );
    }
  }

  // ==================== APP BAR / EXCEL TOOLBAR ====================
  PreferredSizeWidget _buildExcelHeader(BuildContext context, BeyannameProvider provider) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: AppColors.surface,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF107C41), // Excel yeşili
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'DSYS VERGİ & BEYANNAME',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Yıl Seçici
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.seciliYil,
                items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (y) => provider.donemDegistir(y!, provider.seciliAy),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Ay Seçici
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.seciliAy,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_aylar[i]))),
                onChanged: (m) => provider.donemDegistir(provider.seciliYil, m!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Otomatik / Anlık Taslak Kayıt Göstergesi
        if (provider.isAutoSaving)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.infoSubtle,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.info),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
                ),
                SizedBox(width: 6),
                Text(
                  'Kaydediliyor...',
                  style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else if (provider.sonTaslakZamani != null)
          Tooltip(
            message: 'Yerel taslak hafızada güvende',
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.successSubtle,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Taslak: ${provider.sonTaslakZamani!.hour.toString().padLeft(2, '0')}:${provider.sonTaslakZamani!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 8),

        // 1) VERİ & ARAÇLAR AÇILIR MENÜSÜ
        PopupMenuButton<String>(
          tooltip: 'Veri Girişi ve Araçlar Menüsü',
          offset: const Offset(0, 36),
          onSelected: (val) async {
            switch (val) {
              case 'hizli_giris':
                HizliVeriGirisiDialog.goster(context, provider);
                break;
              case 'vergi_arama':
                VergiAramaDialog.goster(context, provider);
                break;
              case 'ornek_veri':
                provider.ornekEylulVerisiniYukle();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Eylül 2025 Excel verileri masaya yüklendi.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                break;
              case 'temizle':
                _donemiTemizleDialog(context, provider);
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'hizli_giris',
              child: Row(
                children: [
                  Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFEA580C)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Hızlı Veri Girişi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Toplu matrah ve KDV masası', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'vergi_arama',
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Vergi Arama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Tevkifat ve vergi kod rehberi', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'ornek_veri',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 18, color: AppColors.info),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Örnek Veri Yükle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Eylül 2025 şablonunu masaya aktar', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'temizle',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Dönemi Sıfırla / Temizle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
                      Text('Masayı ve taslağı sıfırlar', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14, color: AppColors.textPrimary),
                SizedBox(width: 6),
                Text('Veri & Araçlar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2) RAPORLAR & ÇIKTI AÇILIR MENÜSÜ
        PopupMenuButton<String>(
          tooltip: 'Raporlar ve Dışa Aktarım',
          offset: const Offset(0, 36),
          onSelected: (val) async {
            if (val == 'excel') {
              _defterdarlikExcelIndir(context, provider);
            } else if (val == 'pdf_aktif') {
              BeyannameRaporServisi.sayfaRaporuYazdir(context, provider, _activeTabIndex);
            } else if (val == 'pdf_konsolide') {
              BeyannameRaporServisi.sayfaRaporuYazdir(context, provider, 0);
            } else if (val.startsWith('pdf_tab_')) {
              final idx = int.tryParse(val.replaceAll('pdf_tab_', '')) ?? 0;
              BeyannameRaporServisi.sayfaRaporuYazdir(context, provider, idx);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.table_view_rounded, size: 18, color: AppColors.success),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Defterdarlık Exceli (.xlsx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Birim bazlı detaylı inceleme cetveli', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'pdf_aktif',
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📄 Açık Olan Masayı PDF İndir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                        Text('${_tabTitles[_activeTabIndex]} (Aktif Sayfa)', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf_konsolide',
              child: Row(
                children: [
                  Icon(Icons.print_rounded, size: 18, color: Color(0xFF1E40AF)),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📑 Konsolide İcmal Raporu (Tüm Masalar)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Resmi döküm ve tahakkuk icmali', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            ...List.generate(_tabTitles.length, (i) {
              return PopupMenuItem(
                value: 'pdf_tab_$i',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 16, color: _tabColors[i]),
                    const SizedBox(width: 10),
                    Text(_tabTitles[i], style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 14, color: AppColors.textPrimary),
                SizedBox(width: 6),
                Text('Raporlar & Excel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 3) KAYDET BUTONU
        SizedBox(
          height: 30,
          child: ElevatedButton.icon(
            onPressed: () => _beyannameKaydet(context, provider),
            icon: const Icon(Icons.save_rounded, size: 14),
            label: const Text('Kaydet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ==================== KPI BANNER (EXCEL ÜST ÇERÇEVE) ====================
  Widget _buildSummaryKpiBanner(BeyannameProvider provider) {
    final k1 = provider.kdv1Sonuc;
    final k2 = provider.kdv2Sonuc;
    final m = provider.muhtasarSonuc;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildKpiCard('ÖDENECEK KDV 1', TurkceFormat.para(k1.odenecekKdv1), const Color(0xFF2563EB), Icons.receipt_long_rounded),
          const SizedBox(width: 12),
          _buildKpiCard('KDV 2 TEVKİFAT', TurkceFormat.para(k2.butunTevkifatlarToplami), const Color(0xFFD97706), Icons.call_split_rounded),
          const SizedBox(width: 12),
          _buildKpiCard('MUHTASAR (301+302)', TurkceFormat.para(m.toplamDamgaVergisi301Ve302), const Color(0xFF059669), Icons.badge_rounded),
          const SizedBox(width: 12),
          _buildKpiCard('DAMGA MATRAH (9,48)', TurkceFormat.para(provider.damgaToplamMatrah), const Color(0xFF7C3AED), Icons.calculate_rounded),
          const SizedBox(width: 12),
          _buildKpiCard('600 KÜMÜLATİF HASILAT', TurkceFormat.para(provider.hasiat600ToplamKumulatif), const Color(0xFF0284C7), Icons.trending_up_rounded),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ==================== SEKME BUTONLARI (EXCEL SHEET TABLARI) ====================
  Widget _buildExcelTabs() {
    return Container(
      color: const Color(0xFFF1F5F9), // Zarif nötr zemin
      height: 40,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _tabTitles.length,
        itemBuilder: (context, i) {
          final isSelected = _activeTabIndex == i;
          final tabColor = _tabColors[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _activeTabIndex = i),
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: tabColor, width: 1.5)
                      : Border.all(color: Colors.transparent),
                  boxShadow: isSelected
                      ? [BoxShadow(color: tabColor.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  _tabTitles[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? tabColor : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== AKTİF İÇERİK SEÇİCİ ====================
  Widget _buildActiveTabContent(BeyannameProvider provider) {
    switch (_activeTabIndex) {
      case 0:
        return _buildExcelAnaSayfa(provider);
      case 1:
        return _buildBirimIcmal(provider);
      case 2:
        return _buildKdv1Masasi(provider);
      case 3:
        return _buildKdv2TevkifatMasasi(provider);
      case 4:
        return _buildMuhtasarMasasi(provider);
      case 5:
        return _buildDamgaMasasi(provider);
      case 6:
        return _build600Masasi(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // 1. ANA SAYFA (EXCEL 'Ana Sayfa' ÇARŞAF TABLOSUNUN BİREBİR YANSITILMASI)
  // =========================================================================
  Widget _buildExcelAnaSayfa(BeyannameProvider provider) {
    final k1 = provider.kdv1Sonuc;
    final k2 = provider.kdv2Sonuc;
    final m = provider.muhtasarSonuc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. KDV 1 BÖLÜMÜ ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('KDV 1 (HESAPLANAN & İNDİRİLECEK KDV DENGESİ)', accentColor: const Color(0xFF1D4ED8)),
            _buildSayfaPdfButton(context, provider, 0),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            // Başlık Satırı
            _headerRow(
              ['AÇIKLAMA / KALEM', 'KDV %10', 'KDV %20', 'HESAPLANAN TOPLAM KDV (%10 ve %20 Toplamları)'],
              bg: const Color(0xFFDBEAFE),
              textColor: const Color(0xFF1E3A8A),
              alignments: const [TextAlign.left, TextAlign.right, TextAlign.right, TextAlign.right],
            ),
            // Hesaplanan KDV
            _dataRow('HESAPLANAN MATRAH', [
              TurkceFormat.para(k1.matrah10Hesaplanan),
              TurkceFormat.para(k1.matrah20Hesaplanan),
              TurkceFormat.para(k1.matrah10Hesaplanan + k1.matrah20Hesaplanan),
            ]),
            _dataRow('HESAPLANAN KDV TUTARI', [
              TurkceFormat.para(k1.kdv10Hesaplanan),
              TurkceFormat.para(k1.kdv20Hesaplanan),
              TurkceFormat.para(k1.toplamHesaplananKdv),
            ], isBold: true, bg: const Color(0xFFF8FAFC)),
            _dataRow('MATRAH + KDV TUTARI TOPLAMI', [
              TurkceFormat.para(k1.matrah10Hesaplanan + k1.kdv10Hesaplanan),
              TurkceFormat.para(k1.matrah20Hesaplanan + k1.kdv20Hesaplanan),
              TurkceFormat.para(k1.matrah10Hesaplanan + k1.matrah20Hesaplanan + k1.toplamHesaplananKdv),
            ]),
            // Ayraç satırı
            _dividerRow('İNDİRİLECEK KDV', 4, bg: const Color(0xFFBFDBFE), textColor: const Color(0xFF1D4ED8)),
            // İndirilecek KDV
            _dataRow('İNDİRİLECEK MATRAH', [
              TurkceFormat.para(k1.matrah10Indirilecek),
              TurkceFormat.para(k1.matrah20Indirilecek),
              TurkceFormat.para(k1.matrah10Indirilecek + k1.matrah20Indirilecek),
            ]),
            _dataRow('İNDİRİLECEK KDV TUTARI', [
              TurkceFormat.para(k1.kdv10Indirilecek),
              TurkceFormat.para(k1.kdv20Indirilecek),
              TurkceFormat.para(k1.toplamIndirilecekKdv),
            ], isBold: true, bg: const Color(0xFFF8FAFC)),
            _dataRow('MATRAH + KDV TUTARI TOPLAMI', [
              TurkceFormat.para(k1.matrah10Indirilecek + k1.kdv10Indirilecek),
              TurkceFormat.para(k1.matrah20Indirilecek + k1.kdv20Indirilecek),
              TurkceFormat.para(k1.matrah10Indirilecek + k1.matrah20Indirilecek + k1.toplamIndirilecekKdv),
            ]),
            if (k1.oncekiDonemdenDevredenKdv > 0)
              _dataRow('ÖNCEKİ DÖNEMDEN DEVREDEN KDV', [
                '-',
                '-',
                TurkceFormat.para(k1.oncekiDonemdenDevredenKdv),
              ]),
            // Vurgulu Net Ödenecek / Devreden KDV Satırı
            _highlightRow(
              k1.sonrakiDonemeDevredenKdv > 0
                  ? 'SONRAKİ DÖNEME DEVREDEN KDV'
                  : 'ÖDENECEK KDV (HESAPLANAN - İNDİRİLECEK - DEVİR)',
              TurkceFormat.para(k1.sonrakiDonemeDevredenKdv > 0 ? k1.sonrakiDonemeDevredenKdv : k1.odenecekKdv1),
              k1.sonrakiDonemeDevredenKdv > 0 ? const Color(0xFFD97706) : const Color(0xFF1D4ED8),
              colSpan: 4,
            ),
          ],
          borderColor: const Color(0xFFBFDBFE),
          gridColor: const Color(0xFFEFF6FF),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.8),
          },
        ),
        const SizedBox(height: 16),

        // --- 2. KDV 2 TEVKİFATLAR BÖLÜMÜ (9/10, 7/10, 5/10) ---
        _buildSheetTitle('KDV 2 TEVKİFAT ÖZETİ (9/10, 7/10, 5/10 ORANLARI)', accentColor: const Color(0xFFD97706)),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['TEVKİFAT TÜRÜ', 'MATRAH TOPLAMI', 'KDV TOPLAMI', 'ORAN', 'TEVKİFAT TUTARI'],
              bg: const Color(0xFFFEF3C7),
              textColor: const Color(0xFF92400E),
              alignments: const [TextAlign.left, TextAlign.right, TextAlign.right, TextAlign.center, TextAlign.right],
            ),
            _dataRow('9 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.dokuzBoluOn.etiket] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.dokuzBoluOn.etiket] ?? 0),
              '9 / 10 (%90)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.dokuzBoluOn.etiket] ?? 0),
            ]),
            _dataRow('7 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.yediBoluOn.etiket] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.yediBoluOn.etiket] ?? 0),
              '7 / 10 (%70)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.yediBoluOn.etiket] ?? 0),
            ]),
            _dataRow('5 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.besBoluOn.etiket] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.besBoluOn.etiket] ?? 0),
              '5 / 10 (%50)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.besBoluOn.etiket] ?? 0),
            ]),
            _highlightRow(
              'BÜTÜN TEVKİFAT TÜRLERİNİN (9/10+7/10+5/10) TEVKİFAT TOPLAMI',
              TurkceFormat.para(k2.butunTevkifatlarToplami),
              const Color(0xFFD97706),
              colSpan: 5,
            ),
          ],
          borderColor: const Color(0xFFFDE68A),
          gridColor: const Color(0xFFFFFBEB),
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.4),
          },
        ),
        const SizedBox(height: 16),

        // --- 3. FİRMA / KİŞİ BİLGİLERİ DÖKÜMÜ ---
        _buildSheetTitle('KDV 2 TEVKİFATLI FİRMA / KİŞİ BİLGİLERİ', accentColor: const Color(0xFFD97706)),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['FİRMA / KİŞİ ADI', 'VERGİ / TC NO', 'TÜR / ORAN', 'MATRAH TUTARI', 'KDV TUTARI', 'TEVKİFAT TUTARI'],
              bg: const Color(0xFFFEF3C7),
              textColor: const Color(0xFF92400E),
            ),
            if (provider.tevkifatKayitlari.isEmpty)
              _singleCellRow('Kayıtlı tevkifat firması bulunmuyor.', 6)
            else
              ...provider.tevkifatKayitlari.map((f) => TableRow(
                    children: [
                      _cellText(f.firmaAdi, isBold: true, align: TextAlign.left),
                      _cellText(f.vergiTcNo, align: TextAlign.center),
                      _cellText('${f.tevkifatTuru.etiket} (%${f.kdvOrani})', align: TextAlign.center),
                      _cellText(TurkceFormat.para(f.matrahTutari)),
                      _cellText(TurkceFormat.para(f.kdvTutari)),
                      _cellText(TurkceFormat.para(f.tevkifatTutari), isBold: true, color: const Color(0xFFD97706)),
                    ],
                  )),
          ],
          borderColor: const Color(0xFFFDE68A),
          gridColor: const Color(0xFFFFFBEB),
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(1.4),
          },
        ),
        const SizedBox(height: 16),

        // --- 4. MUHTASAR & DAMGA BÖLÜMÜ (YAN YANA İKİLİ ÇERÇEVE) ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol: Muhtasar Beyanname Dökümü
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSheetTitle('MUHTASAR BEYANNAME BORDRO ÖZETİ', accentColor: const Color(0xFF059669)),
                  const SizedBox(height: 6),
                  _buildTableContainer(
                    [
                      _headerRow(
                        ['MUHTASAR KALEMİ', 'TUTAR / DEĞER'],
                        bg: const Color(0xFFD1FAE5),
                        textColor: const Color(0xFF065F46),
                      ),
                      _dataRow('Toplam Hak Sahibi Kişi Sayısı', ['${m.toplamKisiSayisi} Kişi']),
                      _dataRow('Toplam Brüt Ücret', [TurkceFormat.para(m.toplamBrutUcret)]),
                      _dataRow('Aylık Gelir Vergisi Matrahları Toplamı', [TurkceFormat.para(m.toplamAylikGvMatrahi)]),
                      _dataRow('Kesilen Gelir Vergisi Toplamı', [TurkceFormat.para(m.toplamGelirVergisi)], isBold: true),
                      _dataRow('Asgari Ücret Gelir Vergisi İstisnası', [TurkceFormat.para(m.asgariUcretGvIstisnasiToplami)]),
                      _dataRow('Asgari Ücret Damga Vergisi İstisnası', [TurkceFormat.para(m.asgariUcretDvIstisnasiToplami)]),
                      _dataRow('Net Ödenen Toplamı', [TurkceFormat.para(m.toplamNetOdenen)], isBold: true),
                    ],
                    borderColor: const Color(0xFFA7F3D0),
                    gridColor: const Color(0xFFF0FDF4),
                    columnWidths: const {
                      0: FlexColumnWidth(2.6),
                      1: FlexColumnWidth(1.4),
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Sağ: Damga Vergisi & 600 Hasılat
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSheetTitle('DAMGA VERGİSİ (360.03.05) & 600 HASILAT', accentColor: const Color(0xFF7C3AED)),
                  const SizedBox(height: 6),
                  _buildTableContainer(
                    [
                      _headerRow(
                        ['VERGİ & HASILAT KALEMİ', 'TUTAR'],
                        bg: const Color(0xFFEDE9FE),
                        textColor: const Color(0xFF5B21B6),
                      ),
                      _dataRow('301 (Ödemelerden Kesilen Damga)', [TurkceFormat.para(m.muhtasarKesilenDamgaVergisi301)]),
                      _dataRow('302 (Muhtasar Ücret Damga Vergisi)', [TurkceFormat.para(m.muhtasarDamgaVergisi302)]),
                      _highlightRow('301 + 302 TOPLAM DAMGA', TurkceFormat.para(m.toplamDamgaVergisi301Ve302), const Color(0xFF059669), colSpan: 2),
                      _dataRow('360.03.05 Matrahı (Binde 9,48)', [TurkceFormat.para(provider.damgaToplamMatrah)]),
                      _dataRow('Bu Ay Toplam 600 Aylık Hasılat', [TurkceFormat.para(provider.hasiat600ToplamAylik)]),
                      _dataRow('123 Kredi Kartı Toplam Tutarı', [TurkceFormat.para(provider.krediKarti123Toplam)]),
                      _highlightRow('600 KÜMÜLATİF HASILAT', TurkceFormat.para(provider.hasiat600ToplamKumulatif), const Color(0xFF0284C7), colSpan: 2),
                    ],
                    borderColor: const Color(0xFFDDD6FE),
                    gridColor: const Color(0xFFFAF5FF),
                    columnWidths: const {
                      0: FlexColumnWidth(2.6),
                      1: FlexColumnWidth(1.4),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 2. KDV 1 MASASI (SIFIR DONMALI, ENTER/TAB DESTEKLİ EXCEL GİRİŞİ)
  // =========================================================================
  Widget _buildKdv1Masasi(BeyannameProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('Birim Bazlı KDV 1 Giriş Masası (Hesaplanan & İndirilecek KDV)', accentColor: const Color(0xFF1D4ED8)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSayfaPdfButton(context, provider, 2),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddBirimDialog(context, provider),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Yeni Birim Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildDevredenKdvBanner(provider),
        _buildTableContainer(
          [
            _headerRow(
              [
                'BİRİM ADI',
                'HESAPLANAN %10',
                'HESAPLANAN %20',
                'İNDİRİLECEK %10',
                'İNDİRİLECEK %20',
                'NET ÖDENECEK KDV',
                'İŞLEM',
              ],
              bg: const Color(0xFFF1F5F9),
              textColor: const Color(0xFF1E293B),
            ),
            ...provider.kdv1Satirlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  _buildBirimCell(s.birimAdi),
                  EditableCell(
                    value: s.hesaplananKdv10,
                    onSubmitted: (v) {
                      provider.updateKdv1Satir(
                        idx,
                        s.copyWith(
                          hesaplananKdv10: v,
                          hesaplananMatrah10: v > 0 ? BeyannameHesaplamaMotoru.round(v * 10) : 0,
                        ),
                      );
                    },
                  ),
                  EditableCell(
                    value: s.hesaplananKdv20,
                    onSubmitted: (v) {
                      provider.updateKdv1Satir(
                        idx,
                        s.copyWith(
                          hesaplananKdv20: v,
                          hesaplananMatrah20: v > 0 ? BeyannameHesaplamaMotoru.round(v * 5) : 0,
                        ),
                      );
                    },
                  ),
                  EditableCell(
                    value: s.indirilecekKdv10,
                    onSubmitted: (v) {
                      provider.updateKdv1Satir(
                        idx,
                        s.copyWith(
                          indirilecekKdv10: v,
                          indirilecekMatrah10: v > 0 ? BeyannameHesaplamaMotoru.round(v * 10) : 0,
                        ),
                      );
                    },
                  ),
                  EditableCell(
                    value: s.indirilecekKdv20,
                    onSubmitted: (v) {
                      provider.updateKdv1Satir(
                        idx,
                        s.copyWith(
                          indirilecekKdv20: v,
                          indirilecekMatrah20: v > 0 ? BeyannameHesaplamaMotoru.round(v * 5) : 0,
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      TurkceFormat.para(s.netOdenecekKdv),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: s.netOdenecekKdv >= 0 ? const Color(0xFF059669) : Colors.red,
                      ),
                    ),
                  ),
                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                      tooltip: 'Satırı Sil',
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => provider.removeKdv1Satir(idx),
                    ),
                  ),
                ],
              );
            }),
          ],
          borderColor: const Color(0xFFCBD5E1),
          gridColor: const Color(0xFFF1F5F9),
          minWidth: 920,
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.2),
            6: FixedColumnWidth(55),
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 3. KDV 2 TEVKİFAT MASASI
  // =========================================================================
  Widget _buildKdv2TevkifatMasasi(BeyannameProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('KDV 2 Tevkifatlı Fatura & Firma Masası', accentColor: const Color(0xFFD97706)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSayfaPdfButton(context, provider, 3),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddTevkifatDialog(context, provider),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Tevkifatlı Fatura Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['FİRMA / KİŞİ ADI', 'VERGİ / TC NO', 'BİRİM', 'TÜR / ORAN', 'MATRAH TUTARI', 'KDV TUTARI', 'TEVKİFAT TUTARI', 'İŞLEM'],
              bg: const Color(0xFFFEF3C7),
              textColor: const Color(0xFF92400E),
            ),
            ...provider.tevkifatKayitlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final f = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  _cellText(f.firmaAdi, isBold: true, align: TextAlign.left),
                  _cellText(f.vergiTcNo, align: TextAlign.center),
                  _buildBirimCell(f.birimAdi ?? '—'),
                  _cellText('${f.tevkifatTuru.etiket} (%${f.kdvOrani})', align: TextAlign.center),
                  _cellText(TurkceFormat.para(f.matrahTutari)),
                  _cellText(TurkceFormat.para(f.kdvTutari)),
                  _cellText(TurkceFormat.para(f.tevkifatTutari), isBold: true, color: const Color(0xFFD97706)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFD97706)),
                          splashRadius: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Düzenle',
                          onPressed: () => _showAddTevkifatDialog(
                            context,
                            provider,
                            editIndex: idx,
                            mevcut: f,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                          splashRadius: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Sil',
                          onPressed: () => provider.removeTevkifatKaydi(idx),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
          borderColor: const Color(0xFFFDE68A),
          gridColor: const Color(0xFFFFFBEB),
          minWidth: 1020,
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.1),
            6: FlexColumnWidth(1.2),
            7: FixedColumnWidth(65),
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 4. MUHTASAR MASASI
  // =========================================================================
  Widget _buildMuhtasarMasasi(BeyannameProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('Muhtasar Personel Bordro Tablosu', accentColor: const Color(0xFF059669)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSayfaPdfButton(context, provider, 4),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddMuhtasarDialog(context, provider),
                    icon: const Icon(Icons.person_add_rounded, size: 14),
                    label: const Text('Personel Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['BİRİM', 'PERSONEL AD SOYAD', 'KİŞİ', 'BRÜT ÜCRET', 'GELİR VERGİSİ', 'DAMGA VERGİSİ', 'NET ÖDENEN', 'GV MATRAHI', 'İŞLEM'],
              bg: const Color(0xFFD1FAE5),
              textColor: const Color(0xFF065F46),
            ),
            ...provider.muhtasarSatirlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  _buildBirimCell(m.birimAdi),
                  _buildPersonelAdSoyadCell(m),
                  _cellText('${m.kisiSayisi}', align: TextAlign.center),
                  _cellText(TurkceFormat.para(m.brutUcret)),
                  _cellText(TurkceFormat.para(m.gelirVergisi)),
                  _cellText(TurkceFormat.para(m.damgaVergisi)),
                  _cellText(TurkceFormat.para(m.netOdenen)),
                  _cellText(TurkceFormat.para(m.aylikGelirVergisiMatrahi)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF059669)),
                          splashRadius: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Düzenle',
                          onPressed: () => _showAddMuhtasarDialog(
                            context,
                            provider,
                            editIndex: idx,
                            mevcut: m,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                          splashRadius: 14,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Sil',
                          onPressed: () => provider.removeMuhtasarSatir(idx),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
          borderColor: const Color(0xFFA7F3D0),
          gridColor: const Color(0xFFF0FDF4),
          minWidth: 980,
          columnWidths: const {
            0: FlexColumnWidth(1.3),
            1: FlexColumnWidth(2.2),
            2: FixedColumnWidth(44),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(1.1),
            7: FlexColumnWidth(1.1),
            8: FixedColumnWidth(65),
          },
        ),
      ],
    );
  }

  Widget _buildPersonelAdSoyadCell(MuhtasarSatiri m) {
    final isim = m.temizAdSoyad;
    final unvan = (m.unvan ?? '').trim();
    final birim = m.birimAdi.trim();

    final List<String> detaylar = [];
    if (unvan.isNotEmpty) detaylar.add('👤 Ünvan: $unvan');
    if (birim.isNotEmpty) detaylar.add('🏛️ Birim: $birim');

    final tooltipMesaji = detaylar.isNotEmpty ? detaylar.join('\n') : isim;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Tooltip(
        message: tooltipMesaji,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, height: 1.4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isim,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unvan.isNotEmpty || birim.isNotEmpty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 5. DAMGA MASASI (360.03.05 BİNDE 9,48)
  // =========================================================================
  Widget _buildDamgaMasasi(BeyannameProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('360.03.05 Ödemelerden Kesilen Damga Vergisi (Binde 9,48 Ters Matrah Hesabı)', accentColor: const Color(0xFF7C3AED)),
            _buildSayfaPdfButton(context, provider, 5),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['BİRİM ADI', 'MİZAN DAMGA VERGİSİ TUTARI (TL)', 'HESAPLANAN MATRAH (DAMGA * 1000 / 9,48)'],
              bg: const Color(0xFFEDE9FE),
              textColor: const Color(0xFF5B21B6),
            ),
            ...provider.damgaSatirlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  _buildBirimCell(d.birimAdi),
                  EditableCell(
                    value: d.damgaVergisi,
                    onSubmitted: (v) => provider.updateDamgaSatir(idx, v),
                  ),
                  _cellText(TurkceFormat.para(d.matrah), isBold: true, color: const Color(0xFF7C3AED)),
                ],
              );
            }),
            _highlightRow('TOPLAM DAMGA MATRAHI', TurkceFormat.para(provider.damgaToplamMatrah), const Color(0xFF7C3AED), colSpan: 3),
          ],
          borderColor: const Color(0xFFDDD6FE),
          gridColor: const Color(0xFFFAF5FF),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.5),
          },
        ),
      ],
    );
  }

  // --- Devreden KDV Şeridi ---
  Widget _buildDevredenKdvBanner(BeyannameProvider provider) {
    final k1 = provider.kdv1Sonuc;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          const Text(
            'Önceki Aydan Devreden KDV:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: EditableCell(
              value: provider.oncekiAydanDevredenKdv,
              onSubmitted: (v) => provider.setOncekiAydanDevredenKdv(v),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Toplam İndirim & Devir: ${TurkceFormat.para(k1.toplamIndirilecekKdv + provider.oncekiAydanDevredenKdv)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const Spacer(),
          if (k1.sonrakiDonemeDevredenKdv > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Text(
                'Sonraki Döneme Devreden KDV: ${TurkceFormat.para(k1.sonrakiDonemeDevredenKdv)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Text(
                'Net Ödenecek KDV: ${TurkceFormat.para(k1.odenecekKdv1)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. 600 MASASI (ÖNCEKİ AYLAR + BU AY = KÜMÜLATİF DENGESİ)
  // =========================================================================
  Widget _build600Masasi(BeyannameProvider provider) {
    final prevMonthName = provider.seciliAy > 1 ? _aylar[provider.seciliAy - 2] : '';
    final labelPrev = provider.seciliAy > 1
        ? 'ÖNCEKİ DÖNEMLER (Ocak - $prevMonthName)'
        : 'ÖNCEKİ DÖNEMLER (Yok)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('600 Hasılat & 123 Kredi Kartı (Geçmiş Aylar Kümülatif Takibi)', accentColor: const Color(0xFF0284C7)),
            Row(
              children: [
                _buildSayfaPdfButton(context, provider, 6),
                const SizedBox(width: 8),
                if (provider.seciliAy > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ozet = await provider.gecmisAylariSenkronizeEt();
                          if (context.mounted) {
                            if (ozet.bosMu) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bu yıl için sisteme kaydedilmiş önceki ay kaydı bulunamadı.'),
                                  backgroundColor: Color(0xFFD97706),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } else {
                              final aylarStr = ozet.bulunanAylar.map((a) => _aylar[a - 1]).join(', ');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ ${provider.seciliYil} yılı ($aylarStr) aylarından toplam ${TurkceFormat.para(ozet.toplamHasilat)} hasılat birimlere aktarıldı (Mizan mutabakatı sağlandı).'),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.sync_rounded, size: 14),
                        label: const Text('Geçmiş Aylardan Çek (Mizan)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Kümülatif = Önceki Aylar + Cari Ay',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              [
                'BİRİM ADI',
                labelPrev,
                'BU AY AYLIK HASILAT',
                'YILLIK KÜMÜLATİF HASILAT',
                '123 KREDİ KARTI',
              ],
              bg: const Color(0xFFE0F2FE),
              textColor: const Color(0xFF0369A1),
            ),
            ...provider.hasiat600Satirlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final h = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  _buildBirimCell(h.birimAdi),
                  EditableCell(
                    value: h.oncekiAylarHasilat600,
                    textColor: const Color(0xFF475569),
                    onSubmitted: (v) => provider.updateHasiatSatir(idx, oncekiAylar: v),
                  ),
                  EditableCell(
                    value: h.aylikHasilat600,
                    onSubmitted: (v) => provider.updateHasiatSatir(idx, aylik: v),
                  ),
                  EditableCell(
                    value: h.kumulatifHasilat600,
                    isBold: true,
                    textColor: const Color(0xFF0284C7),
                    onSubmitted: (v) => provider.updateHasiatSatir(idx, kumulatif: v),
                  ),
                  EditableCell(
                    value: h.krediKarti123,
                    onSubmitted: (v) => provider.updateHasiatSatir(idx, krediKarti: v),
                  ),
                ],
              );
            }),
            // Genel Toplam Satırı
            _dataRow(
              'GENEL TOPLAMLAR',
              [
                TurkceFormat.para(provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.oncekiAylarHasilat600)),
                TurkceFormat.para(provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.aylikHasilat600)),
                TurkceFormat.para(provider.hasiat600ToplamKumulatif),
                TurkceFormat.para(provider.krediKarti123Toplam),
              ],
              isBold: true,
              bg: const Color(0xFFF1F5F9),
            ),
          ],
          borderColor: const Color(0xFFBAE6FD),
          gridColor: const Color(0xFFF0F9FF),
          minWidth: 920,
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.3),
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '💡 Mizan Güvencesi: \'Önceki Dönemler\' tutarları, ${provider.seciliYil} yılının sisteme kaydedilmiş önceki aylarından birim bazında otomatik toplanır. \'Bu Ay Aylık Hasılat\'ı girdiğinizde oluşan Kümülatif tutarı doğrudan Kümülatif Mizan 600 bakiyenizle karşılaştırıp mutabakat sağlayabilirsiniz.',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. BİRİM BAZLI VERGİLER (EXCEL 'Birim Bazlı Vergiler' SAYFASININ BİREBİR AYNISI)
  // =========================================================================
  Widget _buildBirimIcmal(BeyannameProvider provider) {
    final list = provider.birimIcmalListesi;

    // Tablo 1 Toplamları
    final topKdv1 = list.fold(0.0, (s, x) => s + x.kdv1Tutari);
    final topDamgaVb = list.fold(0.0, (s, x) => s + x.damgaVb);
    final topMuhtasarGelir = list.fold(0.0, (s, x) => s + x.muhtasarGelir);
    final topMuhtasarDamga = list.fold(0.0, (s, x) => s + x.muhtasarDamga);
    final topMuhtasarKesilen = list.fold(0.0, (s, x) => s + x.muhtasarKesilenDamga);
    final topMuhtasarToplam = list.fold(0.0, (s, x) => s + x.muhtasarToplam);

    // Tablo 2 Toplamları (KDV 2)
    final topKdv2Dokuz = list.fold(0.0, (s, x) => s + x.kdv2DokuzBoluOn);
    final topKdv2Yedi = list.fold(0.0, (s, x) => s + x.kdv2YediBoluOn);
    final topKdv2Bes = list.fold(0.0, (s, x) => s + x.kdv2BesBoluOn);
    final topKdv2Genel = list.fold(0.0, (s, x) => s + x.kdv2Toplam);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==================== 1. TABLO: BİRİM BAZLI VERGİLER (KDV 1, DAMGA, MUHTASAR) ====================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSheetTitle('Birim Bazlı Vergiler (KDV 1, Damga Vergisi, Muhtasar)', accentColor: const Color(0xFF15803D)),
            _buildSayfaPdfButton(context, provider, 1),
          ],
        ),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              [
                'BİRİMLER',
                'KDV 1',
                'DAMGA V.B.',
                'MUHTASAR GELİR',
                'MUHTASAR DAMGA',
                'MUHTASAR ÖDEMELERİNDE KESİLEN DAMGA',
                'MUHTASAR TOPLAM ÖDENECEK',
              ],
              bg: const Color(0xFFDCFCE7), // Excel fıstık yeşili başlık
              textColor: const Color(0xFF14532D),
            ),
            ...list.map((b) {
              final isTomer = BirimAdlandirma.canonicalKey(b.birimAdi) == 'tomer';
              final bgRow = isTomer
                  ? const Color(0xFFFEF08A).withValues(alpha: 0.3)
                  : Colors.white;

              return TableRow(
                decoration: BoxDecoration(color: bgRow),
                children: [
                  _buildBirimCell(b.birimAdi),
                  _cellText(
                    b.kdv1Tutari < 0 ? '(-) ${TurkceFormat.para(b.kdv1Tutari.abs())}' : TurkceFormat.para(b.kdv1Tutari),
                    color: b.kdv1Tutari < 0 ? const Color(0xFFDC2626) : null,
                  ),
                  _cellText(TurkceFormat.para(b.damgaVb)),
                  _cellText(TurkceFormat.para(b.muhtasarGelir)),
                  _cellText(TurkceFormat.para(b.muhtasarDamga)),
                  _cellText(TurkceFormat.para(b.muhtasarKesilenDamga)),
                  _cellText(
                    TurkceFormat.para(b.muhtasarToplam),
                    isBold: true,
                    color: const Color(0xFF15803D),
                  ),
                ],
              );
            }),
            // Diş Sözleşme & Karar Pulu Ek Satırları (Excel yapısı)
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
              children: [
                _buildBirimCell('DİŞ SÖZLEŞMEYE DAİR'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00', isBold: true),
              ],
            ),
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
              children: [
                _buildBirimCell('DİŞ DAMGA-KARAR PULU'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00'),
                _cellText('₺0,00', isBold: true),
              ],
            ),
            // Tablo 1 Toplam Satırı
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7)),
              children: [
                _cellText('TOPLAMLAR', isBold: true, align: TextAlign.left, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topKdv1), isBold: true, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topDamgaVb), isBold: true, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topMuhtasarGelir), isBold: true, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topMuhtasarDamga), isBold: true, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topMuhtasarKesilen), isBold: true, color: const Color(0xFF14532D)),
                _cellText(TurkceFormat.para(topMuhtasarToplam), isBold: true, color: const Color(0xFF15803D)),
              ],
            ),
          ],
          borderColor: const Color(0xFF86EFAC),
          gridColor: const Color(0xFFBBF7D0),
          minWidth: 920,
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.2),
            5: FlexColumnWidth(1.6),
            6: FlexColumnWidth(1.4),
          },
        ),
        const SizedBox(height: 24),

        // ==================== 2. TABLO: KDV 2 TEVKİFAT (9/10, 7/10, 5/10) ====================
        _buildSheetTitle('KDV 2 Tevkifat Birim Dağılımı (9/10, 7/10, 5/10 Oranları)', accentColor: const Color(0xFFD97706)),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              [
                'BİRİMLER',
                '9 / 10 (%90)',
                '7 / 10 (%70)',
                '5 / 10 (%50)',
                'TOPLAM KDV 2',
              ],
              bg: const Color(0xFFFEF3C7),
              textColor: const Color(0xFF92400E),
            ),
            ...list.map((b) {
              final isDis = BirimAdlandirma.canonicalKey(b.birimAdi) == 'dis';
              return TableRow(
                decoration: BoxDecoration(
                  color: isDis ? const Color(0xFFFEF08A).withValues(alpha: 0.3) : Colors.white,
                ),
                children: [
                  _buildBirimCell(b.birimAdi),
                  _cellText(TurkceFormat.para(b.kdv2DokuzBoluOn)),
                  _cellText(TurkceFormat.para(b.kdv2YediBoluOn)),
                  _cellText(TurkceFormat.para(b.kdv2BesBoluOn)),
                  _cellText(TurkceFormat.para(b.kdv2Toplam), isBold: true, color: const Color(0xFFD97706)),
                ],
              );
            }),
            // KDV 2 Toplam Satırı
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7)),
              children: [
                _cellText('TOPLAM KDV 2 ÖDENECEK TEVKİFAT', isBold: true, align: TextAlign.left, color: const Color(0xFF92400E)),
                _cellText(TurkceFormat.para(topKdv2Dokuz), isBold: true, color: const Color(0xFF92400E)),
                _cellText(TurkceFormat.para(topKdv2Yedi), isBold: true, color: const Color(0xFF92400E)),
                _cellText(TurkceFormat.para(topKdv2Bes), isBold: true, color: const Color(0xFF92400E)),
                _cellText(TurkceFormat.para(topKdv2Genel), isBold: true, color: const Color(0xFFB45309)),
              ],
            ),
          ],
          borderColor: const Color(0xFFFDE68A),
          gridColor: const Color(0xFFFEF3C7),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.5),
          },
        ),
      ],
    );
  }

  // ==================== TABLO VE STİL YARDIMCILARI ====================

  Widget _buildSheetTitle(String title, {Color accentColor = const Color(0xFF0284C7)}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: accentColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSayfaPdfButton(BuildContext context, BeyannameProvider provider, int tabIndex) {
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: () => BeyannameRaporServisi.sayfaRaporuYazdir(context, provider, tabIndex),
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
        label: const Text('PDF İndir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F766E),
          side: const BorderSide(color: Color(0xFF0F766E), width: 1),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildTableContainer(
    List<TableRow> rows, {
    Color borderColor = const Color(0xFFBAE6FD),
    Color gridColor = const Color(0xFFE0F2FE),
    Map<int, TableColumnWidth>? columnWidths,
    double minWidth = 850,
  }) {
    final table = Table(
      columnWidths: columnWidths,
      border: TableBorder.all(color: gridColor, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < minWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minWidth,
                child: table,
              ),
            );
          }
          return table;
        },
      ),
    );
  }

  TableRow _headerRow(List<String> titles, {Color? bg, Color? textColor, List<TextAlign>? alignments}) {
    return TableRow(
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFE0F2FE),
      ),
      children: titles.asMap().entries.map((entry) {
        final i = entry.key;
        final t = entry.value;
        final align = (alignments != null && i < alignments.length)
            ? alignments[i]
            : (i == 0 ? TextAlign.left : TextAlign.right);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            t,
            textAlign: align,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: textColor ?? const Color(0xFF0369A1),
              letterSpacing: 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }

  TableRow _dataRow(String label, List<String> values, {bool isBold = false, Color? bg, List<TextAlign>? alignments}) {
    return TableRow(
      decoration: bg != null ? BoxDecoration(color: bg) : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
        ),
        ...values.asMap().entries.map((entry) {
          final i = entry.key;
          final v = entry.value;
          final align = (alignments != null && i < alignments.length)
              ? alignments[i]
              : (v.contains('%') || v.contains('/') ? TextAlign.center : TextAlign.right);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              v,
              textAlign: align,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF0F172A),
              ),
            ),
          );
        }),
      ],
    );
  }

  TableRow _dividerRow(String title, int colSpan, {Color? bg, Color? textColor}) {
    return TableRow(
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFBAE6FD),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            title,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textColor ?? const Color(0xFF0369A1)),
          ),
        ),
        ...List.generate(colSpan - 1, (_) => const SizedBox.shrink()),
      ],
    );
  }

  TableRow _highlightRow(String title, String value, Color color, {required int colSpan}) {
    final List<Widget> cells = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          title,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    ];
    for (int i = 0; i < colSpan - 2; i++) {
      cells.add(const SizedBox.shrink());
    }
    cells.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
        ),
      ),
    );
    return TableRow(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08)),
      children: cells,
    );
  }

  TableRow _singleCellRow(String text, int colSpan) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ),
        ...List.generate(colSpan - 1, (_) => const SizedBox.shrink()),
      ],
    );
  }

  Widget _cellText(String text, {bool isBold = false, TextAlign align = TextAlign.right, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildBirimCell(String birimAdi) {
    final kisa = BirimAdlandirma.kisaAdGetir(birimAdi);
    final tam = BirimAdlandirma.tamAdGetir(birimAdi);
    final hasDifference = kisa.trim() != tam.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              kisa,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasDifference) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tam,
              child: const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }



  // ==================== DİYALOGLAR (EKLEME İŞLEMLERİ) ====================

  void _showAddBirimDialog(BuildContext context, BeyannameProvider provider) {
    // 1. Sistem birimlerini topla
    final Map<String, String> sistemSecenekleri = {};
    for (final b in BirimModel.varsayilanBirimler) {
      sistemSecenekleri[b.ad] = b.kisaAd;
    }
    for (final b in provider.sistemBirimleri) {
      if (b.ad.isNotEmpty) {
        sistemSecenekleri[b.ad] = b.kisaAd.isNotEmpty ? b.kisaAd : b.ad;
      }
    }

    // 2. Halihazırda tabloda olan birimleri tespit et
    final Set<String> mevcutKanonik = provider.kdv1Satirlari
        .map((s) => BirimAdlandirma.canonicalKey(s.birimAdi))
        .toSet();

    // 3. Tabloda henüz olmayan sistem birimleri listesi
    final List<String> eklenebilirSistemBirimleri = sistemSecenekleri.keys.where((ad) {
      final key = BirimAdlandirma.canonicalKey(ad);
      return !mevcutKanonik.contains(key);
    }).toList()..sort();

    // Özel manuel giriş modu kontrolü
    const String digerOzelBirim = '__DIGER_OZEL__';
    String? seciliBirim = eklenebilirSistemBirimleri.isNotEmpty ? eklenebilirSistemBirimleri.first : digerOzelBirim;
    final manuelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 8),
              Text('Yeni Birim Ekle (Sistemden Seç)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistemde tanımlı üniversite birimlerinden seçebilir veya yeni bir özel birim girebilirsiniz:',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: seciliBirim,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sistem Birimi Seçimi',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                  ),
                  items: [
                    ...eklenebilirSistemBirimleri.map((ad) {
                      final kisa = sistemSecenekleri[ad] ?? BirimAdlandirma.kisaAdGetir(ad);
                      return DropdownMenuItem<String>(
                        value: ad,
                        child: Text(
                          '$kisa — $ad',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    const DropdownMenuItem<String>(
                      value: digerOzelBirim,
                      child: Text(
                        '➕ Diğer / Yeni Özel Birim Yaz...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => seciliBirim = val);
                    }
                  },
                ),
                if (seciliBirim == digerOzelBirim) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: manuelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Yeni Birim Adı veya Kısaltması',
                      hintText: 'örn: Yabancı Diller Yüksekokulu...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    autofocus: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                String hedefBirim = '';
                if (seciliBirim == digerOzelBirim) {
                  hedefBirim = manuelCtrl.text.trim();
                } else if (seciliBirim != null) {
                  hedefBirim = seciliBirim!;
                }

                if (hedefBirim.isNotEmpty) {
                  final std = BirimAdlandirma.tamAdGetir(hedefBirim);
                  provider.addKdv1Birim(std);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Masaya Ekle'),
            ),
          ],
        ),
      ),
    );
  }


  void _showAddTevkifatDialog(
    BuildContext context,
    BeyannameProvider provider, {
    int? editIndex,
    TevkifatFirmaKaydi? mevcut,
  }) {
    final firmaCtrl = TextEditingController(text: mevcut?.firmaAdi ?? '');
    final vknCtrl = TextEditingController(text: mevcut?.vergiTcNo ?? '');
    final matrahCtrl = TextEditingController(
      text: mevcut != null && mevcut.matrahTutari > 0
          ? TurkceFormat.paraKalem(mevcut.matrahTutari)
          : '',
    );
    final kdvCtrl = TextEditingController(
      text: mevcut != null && mevcut.kdvTutari > 0
          ? TurkceFormat.paraKalem(mevcut.kdvTutari)
          : '',
    );
    TevkifatTuru seciliTur = mevcut?.tevkifatTuru ?? TevkifatTuru.dokuzBoluOn;
    int kdvOrani = mevcut?.kdvOrani ?? 20;

    // Birim seçeneklerini topla
    final Map<String, String> birimSecenekleri = {};
    for (final b in BirimModel.varsayilanBirimler) {
      birimSecenekleri[b.ad] = b.kisaAd.isNotEmpty ? b.kisaAd : b.ad;
    }
    for (final b in provider.sistemBirimleri) {
      if (b.ad.isNotEmpty) {
        birimSecenekleri[b.ad] = b.kisaAd.isNotEmpty ? b.kisaAd : b.ad;
      }
    }
    for (final k in provider.kdv1Satirlari) {
      if (k.birimAdi.isNotEmpty && !birimSecenekleri.containsKey(k.birimAdi)) {
        birimSecenekleri[k.birimAdi] = BirimAdlandirma.kisaAdGetir(k.birimAdi);
      }
    }
    final sortedBirimler = birimSecenekleri.keys.toList()..sort();

    String? seciliBirim = mevcut?.birimAdi;
    if (seciliBirim == null || !birimSecenekleri.containsKey(seciliBirim)) {
      if (sortedBirimler.isNotEmpty) {
        seciliBirim = sortedBirimler.first;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                mevcut != null ? 'Tevkifatlı Faturayı Düzenle' : 'Yeni Tevkifatlı Fatura Ekle',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Birim Seçimi (Birim Bazlı Vergiler icmali için zorunlu)
                  DropdownButtonFormField<String>(
                    value: seciliBirim,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ait Olduğu Birim (Birim Dağılımı İçin)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.account_balance_rounded, size: 18),
                    ),
                    items: sortedBirimler.map((ad) {
                      final kisa = birimSecenekleri[ad] ?? ad;
                      return DropdownMenuItem<String>(
                        value: ad,
                        child: Text(
                          '$kisa — $ad',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => seciliBirim = v),
                  ),
                  const SizedBox(height: 12),

                  // 2. Firma Adı + Rehberden Seç Butonu
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firmaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Firma / Kişi Adı',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            prefixIcon: const Icon(Icons.business_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded, color: Color(0xFFD97706)),
                              tooltip: 'Firma Veritabanından Seç',
                              onPressed: () async {
                                final secilen = await showDialog<FirmaModel>(
                                  context: context,
                                  builder: (c) => const FirmaSeciciDialog(),
                                );
                                if (secilen != null) {
                                  firmaCtrl.text = secilen.firmaAdi;
                                  vknCtrl.text = secilen.vergiNo;
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.corporate_fare_rounded, size: 16),
                          label: const Text('Rehberden Seç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final secilen = await showDialog<FirmaModel>(
                              context: context,
                              builder: (c) => const FirmaSeciciDialog(),
                            );
                            if (secilen != null) {
                              firmaCtrl.text = secilen.firmaAdi;
                              vknCtrl.text = secilen.vergiNo;
                              setDialogState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. Vergi No / TC Kimlik
                  TextField(
                    controller: vknCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Vergi No / TC Kimlik',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.badge_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Tevkifat Türü ve KDV Oranı
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TevkifatTuru>(
                          value: seciliTur,
                          decoration: const InputDecoration(
                            labelText: 'Tevkifat Türü',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: TevkifatTuru.dokuzBoluOn, child: Text('9 / 10 (%90)')),
                            DropdownMenuItem(value: TevkifatTuru.yediBoluOn, child: Text('7 / 10 (%70)')),
                            DropdownMenuItem(value: TevkifatTuru.besBoluOn, child: Text('5 / 10 (%50)')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => seciliTur = v);
                              final m = TurkceFormat.parseSayi(matrahCtrl.text);
                              if (m > 0) {
                                final kdv = BeyannameHesaplamaMotoru.round(m * (kdvOrani / 100));
                                kdvCtrl.text = TurkceFormat.paraKalem(kdv);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: kdvOrani,
                          decoration: const InputDecoration(
                            labelText: 'KDV Oranı',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: [8, 10, 18, 20].map((o) => DropdownMenuItem(value: o, child: Text('%$o'))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => kdvOrani = v);
                              final m = TurkceFormat.parseSayi(matrahCtrl.text);
                              if (m > 0) {
                                final kdv = BeyannameHesaplamaMotoru.round(m * (kdvOrani / 100));
                                kdvCtrl.text = TurkceFormat.paraKalem(kdv);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Matrah ve KDV Tutarları
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: matrahCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matrah Tutarı (TL)',
                            hintText: 'örn: 100.000,00',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: const [TurkceParaInputFormatter()],
                          onChanged: (val) {
                            final m = TurkceFormat.parseSayi(val);
                            if (m > 0) {
                              final kdv = BeyannameHesaplamaMotoru.round(m * (kdvOrani / 100));
                              kdvCtrl.text = TurkceFormat.paraKalem(kdv);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: kdvCtrl,
                          decoration: const InputDecoration(
                            labelText: 'KDV Tutarı (TL)',
                            hintText: 'örn: 20.000,00',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: const [TurkceParaInputFormatter()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                final matrah = TurkceFormat.parseSayi(matrahCtrl.text);
                final kdv = TurkceFormat.parseSayi(kdvCtrl.text);
                final tevkifat = BeyannameHesaplamaMotoru.round(kdv * seciliTur.oran);

                final kayit = TevkifatFirmaKaydi(
                  id: mevcut?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  firmaAdi: firmaCtrl.text.trim().isEmpty ? 'Tevkifatlı Fatura' : firmaCtrl.text.trim(),
                  vergiTcNo: vknCtrl.text.trim(),
                  tevkifatTuru: seciliTur,
                  tevkifatEtiketi: seciliTur.etiket,
                  kdvOrani: kdvOrani,
                  matrahTutari: matrah,
                  kdvTutari: kdv,
                  tevkifatTutari: tevkifat,
                  birimAdi: seciliBirim,
                );

                if (editIndex != null) {
                  provider.updateTevkifatKaydi(editIndex, kayit);
                } else {
                  provider.addTevkifatKaydi(kayit);
                }
                Navigator.pop(ctx);
              },
              child: Text(mevcut != null ? 'Güncelle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMuhtasarDialog(
    BuildContext context,
    BeyannameProvider provider, {
    int? editIndex,
    MuhtasarSatiri? mevcut,
  }) async {
    // 1.219 üniversite personelini hafızadan getir (sıfır gecikme)
    final tumPersoneller = await PersonelService().getAll();

    // Mevcut birim listesinden seçenekleri oluştur (varsayılan birimler + KDV 1 satırlarındaki birimler)
    final Set<String> mevcutBirimler = {};
    for (final b in BirimModel.varsayilanBirimler) {
      mevcutBirimler.add(b.ad);
    }
    for (final s in provider.kdv1Satirlari) {
      if (s.birimAdi.isNotEmpty) mevcutBirimler.add(s.birimAdi);
    }
    if (mevcut != null && mevcut.birimAdi.isNotEmpty) {
      mevcutBirimler.add(mevcut.birimAdi);
    }
    final birimListesi = mevcutBirimler.toList()..sort();

    String seciliBirim = mevcut != null && mevcut.birimAdi.isNotEmpty
        ? (birimListesi.contains(mevcut.birimAdi)
            ? mevcut.birimAdi
            : (birimListesi.firstWhere(
                (b) => BirimAdlandirma.canonicalKey(b) == BirimAdlandirma.canonicalKey(mevcut.birimAdi),
                orElse: () => birimListesi.first,
              )))
        : birimListesi.firstWhere(
            (b) => BirimAdlandirma.canonicalKey(b) == 'dts',
            orElse: () => birimListesi.isNotEmpty ? birimListesi.first : 'DTS',
          );

    final adCtrl = TextEditingController(text: mevcut?.temizAdSoyad ?? '');
    String? seciliUnvan = mevcut?.unvan;
    List<PersonelModel> oneriListesi = [];
    bool aramaYapildi = false;

    final brutCtrl = TextEditingController(
      text: mevcut != null && mevcut.brutUcret > 0
          ? TurkceFormat.paraKalem(mevcut.brutUcret)
          : '',
    );
    final gvCtrl = TextEditingController(
      text: mevcut != null && mevcut.gelirVergisi > 0
          ? TurkceFormat.paraKalem(mevcut.gelirVergisi)
          : '',
    );
    final dvCtrl = TextEditingController(
      text: mevcut != null && mevcut.damgaVergisi > 0
          ? TurkceFormat.paraKalem(mevcut.damgaVergisi)
          : '',
    );
    final matrahCtrl = TextEditingController(
      text: mevcut != null && mevcut.aylikGelirVergisiMatrahi > 0
          ? TurkceFormat.paraKalem(mevcut.aylikGelirVergisiMatrahi)
          : '',
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.badge_rounded, color: Color(0xFF059669), size: 20),
              const SizedBox(width: 8),
              Text(
                mevcut != null ? 'Muhtasar Personel Satırı Düzenle' : 'Muhtasar Personel Satırı Ekle',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: seciliBirim,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Birim Seçimi',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.apartment_rounded, size: 18),
                    ),
                    items: birimListesi.map((b) {
                      final kisa = BirimAdlandirma.kisaAdGetir(b);
                      return DropdownMenuItem(
                        value: b,
                        child: Text(
                          '$kisa - $b',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => seciliBirim = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  // AKILLI PERSONEL ARAMA VE TAMAMLAMA METİN KUTUSU
                  TextField(
                    controller: adCtrl,
                    decoration: InputDecoration(
                      labelText: 'Personel Ad Soyad (Üniversite Rehberi)',
                      hintText: 'Ad, unvan veya birim yazarak arayın...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF059669)),
                      suffixIcon: adCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              splashRadius: 14,
                              onPressed: () {
                                adCtrl.clear();
                                setDialogState(() {
                                  oneriListesi = [];
                                  aramaYapildi = false;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      final q = PersonelService.normalizeMetin(val);
                      setDialogState(() {
                        if (q.length < 2) {
                          oneriListesi = [];
                          aramaYapildi = false;
                        } else {
                          oneriListesi = tumPersoneller.where((p) {
                            final ad = PersonelService.normalizeMetin(p.adSoyad);
                            final unvan = PersonelService.normalizeMetin(p.unvan);
                            final birim = PersonelService.normalizeMetin(p.birimAdi ?? '');
                            return ad.contains(q) || unvan.contains(q) || birim.contains(q);
                          }).take(8).toList();
                          aramaYapildi = true;
                        }
                      });
                    },
                  ),
                  // DİNAMİK CANLI ÖNERİ LİSTESİ (Sıfır gecikme, overlay hatası yok)
                  if (aramaYapildi && oneriListesi.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF059669), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: oneriListesi.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          itemBuilder: (ctx, idx) {
                            final p = oneriListesi[idx];
                            final isAkademik = p.personelTuru == 'Akademik';
                            return ListTile(
                              dense: true,
                              tileColor: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                              leading: CircleAvatar(
                                radius: 13,
                                backgroundColor: isAkademik
                                    ? const Color(0xFF1E40AF).withValues(alpha: 0.12)
                                    : const Color(0xFF059669).withValues(alpha: 0.12),
                                child: Icon(
                                  isAkademik ? Icons.school_rounded : Icons.badge_rounded,
                                  size: 13,
                                  color: isAkademik ? const Color(0xFF1E40AF) : const Color(0xFF059669),
                                ),
                              ),
                              title: Text(
                                p.adSoyad,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                [
                                  if (p.unvan.isNotEmpty) p.unvan,
                                  if (p.birimAdi != null && p.birimAdi!.isNotEmpty) p.birimAdi!,
                                  if (p.telefon != null && p.telefon!.isNotEmpty) 'Dahili: ${p.telefon}',
                                ].join(' • '),
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                adCtrl.text = p.adSoyad.trim();
                                seciliUnvan = p.unvan.isNotEmpty ? p.unvan : null;
                                if (p.birimAdi != null && p.birimAdi!.trim().isNotEmpty) {
                                  final pBirim = p.birimAdi!.trim();
                                  final match = birimListesi.firstWhere(
                                    (b) => BirimAdlandirma.canonicalKey(b) == BirimAdlandirma.canonicalKey(pBirim) ||
                                           b.toLowerCase() == pBirim.toLowerCase(),
                                    orElse: () => '',
                                  );
                                  if (match.isNotEmpty) {
                                    seciliBirim = match;
                                  } else {
                                    if (!birimListesi.contains(pBirim)) {
                                      birimListesi.add(pBirim);
                                      birimListesi.sort();
                                    }
                                    seciliBirim = pBirim;
                                  }
                                }
                                setDialogState(() {
                                  oneriListesi = [];
                                  aramaYapildi = false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ] else if (aramaYapildi && oneriListesi.isEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rehberde kayıt bulunamadı. Dilerseniz bu ismi elle yazıp doğrudan ekleyebilirsiniz.',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: brutCtrl,
                    decoration: const InputDecoration(labelText: 'Brüt Ücret (TL)', hintText: 'örn: 25.000,00'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [TurkceParaInputFormatter()],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: gvCtrl,
                    decoration: const InputDecoration(labelText: 'Gelir Vergisi (TL)', hintText: 'örn: 4.420,93'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [TurkceParaInputFormatter()],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dvCtrl,
                    decoration: const InputDecoration(labelText: 'Damga Vergisi (TL)', hintText: 'örn: 189,75'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [TurkceParaInputFormatter()],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: matrahCtrl,
                    decoration: const InputDecoration(labelText: 'Aylık GV Matrahı (TL)', hintText: 'örn: 21.250,00'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [TurkceParaInputFormatter()],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final brut = TurkceFormat.parseSayi(brutCtrl.text);
                final gv = TurkceFormat.parseSayi(gvCtrl.text);
                final dv = TurkceFormat.parseSayi(dvCtrl.text);
                final matrah = TurkceFormat.parseSayi(matrahCtrl.text);
                final net = BeyannameHesaplamaMotoru.round(brut - gv - dv);
                final adSoyad = adCtrl.text.trim();

                final satir = MuhtasarSatiri(
                  id: mevcut?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  birimAdi: BirimAdlandirma.tamAdGetir(seciliBirim),
                  adSoyad: adSoyad,
                  unvan: seciliUnvan,
                  kisiSayisi: mevcut?.kisiSayisi ?? 1,
                  brutUcret: brut,
                  gelirVergisi: gv,
                  damgaVergisi: dv,
                  netOdenen: net,
                  aylikGelirVergisiMatrahi: matrah,
                );

                if (editIndex != null) {
                  provider.updateMuhtasarSatir(editIndex, satir);
                } else {
                  provider.addMuhtasarSatir(satir);
                }

                // Merkezi Personel Veritabanına da otomatik kazandır (arka planda)
                if (adSoyad.isNotEmpty) {
                  PersonelService().getOrAdd(adSoyad: adSoyad, birimAdi: seciliBirim).catchError((_) => null);
                }

                Navigator.pop(ctx);
              },
              child: Text(mevcut != null ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
