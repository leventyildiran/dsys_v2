import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../providers/beyanname_provider.dart';
import '../models/beyanname_model.dart';
import '../services/beyanname_hesaplama_motoru.dart';
import '../widgets/editable_cell.dart';
import '../../birim/models/birim_model.dart';

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
    '📑 KDV 1 Masası',
    '✂️ KDV 2 Tevkifat',
    '👥 Muhtasar Bordro',
    '🏷️ Damga (360.03.05)',
    '📈 600 Hasılat & 123',
    '🏢 Birim İcmali',
  ];

  final List<Color> _tabColors = const [
    Color(0xFF1E40AF), // 0. Ana Sayfa (Mavi / Kurumsal)
    Color(0xFF2563EB), // 1. KDV 1 (Kraliyet Mavisi)
    Color(0xFFD97706), // 2. KDV 2 (Sıcak Kehribar)
    Color(0xFF059669), // 3. Muhtasar (Zümrüt Yeşili)
    Color(0xFF7C3AED), // 4. Damga (Asil Mor)
    Color(0xFF0284C7), // 5. 600 Hasılat (Camgöbeği)
    Color(0xFF475569), // 6. Birim İcmali (Arduvaz)
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
                _buildAssistantGuideStrip(provider),
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

  // ==================== APP BAR / EXCEL TOOLBAR ====================
  PreferredSizeWidget _buildExcelHeader(BuildContext context, BeyannameProvider provider) {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF107C41), // Excel yeşili
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
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
          const SizedBox(width: 12),
          // Yıl Seçici
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.seciliYil,
                items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (y) => provider.donemDegistir(y!, provider.seciliAy),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Ay Seçici
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.seciliAy,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_aylar[i]))),
                onChanged: (m) => provider.donemDegistir(provider.seciliYil, m!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Örnek Veri Yükle Butonu
        SizedBox(
          height: 30,
          child: OutlinedButton.icon(
            onPressed: () {
              provider.ornekEylulVerisiniYukle();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Eylül 2025 Excel verileri masaya yüklendi.'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFF107C41),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 14),
            label: const Text('Örnek Veri (Eylül 2025)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF107C41),
              side: const BorderSide(color: Color(0xFF107C41)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Kaydet Butonu
        SizedBox(
          height: 30,
          child: ElevatedButton.icon(
            onPressed: () async {
              final ok = await provider.kaydet();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Beyanname başarıyla kaydedildi.' : 'Kayıt sırasında hata oluştu!'),
                    backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_rounded, size: 14),
            label: const Text('Kaydet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
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

  Widget _buildAssistantGuideStrip(BeyannameProvider provider) {
    int totalCells = 0;
    int filledCells = 0;

    for (final s in provider.kdv1Satirlari) {
      totalCells += 4;
      if (s.hesaplananKdv10 > 0) filledCells++;
      if (s.hesaplananKdv20 > 0) filledCells++;
      if (s.indirilecekKdv10 > 0) filledCells++;
      if (s.indirilecekKdv20 > 0) filledCells++;
    }
    for (final d in provider.damgaSatirlari) {
      totalCells++;
      if (d.damgaVergisi > 0) filledCells++;
    }
    for (final h in provider.hasiat600Satirlari) {
      totalCells += 3;
      if (h.kumulatifHasilat600 > 0) filledCells++;
      if (h.aylikHasilat600 > 0) filledCells++;
      if (h.krediKarti123 > 0) filledCells++;
    }

    final int emptyCells = totalCells - filledCells;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                const SizedBox(width: 4),
                Text(
                  'Girilen: $filledCells hücre',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_outlined, size: 12, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text(
                  'Boş / Bekleyen: $emptyCells hücre',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.keyboard_outlined, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          const Text(
            'Hücreye tıklayıp sayıyı yazın; Enter veya Tab ile bir sonraki hücreye seri geçiş yapabilirsiniz.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
          const Spacer(),
          const Text(
            '🟢 Dolu  🟡 Bekliyor  🔵 Aktif',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ],
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
        return _buildKdv1Masasi(provider);
      case 2:
        return _buildKdv2TevkifatMasasi(provider);
      case 3:
        return _buildMuhtasarMasasi(provider);
      case 4:
        return _buildDamgaMasasi(provider);
      case 5:
        return _build600Masasi(provider);
      case 6:
        return _buildBirimIcmal(provider);
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
        _buildSheetTitle('KDV 1 (HESAPLANAN & İNDİRİLECEK KDV DENGESİ)', accentColor: const Color(0xFF1D4ED8)),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            // Başlık Satırı
            _headerRow(
              ['KDV ORANI', 'KDV %10', 'KDV %20', 'HESAPLANAN TOPLAM KDV (%10 ve %20 Toplamları)'],
              bg: const Color(0xFFDBEAFE),
              textColor: const Color(0xFF1E3A8A),
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
            ),
            _dataRow('9 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.dokuzBoluOn] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.dokuzBoluOn] ?? 0),
              '9 / 10 (%90)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.dokuzBoluOn] ?? 0),
            ]),
            _dataRow('7 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.yediBoluOn] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.yediBoluOn] ?? 0),
              '7 / 10 (%70)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.yediBoluOn] ?? 0),
            ]),
            _dataRow('5 / 10 Tevkifatlar', [
              TurkceFormat.para(k2.turMatrahToplam[TevkifatTuru.besBoluOn] ?? 0),
              TurkceFormat.para(k2.turKdvToplam[TevkifatTuru.besBoluOn] ?? 0),
              '5 / 10 (%50)',
              TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.besBoluOn] ?? 0),
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
                      _dataRow('Diş Hekimliği Aylık 600 Hasılatı', [TurkceFormat.para(provider.hasiat600Satirlari.where((s) => BirimAdlandirma.canonicalKey(s.birimAdi) == 'dis').fold(0.0, (sum, s) => sum + s.aylikHasilat600))]),
                      _dataRow('Diş Hekimliği 123 Kredi Kartı Tutarı', [TurkceFormat.para(provider.hasiat600Satirlari.where((s) => BirimAdlandirma.canonicalKey(s.birimAdi) == 'dis').fold(0.0, (sum, s) => sum + s.krediKarti123))]),
                      _highlightRow('600 KÜMÜLATİF HASILAT', TurkceFormat.para(provider.hasiat600ToplamKumulatif), const Color(0xFF0284C7), colSpan: 2),
                    ],
                    borderColor: const Color(0xFFDDD6FE),
                    gridColor: const Color(0xFFFAF5FF),
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
              bg: const Color(0xFFDBEAFE),
              textColor: const Color(0xFF1E3A8A),
            ),
            ...provider.kdv1Satirlari.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              return TableRow(
                decoration: BoxDecoration(color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(s.birimAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
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
          borderColor: const Color(0xFFBFDBFE),
          gridColor: const Color(0xFFEFF6FF),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.2),
            6: FixedColumnWidth(36),
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
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['FİRMA / KİŞİ ADI', 'VERGİ / TC NO', 'TÜR / ORAN', 'MATRAH TUTARI', 'KDV TUTARI', 'TEVKİFAT TUTARI', 'İŞLEM'],
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
                  _cellText('${f.tevkifatTuru.etiket} (%${f.kdvOrani})', align: TextAlign.center),
                  _cellText(TurkceFormat.para(f.matrahTutari)),
                  _cellText(TurkceFormat.para(f.kdvTutari)),
                  _cellText(TurkceFormat.para(f.tevkifatTutari), isBold: true, color: const Color(0xFFD97706)),
                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => provider.removeTevkifatKaydi(idx),
                    ),
                  ),
                ],
              );
            }),
          ],
          borderColor: const Color(0xFFFDE68A),
          gridColor: const Color(0xFFFFFBEB),
          columnWidths: const {
            0: FlexColumnWidth(2.4),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.2),
            6: FixedColumnWidth(36),
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
                  _cellText(m.birimAdi, isBold: true, align: TextAlign.left),
                  _cellText(m.adSoyad, align: TextAlign.left),
                  _cellText('${m.kisiSayisi}', align: TextAlign.center),
                  _cellText(TurkceFormat.para(m.brutUcret)),
                  _cellText(TurkceFormat.para(m.gelirVergisi)),
                  _cellText(TurkceFormat.para(m.damgaVergisi)),
                  _cellText(TurkceFormat.para(m.netOdenen)),
                  _cellText(TurkceFormat.para(m.aylikGelirVergisiMatrahi)),
                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => provider.removeMuhtasarSatir(idx),
                    ),
                  ),
                ],
              );
            }),
          ],
          borderColor: const Color(0xFFA7F3D0),
          gridColor: const Color(0xFFF0FDF4),
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.6),
            2: FixedColumnWidth(45),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(1.0),
            7: FlexColumnWidth(1.0),
            8: FixedColumnWidth(36),
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 5. DAMGA MASASI (360.03.05 BİNDE 9,48)
  // =========================================================================
  Widget _buildDamgaMasasi(BeyannameProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSheetTitle('360.03.05 Ödemelerden Kesilen Damga Vergisi (Binde 9,48 Ters Matrah Hesabı)', accentColor: const Color(0xFF7C3AED)),
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
                  _cellText(d.birimAdi, isBold: true, align: TextAlign.left),
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
                  _cellText(h.birimAdi, isBold: true, align: TextAlign.left),
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
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.4),
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
          child: const Text(
            '💡 İpucu: Bu Ay Aylık Hasılatı girdiğinizde Kümülatif otomatik hesaplanır. Dilerseniz Kümülatif tutarı doğrudan girerek aylık hasılatı ters formülle de bulabilirsiniz.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 7. BİRİM İCMALİ (MUHASEBE ÇIKTISI)
  // =========================================================================
  Widget _buildBirimIcmal(BeyannameProvider provider) {
    final list = provider.birimIcmalListesi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSheetTitle('Birim Bazlı Vergi İcmal Tablosu (Nihai Muhasebe Tahakkuku)', accentColor: const Color(0xFF334155)),
        const SizedBox(height: 6),
        _buildTableContainer(
          [
            _headerRow(
              ['BİRİM ADI', 'KDV 1', 'KDV 2 (9/10)', 'KDV 2 (7/10)', 'MUHTASAR GV', 'MUHTASAR DV', 'GENEL TOPLAM'],
              bg: const Color(0xFFF1F5F9),
              textColor: const Color(0xFF1E293B),
            ),
            ...list.map((b) => TableRow(
                  children: [
                    _cellText(b.birimAdi, isBold: true, align: TextAlign.left),
                    _cellText(TurkceFormat.para(b.kdv1Tutari)),
                    _cellText(TurkceFormat.para(b.kdv2DokuzBoluOn)),
                    _cellText(TurkceFormat.para(b.kdv2YediBoluOn)),
                    _cellText(TurkceFormat.para(b.muhtasarGelir)),
                    _cellText(TurkceFormat.para(b.muhtasarDamga)),
                    _cellText(TurkceFormat.para(b.genelToplamOdenecek), isBold: true, color: const Color(0xFF1D4ED8)),
                  ],
                )),
          ],
          borderColor: const Color(0xFFCBD5E1),
          gridColor: const Color(0xFFF8FAFC),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(1.2),
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

  Widget _buildTableContainer(
    List<TableRow> rows, {
    Color borderColor = const Color(0xFFBAE6FD),
    Color gridColor = const Color(0xFFE0F2FE),
    Map<int, TableColumnWidth>? columnWidths,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Table(
        columnWidths: columnWidths,
        border: TableBorder.all(color: gridColor, width: 1),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  TableRow _headerRow(List<String> titles, {Color? bg, Color? textColor}) {
    return TableRow(
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFE0F2FE),
      ),
      children: titles.map((t) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor ?? const Color(0xFF0369A1),
              letterSpacing: 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }

  TableRow _dataRow(String label, List<String> values, {bool isBold = false, Color? bg}) {
    return TableRow(
      decoration: bg != null ? BoxDecoration(color: bg) : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
        ),
        ...values.map((v) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF0F172A),
                ),
              ),
            )),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor ?? const Color(0xFF0369A1)),
          ),
        ),
        ...List.generate(colSpan - 1, (_) => const SizedBox.shrink()),
      ],
    );
  }

  TableRow _highlightRow(String title, String value, Color color, {required int colSpan}) {
    final List<Widget> cells = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    ];
    for (int i = 0; i < colSpan - 2; i++) {
      cells.add(const SizedBox.shrink());
    }
    cells.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
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
          padding: const EdgeInsets.all(12),
          child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        ...List.generate(colSpan - 1, (_) => const SizedBox.shrink()),
      ],
    );
  }

  Widget _cellText(String text, {bool isBold = false, TextAlign align = TextAlign.right, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }

  // ==================== DİYALOGLAR (EKLEME İŞLEMLERİ) ====================

  void _showAddBirimDialog(BuildContext context, BeyannameProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Birim Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Birim Adı (Resmi Tam Ad veya Kısaltma)',
            hintText: 'örn: UBATAM, DÖSİM, USEM veya tam adı...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text.trim();
              if (raw.isNotEmpty) {
                final std = BirimAdlandirma.tamAdGetir(raw);
                provider.addKdv1Birim(std);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showAddTevkifatDialog(BuildContext context, BeyannameProvider provider) {
    final firmaCtrl = TextEditingController();
    final vknCtrl = TextEditingController();
    final matrahCtrl = TextEditingController();
    final kdvCtrl = TextEditingController();
    TevkifatTuru seciliTur = TevkifatTuru.dokuzBoluOn;
    int kdvOrani = 20;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Tevkifatlı Fatura Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: firmaCtrl, decoration: const InputDecoration(labelText: 'Firma / Kişi Adı')),
                const SizedBox(height: 8),
                TextField(controller: vknCtrl, decoration: const InputDecoration(labelText: 'Vergi No / TC Kimlik')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TevkifatTuru>(
                        value: seciliTur,
                        decoration: const InputDecoration(labelText: 'Tevkifat Türü'),
                        items: const [
                          DropdownMenuItem(value: TevkifatTuru.dokuzBoluOn, child: Text('9 / 10 (%90)')),
                          DropdownMenuItem(value: TevkifatTuru.yediBoluOn, child: Text('7 / 10 (%70)')),
                          DropdownMenuItem(value: TevkifatTuru.besBoluOn, child: Text('5 / 10 (%50)')),
                        ],
                        onChanged: (v) => setDialogState(() => seciliTur = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: kdvOrani,
                        decoration: const InputDecoration(labelText: 'KDV Oranı'),
                        items: [8, 10, 18, 20].map((o) => DropdownMenuItem(value: o, child: Text('%$o'))).toList(),
                        onChanged: (v) => setDialogState(() => kdvOrani = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: matrahCtrl,
                  decoration: const InputDecoration(labelText: 'Matrah Tutarı (TL)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final m = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                    if (m > 0) {
                      final kdv = BeyannameHesaplamaMotoru.round(m * (kdvOrani / 100));
                      kdvCtrl.text = kdv.toString();
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: kdvCtrl, decoration: const InputDecoration(labelText: 'KDV Tutarı (TL)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                final matrah = double.tryParse(matrahCtrl.text.replaceAll(',', '.')) ?? 0;
                final kdv = double.tryParse(kdvCtrl.text.replaceAll(',', '.')) ?? 0;
                final tevkifat = BeyannameHesaplamaMotoru.round(kdv * seciliTur.oran);

                provider.addTevkifatKaydi(
                  TevkifatFirmaKaydi(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    firmaAdi: firmaCtrl.text.trim(),
                    vergiTcNo: vknCtrl.text.trim(),
                    tevkifatTuru: seciliTur,
                    kdvOrani: kdvOrani,
                    matrahTutari: matrah,
                    kdvTutari: kdv,
                    tevkifatTutari: tevkifat,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMuhtasarDialog(BuildContext context, BeyannameProvider provider) {
    final birimCtrl = TextEditingController(text: 'DTS');
    final adCtrl = TextEditingController();
    final brutCtrl = TextEditingController();
    final gvCtrl = TextEditingController();
    final dvCtrl = TextEditingController();
    final matrahCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Muhtasar Personel Satırı Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: birimCtrl, decoration: const InputDecoration(labelText: 'Birim Adı')),
              const SizedBox(height: 8),
              TextField(controller: adCtrl, decoration: const InputDecoration(labelText: 'Personel Ad Soyad')),
              const SizedBox(height: 8),
              TextField(controller: brutCtrl, decoration: const InputDecoration(labelText: 'Brüt Ücret (TL)')),
              const SizedBox(height: 8),
              TextField(controller: gvCtrl, decoration: const InputDecoration(labelText: 'Gelir Vergisi (TL)')),
              const SizedBox(height: 8),
              TextField(controller: dvCtrl, decoration: const InputDecoration(labelText: 'Damga Vergisi (TL)')),
              const SizedBox(height: 8),
              TextField(controller: matrahCtrl, decoration: const InputDecoration(labelText: 'Aylık GV Matrahı (TL)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final brut = double.tryParse(brutCtrl.text.replaceAll(',', '.')) ?? 0;
              final gv = double.tryParse(gvCtrl.text.replaceAll(',', '.')) ?? 0;
              final dv = double.tryParse(dvCtrl.text.replaceAll(',', '.')) ?? 0;
              final matrah = double.tryParse(matrahCtrl.text.replaceAll(',', '.')) ?? 0;
              final net = BeyannameHesaplamaMotoru.round(brut - gv - dv);

              provider.addMuhtasarSatir(
                MuhtasarSatiri(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  birimAdi: BirimAdlandirma.tamAdGetir(birimCtrl.text),
                  adSoyad: adCtrl.text.trim(),
                  kisiSayisi: 1,
                  brutUcret: brut,
                  gelirVergisi: gv,
                  damgaVergisi: dv,
                  netOdenen: net,
                  aylikGelirVergisiMatrahi: matrah,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
