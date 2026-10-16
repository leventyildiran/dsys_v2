import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/beyanname_provider.dart';

/// Toplu mizan ve evrak yükleme işlemini başlatan ve canlı siyah terminal akışına yönlendiren bileşen.
class TopluBelgeYuklemeDiyalogu {
  static Future<void> calistir({
    required BuildContext context,
    required BeyannameProvider provider,
    required List<({String dosyaAdi, int dosyaBoyutu, String dosyaUzantisi, Uint8List? dosyaBytes})> dosyalar,
    required List<String> aktifBirimler,
    String? varsayilanBirimAdi,
  }) async {
    if (dosyalar.isEmpty) return;

    try {
      final eslesenler = await provider.topluBelgeOtomatikEslestirVeYukle(
        dosyalar: dosyalar,
        aktifBirimler: aktifBirimler,
        varsayilanBirimAdi: varsayilanBirimAdi,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${eslesenler.length} evrak incelendi ve ilgili birim listelerine aşağıya doğru yerleştirildi.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
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
