import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/beyanname_provider.dart';

/// Toplu mizan ve evrak yükleme sırasında kullanıcıya ilerleme durumunu gösteren
/// ve UI kitlenmesini önleyen modern dialog bileşeni.
class TopluBelgeYuklemeDiyalogu {
  static Future<void> calistir({
    required BuildContext context,
    required BeyannameProvider provider,
    required List<({String dosyaAdi, int dosyaBoyutu, String dosyaUzantisi, Uint8List? dosyaBytes})> dosyalar,
    required List<String> aktifBirimler,
    String? varsayilanBirimAdi,
  }) async {
    if (dosyalar.isEmpty) return;

    int currentStep = 0;
    final totalSteps = dosyalar.length;
    String currentFileName = dosyalar.first.dosyaAdi;
    void Function(void Function())? dialogSetState;
    bool dialogOpen = true;

    // İlerleme dialogunu başlat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            final progress = totalSteps > 0 ? (currentStep / totalSteps).clamp(0.0, 1.0) : 0.0;
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Belgeler İnceleniyor ve Eşleştiriliyor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStep == 0
                          ? 'Hazırlanıyor...'
                          : 'İnceleniyor: $currentFileName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$currentStep / $totalSteps Belge',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '%${(progress * 100).toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      dialogOpen = false;
    });

    try {
      final eslesenler = await provider.topluBelgeOtomatikEslestirVeYukle(
        dosyalar: dosyalar,
        aktifBirimler: aktifBirimler,
        varsayilanBirimAdi: varsayilanBirimAdi,
        onProgress: (current, total, dosyaAdi) {
          currentStep = current;
          currentFileName = dosyaAdi;
          dialogSetState?.call(() {});
        },
      );

      // Dialogu güvenli şekilde kapat
      if (dialogOpen && context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${eslesenler.length} belge otomatik sınıflandırıldı ve ilgili birim yuvalarına yerleştirildi.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (dialogOpen && context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toplu evrak yükleme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
