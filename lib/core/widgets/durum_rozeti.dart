import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Durum rozetinin anlamı. Her tip, [`AppColors`](../theme/app_colors.dart:1)
/// içindeki tek bir durum rengiyle eşleşir (tek anlam = tek renk).
///
/// - [basarili] → onaylandı / tamamlandı / eşleşti
/// - [uyari]    → dikkat / onay bekliyor / eksik alan
/// - [hata]     → hata / reddedildi / gecikmiş / tutarsız
/// - [bilgi]    → nötr bilgi / ipucu
/// - [notr]     → pasif / devre dışı / bilgi yok
enum DurumTipi { basarili, uyari, hata, bilgi, notr }

/// [DurumTipi] → renk/ikon eşlemesi. Renkler asla burada ham yazılmaz,
/// yalnızca [`AppColors`](../theme/app_colors.dart:1) tokenları kullanılır.
extension DurumTipiStil on DurumTipi {
  /// Metin ve ikon rengi.
  Color get metinRengi => switch (this) {
        DurumTipi.basarili => AppColors.success,
        DurumTipi.uyari => AppColors.warning,
        DurumTipi.hata => AppColors.danger,
        DurumTipi.bilgi => AppColors.info,
        DurumTipi.notr => AppColors.neutral,
      };

  /// Rozet dolgu (arka plan) rengi.
  Color get zeminRengi => switch (this) {
        DurumTipi.basarili => AppColors.successSubtle,
        DurumTipi.uyari => AppColors.warningSubtle,
        DurumTipi.hata => AppColors.dangerSubtle,
        DurumTipi.bilgi => AppColors.infoSubtle,
        DurumTipi.notr => AppColors.neutralSubtle,
      };

  /// Rozet kenarlık rengi.
  Color get kenarlikRengi => switch (this) {
        DurumTipi.basarili => AppColors.successBorder,
        DurumTipi.uyari => AppColors.warningBorder,
        DurumTipi.hata => AppColors.dangerBorder,
        DurumTipi.bilgi => AppColors.infoBorder,
        DurumTipi.notr => AppColors.border,
      };

  /// Varsayılan ikon.
  IconData get ikon => switch (this) {
        DurumTipi.basarili => Icons.check_circle_outline,
        DurumTipi.uyari => Icons.error_outline,
        DurumTipi.hata => Icons.cancel_outlined,
        DurumTipi.bilgi => Icons.info_outline,
        DurumTipi.notr => Icons.remove_circle_outline,
      };
}

/// Anlamlı durum rozeti. Renk = durum. Süs amaçlı kullanılmaz.
///
/// ```dart
/// DurumRozeti(etiket: 'Onaylandı', tip: DurumTipi.basarili, ikonGoster: true)
/// ```
class DurumRozeti extends StatelessWidget {
  const DurumRozeti({
    super.key,
    required this.etiket,
    this.tip = DurumTipi.notr,
    this.ikonGoster = false,
    this.dolgu = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  /// Rozet metni (ör. "Onaylandı", "Eksik", "Reddedildi").
  final String etiket;

  /// Durum tipi; rengi ve varsayılan ikonu belirler.
  final DurumTipi tip;

  /// Metnin solunda ikon gösterilsin mi.
  final bool ikonGoster;

  /// İç boşluk.
  final EdgeInsetsGeometry dolgu;

  @override
  Widget build(BuildContext context) {
    final stil = tip;
    return Container(
      padding: dolgu,
      decoration: BoxDecoration(
        color: stil.zeminRengi,
        border: Border.all(color: stil.kenarlikRengi),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikonGoster) ...[
            Icon(stil.ikon, size: 13, color: stil.metinRengi),
            const SizedBox(width: 4),
          ],
          Text(
            etiket,
            style: TextStyle(
              color: stil.metinRengi,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// **Nötr** etiket (birim, rol, tür). Kural gereği bunlar renkle ayırt EDİLMEZ;
/// metinle ayırt edilir. Yalnızca gerçek durum bilgisi varsa [DurumRozeti] kullan.
class NotrEtiket extends StatelessWidget {
  const NotrEtiket({
    super.key,
    required this.etiket,
    this.dolgu = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  final String etiket;
  final EdgeInsetsGeometry dolgu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: dolgu,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        etiket,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
