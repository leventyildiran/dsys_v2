import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../birim/models/birim_model.dart';
import '../../providers/beyanname_provider.dart';
import 'ai_canli_akis_paneli.dart';
import 'ai_denetim_rapor_dialog.dart';
import 'birim_belge_karti.dart';

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
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Akıllı Mizan & Beyanname Denetim Ajanı',
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
                  const Spacer(),

                  // Rapor ve Masalara Aktar Butonu (Varsa)
                  if (sonRapor != null) ...[
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
                            ? 'Raporu İncele & Masalara Aktar (${sonRapor.kritikHataSayisi} Hata)'
                            : 'Raporu İncele & Masalara Aktar (Mutabık)',
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
                    const SizedBox(width: 8),
                  ],

                  // Tümünü Analiz Et Butonu
                  ElevatedButton.icon(
                    onPressed: isCalisiyor || toplamEvrak == 0
                        ? null
                        : () => provider.aiAjanAnaliziBaslat(),
                    icon: isCalisiyor
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      isCalisiyor ? 'Analiz Ediliyor...' : 'Tüm Birimleri Oku',
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

                  // Temizle Butonu
                  if (toplamEvrak > 0 && !isCalisiyor) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      tooltip: 'Tüm Belgeleri Sıfırla',
                      onPressed: () => _belgeleriTemizleOnay(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),

              // Rapor Sonuç Özet Çizgisi (Varsa)
              if (!isCalisiyor && sonRapor != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sonRapor.kritikHataVarMi ? AppColors.dangerSubtle : AppColors.successSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: sonRapor.kritikHataVarMi
                          ? AppColors.danger.withAlpha(80)
                          : AppColors.success.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sonRapor.kritikHataVarMi ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sonRapor.kritikHataVarMi
                              ? 'Son analizde ${sonRapor.kritikHataSayisi} kritik uyuşmazlık ve ${sonRapor.uyariSayisi} inceleme uyarısı bulundu. Detaylar için yukarıdaki butondan raporu açabilirsiniz.'
                              : 'Son analiz tamamlandı. Mizan ve KDV hesapları mutabık.',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ==================== CANLI AKIŞ TERMİNALİ ====================
        if (isCalisiyor) AiCanliAkisPaneli(provider: provider),

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
