import 'package:flutter/material.dart';

import '../models/taksit_model.dart';
import '../services/taksit_onay_akisi.dart';

/// Kompakt onay hattı göstergesi (6 adım).
class TaksitPipeline extends StatelessWidget {
  const TaksitPipeline({
    super.key,
    required this.durum,
    this.compact = false,
  });

  final TaksitDurum durum;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final aktif = TaksitOnayAkisi.adimIndeksi(durum);
    final adimlar = TaksitOnayAkisi.onayHatti;

    if (compact) {
      return Row(
        children: List.generate(adimlar.length, (i) {
          final renk = _adimRenk(i, aktif, durum);
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < adimlar.length - 1 ? 3 : 0),
              decoration: BoxDecoration(
                color: renk,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(adimlar.length, (i) {
          final d = adimlar[i];
          final tamam = i < aktif;
          final suAn = i == aktif;
          final renk = _adimRenk(i, aktif, durum);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: renk.withValues(alpha: suAn ? 1 : 0.25),
                    child: tamam
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: suAn ? Colors.white : renk,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _kisalt(d.displayName),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: suAn ? FontWeight.w700 : FontWeight.w500,
                      color: suAn ? renk : Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
              if (i < adimlar.length - 1)
                Container(
                  width: 20,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
                  color: i < aktif ? renk : Colors.blueGrey.shade200,
                ),
            ],
          );
        }),
      ),
    );
  }

  String _kisalt(String ad) {
    if (ad.length <= 8) return ad;
    return ad.split(' ').first;
  }

  Color _adimRenk(int i, int aktif, TaksitDurum durum) {
    if (durum == TaksitDurum.gecikti) return Colors.red.shade600;
    if (i < aktif) return Colors.green.shade600;
    if (i == aktif) {
      switch (durum) {
        case TaksitDurum.taslak:
          return Colors.grey.shade600;
        case TaksitDurum.mudurOnayinda:
        case TaksitDurum.merkezOnayinda:
          return Colors.orange.shade700;
        case TaksitDurum.ykGundeminde:
          return Colors.purple.shade600;
        case TaksitDurum.onaylandi:
          return Colors.green.shade700;
        case TaksitDurum.odendi:
          return Colors.blue.shade700;
        case TaksitDurum.gecikti:
          return Colors.red.shade600;
      }
    }
    return Colors.blueGrey.shade200;
  }
}
