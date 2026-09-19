import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/turkce_format.dart';
import '../../models/beyanname_denetim_rapor_model.dart';
import '../../providers/beyanname_provider.dart';

/// Analiz sonrasında açılan, "Neyi Nereden Aldı, Nereye Koydu" şeffaf tablosu
/// ile 9 senaryolu çapraz mutabakat kontrollerini sunan denetim raporu penceresi.
class AiDenetimRaporDialog extends StatefulWidget {
  final BeyannameAjanRaporu rapor;
  final BeyannameProvider provider;

  const AiDenetimRaporDialog({
    super.key,
    required this.rapor,
    required this.provider,
  });

  static Future<void> goster(
    BuildContext context, {
    required BeyannameAjanRaporu rapor,
    required BeyannameProvider provider,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 1060,
            height: 740,
            child: AiDenetimRaporDialog(rapor: rapor, provider: provider),
          ),
        ),
      ),
    );
  }

  @override
  State<AiDenetimRaporDialog> createState() => _AiDenetimRaporDialogState();
}

class _AiDenetimRaporDialogState extends State<AiDenetimRaporDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rapor = widget.rapor;
    final provider = widget.provider;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'BEYANNAME DENETİM & ÇAPRAZ MUTABAKAT RAPORU (${rapor.yil} / ${rapor.ay.toString().padLeft(2, '0')})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.table_view_rounded, size: 18),
              text: 'Nereden Nereye İcmali (${rapor.neredenNereyeListesi.length} Kayıt)',
            ),
            Tab(
              icon: const Icon(Icons.shield_outlined, size: 18),
              text: '9 Senaryolu Çapraz Denetim (${rapor.denetimKontrolleri.length} Test)',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // KPI Özet Gösterge Paneli
          _buildKpiSummaryBar(rapor),

          // Sekme İçerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNeredenNereyeTab(rapor),
                _buildCaprazDenetimTab(rapor),
              ],
            ),
          ),

          // Alt Eylem Butonları
          _buildBottomActionButtons(context, rapor, provider),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar(BeyannameAjanRaporu rapor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          _buildKpiCard(
            label: 'Analiz Edilen Birim',
            value: '${rapor.analizEdilenBirimler.length}',
            color: AppColors.primary,
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'İncelenen Evrak',
            value: '${rapor.toplamDosyaSayisi}',
            color: AppColors.info,
            icon: Icons.description_rounded,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'Kritik Hata',
            value: '${rapor.kritikHataSayisi}',
            color: rapor.kritikHataSayisi > 0 ? AppColors.danger : AppColors.neutral,
            icon: Icons.error_rounded,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'İnceleme Uyarısı',
            value: '${rapor.uyariSayisi}',
            color: rapor.uyariSayisi > 0 ? AppColors.warning : AppColors.neutral,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            label: 'Tam Mutabakat',
            value: '${rapor.basariliKontrolSayisi}',
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
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

  // ==================== SEKME 1: NEREDEN NEREYE İCMALİ ====================
  Widget _buildNeredenNereyeTab(BeyannameAjanRaporu rapor) {
    if (rapor.neredenNereyeListesi.isEmpty) {
      return const Center(child: Text('Aktarılacak veri kaydı bulunamadı.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            columns: const [
              DataColumn(label: Text('BİRİM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('KAYNAK BELGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('MİZAN HESAP KODU / KALEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(numeric: true, label: Text('BULUNAN TUTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('BEYANNAMEDE HEDEF ALAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text('AÇIKLAMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
            rows: rapor.neredenNereyeListesi.map((kayit) {
              return DataRow(
                cells: [
                  DataCell(Text(kayit.birimAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataCell(Text(kayit.kaynakBelge, style: const TextStyle(fontSize: 11))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        kayit.hesapKoduVeAdi,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      TurkceFormat.para(kayit.bulunanTutar),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_right_alt_rounded, size: 16, color: AppColors.info),
                        const SizedBox(width: 4),
                        Text(
                          kayit.hedefAlan,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.info),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(kayit.aciklama ?? '', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ==================== SEKME 2: 9 SENARYOLU ÇAPRAZ DENETİM ====================
  Widget _buildCaprazDenetimTab(BeyannameAjanRaporu rapor) {
    if (rapor.denetimKontrolleri.isEmpty) {
      return const Center(child: Text('Denetim kontrolü bulunamadı.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rapor.denetimKontrolleri.length,
      itemBuilder: (context, index) {
        final k = rapor.denetimKontrolleri[index];

        Color durumRengi = AppColors.success;
        Color zeminRengi = AppColors.successSubtle;
        IconData ikon = Icons.check_circle_rounded;

        if (k.seviye == DenetimSeviyesi.hata) {
          durumRengi = AppColors.danger;
          zeminRengi = AppColors.dangerSubtle;
          ikon = Icons.error_rounded;
        } else if (k.seviye == DenetimSeviyesi.uyari) {
          durumRengi = AppColors.warning;
          zeminRengi = AppColors.warningSubtle;
          ikon = Icons.warning_amber_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: durumRengi.withAlpha(120), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık Bandı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: zeminRengi,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(ikon, size: 18, color: durumRengi),
                    const SizedBox(width: 8),
                    Text(
                      '[Senaryo ${k.senaryoNo}] ${k.birimAdi}: ${k.baslik}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: durumRengi,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: durumRengi,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        k.seviye.etiket,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Açıklama ve Sayısal Mutabakat Detayı
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.aciklama,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, height: 1.3),
                    ),
                    if (k.beklenenDeger != null || k.bulunanDeger != null || k.fark != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            if (k.beklenenDeger != null) ...[
                              const Text('Beklenen: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(TurkceFormat.para(k.beklenenDeger!), style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 16),
                            ],
                            if (k.bulunanDeger != null) ...[
                              const Text('Bulunan: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(TurkceFormat.para(k.bulunanDeger!), style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 16),
                            ],
                            if (k.fark != null && k.fark!.abs() > 0.01) ...[
                              const Text('Fark: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger)),
                              Text(
                                TurkceFormat.para(k.fark!),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (k.cozumOnerisi != null && k.cozumOnerisi!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Öneri / Çözüm: ${k.cozumOnerisi!}',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== ALT BUTONLAR (UYGULA / KAPAT) ====================
  Widget _buildBottomActionButtons(
    BuildContext context,
    BeyannameAjanRaporu rapor,
    BeyannameProvider provider,
  ) {
    final uygulandi = rapor.uygulandiMi || (provider.sonAjanRaporu?.uygulandiMi ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (uygulandi)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                SizedBox(width: 6),
                Text(
                  'Bu rapordaki veriler beyanname masalarına başarıyla aktarılmıştır.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ],
            )
          else if (rapor.kritikHataVarMi)
            const Row(
              children: [
                Icon(Icons.warning_rounded, size: 16, color: AppColors.danger),
                SizedBox(width: 6),
                Text(
                  'DİKKAT: Kritik hatalar var. Verileri masalara aktardıktan sonra hücreleri manuel düzeltebilirsiniz.',
                  style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              provider.aiAjanVerileriniUygula(rapor);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Mizan ve belge verileri KDV 1, Damga ve 600 Hasılat masalarına başarıyla aktarıldı. İlgili sekmelerden inceleyebilirsiniz.'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.download_done_rounded, size: 16),
            label: Text(
              uygulandi ? 'Masalara Tekrar Uygula' : 'Verileri Beyannameye Aktar',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
