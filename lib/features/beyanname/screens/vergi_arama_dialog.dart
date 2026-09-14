import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_model.dart';
import '../providers/beyanname_provider.dart';

/// Geriye Dönük Vergi ve Birim Arama Sayfası (Ayrı Modal / Pencere)
class VergiAramaDialog extends StatefulWidget {
  final BeyannameProvider provider;

  const VergiAramaDialog({super.key, required this.provider});

  static Future<void> goster(BuildContext context, BeyannameProvider provider) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 1200,
            height: 750,
            child: VergiAramaDialog(provider: provider),
          ),
        ),
      ),
    );
  }

  @override
  State<VergiAramaDialog> createState() => _VergiAramaDialogState();
}

class _VergiAramaDialogState extends State<VergiAramaDialog> {
  List<BeyannameDonemModel> _gecmisDonemler = [];
  bool _isLoading = false;
  String? _seciliBirim;
  int? _seciliYil;
  final TextEditingController _aramaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() => _isLoading = true);
    final list = await widget.provider.tumGecmisDonemleriYukle();
    if (mounted) {
      setState(() {
        _gecmisDonemler = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.provider.birimGecmisiFiltrele(
      _gecmisDonemler,
      seciliBirimAdi: _seciliBirim,
      seciliYil: _seciliYil,
    ).where((k) {
      if (_aramaCtrl.text.trim().isEmpty) return true;
      final q = _aramaCtrl.text.trim().toLowerCase();
      return k.birimAdi.toLowerCase().contains(q) ||
          k.donemBaslik.toLowerCase().contains(q);
    }).toList();

    final topKdv1 = filtered.fold(0.0, (s, x) => s + x.kdv1NetOdenecek);
    final topTevkifat = filtered.fold(0.0, (s, x) => s + x.kdv2Tevkifat);
    final topMuhtasarGv = filtered.fold(0.0, (s, x) => s + x.muhtasarGelirVergisi);
    final topMuhtasarDv = filtered.fold(0.0, (s, x) => s + x.muhtasarDamgaVergisi);
    final topDamga360 = filtered.fold(0.0, (s, x) => s + x.damgaVergisi360);
    final topHasilat600 = filtered.fold(0.0, (s, x) => s + x.hasilat600Aylik);
    final topKrediKarti = filtered.fold(0.0, (s, x) => s + x.krediKarti123);
    final genelToplamVergi = filtered.fold(0.0, (s, x) => s + x.toplamOdenecekVergi);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        leading: const Icon(Icons.search_rounded, color: AppColors.primary),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Geriye Dönük Vergi & Birim Tahakkuk Arama',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Text(
              'Tüm geçmiş dönemlerde birim bazında vergi, hasılat ve tevkifat sorgulaması',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Yenile',
            onPressed: _verileriYukle,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            tooltip: 'Kapat',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Birim Seçimi
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _seciliBirim,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Birim Seçin',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tüm Birimler', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...BirimModel.varsayilanBirimler.map(
                          (b) => DropdownMenuItem(
                            value: b.ad,
                            child: Text(
                              b.ad,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _seciliBirim = v),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Yıl Seçimi
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _seciliYil,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Yıl Seçin',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tüm Yıllar', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 2026, child: Text('2026')),
                        DropdownMenuItem(value: 2025, child: Text('2025')),
                        DropdownMenuItem(value: 2024, child: Text('2024')),
                      ],
                      onChanged: (v) => setState(() => _seciliYil = v),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Arama Kutusu
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _aramaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kelime ile Ara...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _aramaCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _aramaCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Sonuç Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Text(
                      '${filtered.length} Kayıt',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildKpiCard('KDV 1 Toplamı', TurkceFormat.para(topKdv1)),
                _buildKpiCard('KDV 2 Tevkifat', TurkceFormat.para(topTevkifat)),
                _buildKpiCard('Muhtasar GV', TurkceFormat.para(topMuhtasarGv)),
                _buildKpiCard('Muhtasar DV', TurkceFormat.para(topMuhtasarDv)),
                _buildKpiCard('Damga (360)', TurkceFormat.para(topDamga360)),
                _buildKpiCard('600 Hasılat', TurkceFormat.para(topHasilat600)),
                _buildKpiCard('123 Kredi Kartı', TurkceFormat.para(topKrediKarti)),
                _buildKpiCard('FİLTRE TOPLAMI', TurkceFormat.para(genelToplamVergi), isToplam: true),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Arama kriterlerine uygun geçmiş kayıt bulunamadı.',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            child: Table(
                              border: TableBorder.all(color: AppColors.tabloIzgara, width: 1),
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(1.8),
                                2: FlexColumnWidth(1.0),
                                3: FlexColumnWidth(1.1),
                                4: FlexColumnWidth(1.0),
                                5: FlexColumnWidth(1.0),
                                6: FlexColumnWidth(1.0),
                                7: FlexColumnWidth(1.1),
                                8: FlexColumnWidth(1.0),
                                9: FlexColumnWidth(1.2),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: AppColors.tabloBaslikZemin),
                                  children: [
                                    'DÖNEM', 'BİRİM ADI', 'KDV 1', 'KDV 2 TEVKİFAT',
                                    'MUHTASAR GV', 'MUHTASAR DV', 'DAMGA (360)', '600 HASILAT',
                                    '123 K.KARTI', 'TOPLAM VERGİ'
                                  ].map((t) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Text(
                                          t,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.tabloBaslikMetin),
                                        ),
                                      )).toList(),
                                ),
                                ...filtered.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final k = entry.value;
                                  return TableRow(
                                    decoration: BoxDecoration(color: idx.isEven ? AppColors.surface : AppColors.tabloSatirCift),
                                    children: [
                                      _cell(k.donemBaslik, isBold: true, align: TextAlign.left),
                                      _cell(k.birimAdi, isBold: true, align: TextAlign.left),
                                      _cell(TurkceFormat.para(k.kdv1NetOdenecek)),
                                      _cell(TurkceFormat.para(k.kdv2Tevkifat)),
                                      _cell(TurkceFormat.para(k.muhtasarGelirVergisi)),
                                      _cell(TurkceFormat.para(k.muhtasarDamgaVergisi)),
                                      _cell(TurkceFormat.para(k.damgaVergisi360)),
                                      _cell(TurkceFormat.para(k.hasilat600Aylik)),
                                      _cell(TurkceFormat.para(k.krediKarti123)),
                                      _cell(TurkceFormat.para(k.toplamOdenecekVergi), isBold: true, color: AppColors.toplamSatirMetin),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tek bir toplamı gösterir. Tüm kartlar nötr yüzeydir; yalnızca "FİLTRE
  /// TOPLAMI" tek vurgu rengiyle ([AppColors.primary]) öne çıkar. Böylece 8
  /// farklı renk yerine kullanıcı tek bakışta özeti bulur.
  Widget _buildKpiCard(String label, String value, {bool isToplam = false}) {
    return Container(
      width: 135,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isToplam ? AppColors.primarySubtle : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isToplam ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: isToplam ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool isBold = false, TextAlign align = TextAlign.right, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppColors.hucreMetin,
        ),
      ),
    );
  }
}
