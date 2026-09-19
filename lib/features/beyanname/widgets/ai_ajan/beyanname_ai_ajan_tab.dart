import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../birim/models/birim_model.dart';
import '../../providers/beyanname_provider.dart';
import 'ai_canli_akis_paneli.dart';
import 'ai_denetim_rapor_dialog.dart';
import 'birim_belge_karti.dart';

/// 8. Sekme: Akıllı Mizan & Belge Ajanı (AI Destekli Beyanname Hazırlama Masası)
class BeyannameAiAjanTab extends StatelessWidget {
  final BeyannameProvider provider;

  const BeyannameAiAjanTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    // Sistemdeki aktif birim listesi (KDV 1 masasında kayıtlı olanlar veya kurum varsayılanları)
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
        // ==================== ÜST YÖNETİM VE BAŞLATMA BANDI ====================
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '🤖 Otomatik Beyanname Ajanı (Gemini Mizan & Belge Motoru)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${provider.seciliYil} / ${provider.seciliAy.toString().padLeft(2, '0')} Dönemi',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Birimlerin Aylık Mizan, Yıllık Kümülatif Mizan ve Ek Belgelerini yükleyin. Sistem tek tek derinlemesine inceler, 9 senaryolu çapraz denetim yapar ve beyannamenizi hatasız doldurur.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),

              // Butonlar ve İstatistikler
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Ana Başlatma Butonu
                  ElevatedButton.icon(
                    onPressed: isCalisiyor || toplamEvrak == 0
                        ? null
                        : () => provider.aiAjanAnaliziBaslat(),
                    icon: isCalisiyor
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      isCalisiyor ? 'Analiz Ediliyor...' : '🚀 Beyannameyi Otomatik Analiz Et ve Hazırla',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),

                  // Son Raporu İncele Butonu
                  if (sonRapor != null)
                    OutlinedButton.icon(
                      onPressed: () => AiDenetimRaporDialog.goster(
                        context,
                        rapor: sonRapor,
                        provider: provider,
                      ),
                      icon: const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                      label: const Text(
                        '📋 Son Denetim Raporunu İncele',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),

                  // Tüm Belgeleri Temizle Butonu
                  if (toplamEvrak > 0 && !isCalisiyor)
                    TextButton.icon(
                      onPressed: () => _belgeleriTemizleOnay(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                      label: const Text('Tüm Belgeleri Sıfırla', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                    ),

                  // Durum Rozetleri
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Aktif Birim: ${aktifBirimler.length}  |  Yüklü Evrak: $toplamEvrak',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ==================== CANLI AKIŞ TERMİNALİ ====================
        if (isCalisiyor) AiCanliAkisPaneli(provider: provider),

        // ==================== RAPOR BİLDİRİM BANDI ====================
        if (!isCalisiyor && sonRapor != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sonRapor.kritikHataVarMi ? AppColors.dangerSubtle : AppColors.successSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  sonRapor.kritikHataVarMi ? Icons.warning_rounded : Icons.check_circle_rounded,
                  size: 20,
                  color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sonRapor.kritikHataVarMi
                      ? '⚠️ Son analizde ${sonRapor.kritikHataSayisi} kritik uyuşmazlık ve ${sonRapor.uyariSayisi} inceleme uyarısı bulundu.'
                      : '✓ Son analiz başarıyla tamamlandı. Tüm mizan ve KDV hesapları mutabık.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => AiDenetimRaporDialog.goster(
                    context,
                    rapor: sonRapor,
                    provider: provider,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Raporu Aç ve Masalara Aktar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sonRapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

        // ==================== AKTİF BİRİMLER LİSTESİ ====================
        Row(
          children: [
            const Icon(Icons.folder_shared_outlined, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Aktif Birimler ve Belge Yükleme Slotları (${aktifBirimler.length} Birim)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),

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
