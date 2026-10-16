import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/beyanname_belge_model.dart';
import '../../providers/beyanname_provider.dart';
import 'toplu_belge_yukleme_diyalogu.dart';

/// Birim başına 4 adet belge yükleme yuvası sunan kompakt ve modern kart bileşeni.
class BirimBelgeKarti extends StatelessWidget {
  final String birimAdi;
  final BeyannameProvider provider;

  const BirimBelgeKarti({
    super.key,
    required this.birimAdi,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final aylikMizan = provider.getBelge(birimAdi, BirimBelgeSlotTuru.aylikMizan);
    final yardimciMizan = provider.getBelge(birimAdi, BirimBelgeSlotTuru.yardimciMizan);
    final yillikMizan = provider.getBelge(birimAdi, BirimBelgeSlotTuru.yillikMizan);
    final digerBelge = provider.getBelge(birimAdi, BirimBelgeSlotTuru.diger);

    final yukluSayisi = (aylikMizan != null ? 1 : 0) +
        (yardimciMizan != null ? 1 : 0) +
        (yillikMizan != null ? 1 : 0) +
        (digerBelge != null ? 1 : 0);

    final isTamDolu = aylikMizan != null && yillikMizan != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTamDolu
              ? AppColors.success.withAlpha(120)
              : (yukluSayisi > 0 ? AppColors.warning.withAlpha(100) : AppColors.border),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Satırı
          Row(
            children: [
              Icon(
                isTamDolu ? Icons.check_circle_rounded : Icons.business_rounded,
                size: 16,
                color: isTamDolu ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        birimAdi,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isTamDolu
                            ? AppColors.successSubtle
                            : (yukluSayisi > 0 ? AppColors.warningSubtle : AppColors.surfaceVariant),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isTamDolu
                            ? 'Mizanlar Hazır ($yukluSayisi Belge)'
                            : (yukluSayisi > 0 ? '$yukluSayisi Belge Yüklü' : 'Belge Yok'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isTamDolu
                              ? AppColors.success
                              : (yukluSayisi > 0 ? AppColors.warning : AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bu birim için toplu dosya seçme butonu
              TextButton.icon(
                onPressed: provider.isAiAjanCalisiyor
                    ? null
                    : () => _cokluDosyaSecVeOtomatikYerlestir(context),
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 14),
                label: const Text(
                  'Çoklu Dosya Seç',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (yukluSayisi > 0) ...[
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: provider.isAiAjanCalisiyor
                      ? null
                      : () {
                          provider.aiAjanAnaliziBaslat(
                            sadeceBuBirim: birimAdi,
                            hizliDeterministikMod: true,
                            otomatikMasalaraAktar: true,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚡ $birimAdi verileri okunuyor ve masalara aktarılıyor...'),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  icon: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.success),
                  label: const Text(
                    'Hızlı Oku & Aktar',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successSubtle,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: provider.isAiAjanCalisiyor
                      ? null
                      : () => provider.aiAjanAnaliziBaslat(
                            sadeceBuBirim: birimAdi,
                            hizliDeterministikMod: false,
                          ),
                  icon: const Icon(Icons.bolt_rounded, size: 14),
                  label: const Text(
                    'AI ile Oku',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.neutral),
                  tooltip: 'Bu birimin tüm belgelerini kaldır',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => provider.birimBelgeleriniTemizle(birimAdi),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 4'lü Kompakt Slot Yuvaları
          LayoutBuilder(
            builder: (context, constraints) {
              final slot1 = _buildSlotItem(
                context,
                slotTuru: BirimBelgeSlotTuru.aylikMizan,
                kisaEtiket: 'Aylık Mizan *',
                yuklenen: aylikMizan,
              );
              final slot2 = _buildSlotItem(
                context,
                slotTuru: BirimBelgeSlotTuru.yillikMizan,
                kisaEtiket: 'Yıllık Mizan *',
                yuklenen: yillikMizan,
              );
              final slot3 = _buildSlotItem(
                context,
                slotTuru: BirimBelgeSlotTuru.yardimciMizan,
                kisaEtiket: 'Yardımcı Mizan',
                yuklenen: yardimciMizan,
              );
              final slot4 = _buildSlotItem(
                context,
                slotTuru: BirimBelgeSlotTuru.diger,
                kisaEtiket: 'Fatura / Diğer',
                yuklenen: digerBelge,
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: slot1),
                        const SizedBox(width: 6),
                        Expanded(child: slot2),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: slot3),
                        const SizedBox(width: 6),
                        Expanded(child: slot4),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: slot1),
                  const SizedBox(width: 6),
                  Expanded(child: slot2),
                  const SizedBox(width: 6),
                  Expanded(child: slot3),
                  const SizedBox(width: 6),
                  Expanded(child: slot4),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlotItem(
    BuildContext context, {
    required BirimBelgeSlotTuru slotTuru,
    required String kisaEtiket,
    required BirimYuklenenBelge? yuklenen,
  }) {
    final isLoaded = yuklenen != null;

    if (!isLoaded) {
      // Yüklenmemiş Boş Slot (Tıklanabilir sade buton kutusu)
      return InkWell(
        onTap: () => _dosyaSecVeYukle(context, slotTuru),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withAlpha(50),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  kisaEtiket,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Yüklenmiş Dolu Slot
    return Tooltip(
      message: '${yuklenen.dosyaAdi} (${yuklenen.okunabilirBoyut})',
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(
          color: AppColors.successSubtle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.success.withAlpha(120)),
        ),
        child: Row(
          children: [
            Icon(
              yuklenen.isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${slotTuru.baslik}: ${yuklenen.dosyaAdi}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.danger),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              tooltip: 'Kaldır',
              onPressed: () => provider.belgeSil(birimAdi: birimAdi, slotTuru: slotTuru),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dosyaSecVeYukle(BuildContext context, BirimBelgeSlotTuru slotTuru) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'txt', 'png', 'jpg'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        if (result.files.length == 1) {
          final f = result.files.first;
          provider.belgeYukle(
            birimAdi: birimAdi,
            slotTuru: slotTuru,
            dosyaAdi: f.name,
            dosyaBoyutu: f.size,
            dosyaUzantisi: f.extension ?? 'pdf',
            dosyaBytes: f.bytes,
          );
        } else {
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
          if (context.mounted) {
            await TopluBelgeYuklemeDiyalogu.calistir(
              context: context,
              provider: provider,
              dosyalar: dosyalar,
              aktifBirimler: [birimAdi],
              varsayilanBirimAdi: birimAdi,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _cokluDosyaSecVeOtomatikYerlestir(BuildContext context) async {
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

      if (context.mounted) {
        await TopluBelgeYuklemeDiyalogu.calistir(
          context: context,
          provider: provider,
          dosyalar: dosyalar,
          aktifBirimler: [birimAdi],
          varsayilanBirimAdi: birimAdi,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çoklu dosya seçme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
