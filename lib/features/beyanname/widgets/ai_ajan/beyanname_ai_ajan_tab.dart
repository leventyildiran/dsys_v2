import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../birim/models/birim_model.dart';
import '../../providers/beyanname_provider.dart';
import 'ai_canli_akis_paneli.dart';
import 'ai_denetim_rapor_dialog.dart';
import 'birim_belge_karti.dart';
import 'okunan_veriler_onizleme_karti.dart';
import 'toplu_belge_yukleme_diyalogu.dart';

/// 8. Sekme: Akıllı Mizan & Belge Ajanı
class BeyannameAiAjanTab extends StatelessWidget {
  final BeyannameProvider provider;

  const BeyannameAiAjanTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    // Sistemdeki aktif birim listesi
    final birimSet = <String>{};
    for (final k in provider.kdv1Satirlari) {
      if (k.birimAdi.trim().isNotEmpty) birimSet.add(k.birimAdi);
    }
    for (final d in provider.damgaSatirlari) {
      if (d.birimAdi.trim().isNotEmpty) birimSet.add(d.birimAdi);
    }
    if (birimSet.isEmpty) {
      for (final b in BirimModel.varsayilanBirimler) {
        birimSet.add(b.ad);
      }
    }

    final aktifBirimler = birimSet.toList()..sort();
    final toplamEvrak = provider.toplamYuklenenBelgeSayisi;
    final isCalisiyor = provider.isAiAjanCalisiyor;
    final sonRapor = provider.sonAjanRaporu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==================== KOMPAKT ÜST KONTROL PANELİ ====================
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology_rounded, size: 22, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Otomatik Mizan & Beyanname Hesaplama Motoru',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${provider.seciliYil} / ${provider.seciliAy.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${aktifBirimler.length} Birim · $toplamEvrak Belge',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Eylem Butonları
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Toplu Belge Seç (Otomatik Birim & Slot Eşleştirme)
                      OutlinedButton.icon(
                        onPressed: isCalisiyor
                            ? null
                            : () => _topluBelgeSecVeEslestir(context, aktifBirimler),
                        icon: const Icon(Icons.upload_file_rounded, size: 15),
                        label: const Text(
                          'Toplu Belge Yükle (Otomatik Dağıt)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // 2. Hızlı Deterministik Oku & Masalara Aktar (AI Beklemeden Saat Gibi)
                      ElevatedButton.icon(
                        onPressed: isCalisiyor || toplamEvrak == 0
                            ? null
                            : () {
                                provider.aiAjanAnaliziBaslat(
                                  hizliDeterministikMod: true,
                                  otomatikMasalaraAktar: true,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '⚡ Hızlı okuma başlatıldı; tamamlandığında veriler otomatik olarak Beyanname masalarına aktarılacak!',
                                    ),
                                    backgroundColor: AppColors.success,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.flash_on_rounded, size: 15),
                        label: const Text(
                          'Hızlı Oku & Masalara Aktar',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.border,
                          disabledForegroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // 3. AI Destekli Derin Oku & Denetle
                      ElevatedButton.icon(
                        onPressed: isCalisiyor || toplamEvrak == 0
                            ? null
                            : () => provider.aiAjanAnaliziBaslat(
                                  hizliDeterministikMod: false,
                                ),
                        icon: isCalisiyor
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                              )
                            : const Icon(Icons.psychology_alt_rounded, size: 16),
                        label: Text(
                          isCalisiyor ? 'Analiz Ediliyor...' : 'AI + Kural Motoru ile Oku',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.border,
                          disabledForegroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      // 4. Rapor Dialog Butonu (Varsa)
                      if (sonRapor != null)
                        FilledButton.tonalIcon(
                          onPressed: () => AiDenetimRaporDialog.goster(
                            context,
                            rapor: sonRapor,
                            provider: provider,
                          ),
                          icon: Icon(
                            sonRapor.kritikHataVarMi ? Icons.warning_rounded : Icons.check_circle_rounded,
                            size: 15,
                            color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                          ),
                          label: Text(
                            sonRapor.kritikHataVarMi
                                ? 'Denetim Raporu (${sonRapor.kritikHataSayisi} Uyarı)'
                                : 'Denetim Raporu (Mutabık)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: sonRapor.kritikHataVarMi
                                ? AppColors.dangerSubtle
                                : AppColors.successSubtle,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),

                      // 5. Temizle Butonu
                      if (toplamEvrak > 0 && !isCalisiyor)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          tooltip: 'Tüm Belgeleri Sıfırla',
                          onPressed: () => _belgeleriTemizleOnay(context),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'İpucu: Mizan (Excel/PDF) ve Tevkifat Faturalarını "Toplu Belge Yükle" ile tek seferde seçebilirsiniz; sistem birim ve mizan türünü (Aylık / Yıllık / Yardımcı / Fatura) otomatik tanır.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // ==================== CANLI AKIŞ TERMİNALİ ====================
        if (isCalisiyor || provider.aiAjanLoglari.isNotEmpty) AiCanliAkisPaneli(provider: provider),

        // ==================== OKUNAN VERİLER ÖNİZLEME & TEK TIKLA AKTARIM ====================
        if (!isCalisiyor && sonRapor != null)
          OkunanVerilerOnizlemeKarti(
            rapor: sonRapor,
            provider: provider,
          ),

        // ==================== AKTİF BİRİMLER LİSTESİ ====================
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.folder_open_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Birim Belgeleri (${aktifBirimler.length} Birim)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        ...aktifBirimler.map((birimAdi) {
          return BirimBelgeKarti(
            birimAdi: birimAdi,
            provider: provider,
          );
        }),
      ],
    );
  }

  Future<void> _topluBelgeSecVeEslestir(
    BuildContext context,
    List<String> aktifBirimler,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'txt', 'png', 'jpg'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final dosyalar = result.files
          .map(
            (f) => (
              dosyaAdi: f.name,
              dosyaBoyutu: f.size,
              dosyaUzantisi: f.extension ?? 'pdf',
              dosyaBytes: f.bytes,
            ),
          )
          .toList();

      if (!context.mounted) return;

      await TopluBelgeYuklemeDiyalogu.calistir(
        context: context,
        provider: provider,
        dosyalar: dosyalar,
        aktifBirimler: aktifBirimler,
        varsayilanBirimAdi: aktifBirimler.isNotEmpty ? aktifBirimler.first : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toplu dosya seçme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _belgeleriTemizleOnay(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm Belgeleri Temizle'),
        content: const Text('Yüklenmiş olan tüm mizan ve ek belgeler silinecektir. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.tumBelgeleriTemizle();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Temizle', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }
}
