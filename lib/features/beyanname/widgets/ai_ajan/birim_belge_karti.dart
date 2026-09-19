import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/beyanname_belge_model.dart';
import '../../providers/beyanname_provider.dart';

/// Birim başına 3 adet belge yükleme yuvası (Aylık Mizan, Yıllık Mizan, Diğer)
/// sunan kurumsal kart bileşeni.
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
    final yillikMizan = provider.getBelge(birimAdi, BirimBelgeSlotTuru.yillikMizan);
    final digerBelge = provider.getBelge(birimAdi, BirimBelgeSlotTuru.diger);

    final yukluSayisi = (aylikMizan != null ? 1 : 0) +
        (yillikMizan != null ? 1 : 0) +
        (digerBelge != null ? 1 : 0);

    final isTamDolu = aylikMizan != null && yillikMizan != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTamDolu ? AppColors.success : (yukluSayisi > 0 ? AppColors.warning : AppColors.border),
          width: isTamDolu ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Başlık ve Durum Rozeti
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isTamDolu ? AppColors.successSubtle : AppColors.primarySubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isTamDolu ? Icons.check_circle_rounded : Icons.account_balance_rounded,
                    size: 18,
                    color: isTamDolu ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        birimAdi,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isTamDolu
                            ? 'Mizan belgeleri eksiksiz yüklendi'
                            : (yukluSayisi > 0
                                ? '$yukluSayisi/2 zorunlu mizan yüklendi'
                                : 'Belge bekleniyor (Aylık ve Yıllık Mizan yükleyiniz)'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isTamDolu ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (yukluSayisi > 0)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.neutral),
                    tooltip: 'Bu birimin tüm belgelerini kaldır',
                    onPressed: () => provider.birimBelgeleriniTemizle(birimAdi),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // 3'lü Slot Yuvaları
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                if (isNarrow) {
                  return Column(
                    children: [
                      _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.aylikMizan,
                        yuklenen: aylikMizan,
                        zorunlu: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.yillikMizan,
                        yuklenen: yillikMizan,
                        zorunlu: true,
                      ),
                      const SizedBox(height: 8),
                      _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.diger,
                        yuklenen: digerBelge,
                        zorunlu: false,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.aylikMizan,
                        yuklenen: aylikMizan,
                        zorunlu: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.yillikMizan,
                        yuklenen: yillikMizan,
                        zorunlu: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSlotItem(
                        context,
                        slotTuru: BirimBelgeSlotTuru.diger,
                        yuklenen: digerBelge,
                        zorunlu: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotItem(
    BuildContext context, {
    required BirimBelgeSlotTuru slotTuru,
    required BirimYuklenenBelge? yuklenen,
    required bool zorunlu,
  }) {
    final isLoaded = yuklenen != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isLoaded ? AppColors.successSubtle : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLoaded ? AppColors.success : AppColors.border,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLoaded
                ? (yuklenen.isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded)
                : Icons.upload_file_rounded,
            size: 20,
            color: isLoaded ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      slotTuru.baslik,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (zorunlu)
                      const Text(
                        ' *',
                        style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                Text(
                  isLoaded
                      ? '${yuklenen.dosyaAdi} (${yuklenen.okunabilirBoyut})'
                      : 'PDF veya Excel yükle',
                  style: TextStyle(
                    fontSize: 10,
                    color: isLoaded ? AppColors.textPrimary : AppColors.textMuted,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (isLoaded)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Belgeyi Kaldır',
              onPressed: () => provider.belgeSil(birimAdi: birimAdi, slotTuru: slotTuru),
            )
          else
            ElevatedButton(
              onPressed: () => _dosyaSecVeYukle(context, slotTuru),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(50, 26),
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              child: const Text('Seç'),
            ),
        ],
      ),
    );
  }

  Future<void> _dosyaSecVeYukle(BuildContext context, BirimBelgeSlotTuru slotTuru) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'txt', 'png', 'jpg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final f = result.files.first;
        final bytes = f.bytes;
        final ext = f.extension ?? 'pdf';

        provider.belgeYukle(
          birimAdi: birimAdi,
          slotTuru: slotTuru,
          dosyaAdi: f.name,
          dosyaBoyutu: f.size,
          dosyaUzantisi: ext,
          dosyaBytes: bytes,
        );
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
}
