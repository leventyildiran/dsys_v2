import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/beyanname_provider.dart';
import '../services/beyanname_dogrulama.dart';

/// Beyanname ekranının üstündeki **kılavuz şeridi**.
///
/// Amaç (kullanıcı talebi): *rahatsız etmeden yönlendirmek, odağı korumak ve
/// hata yapmayı engellemek.* Bu yüzden şerit üç iş yapar:
///   1. **Yönlendir:** kaç hücre dolu, kaç hücre bekliyor.
///   2. **Hata yaptırma:** girilen veri tutarsızsa tek bir uyarı rozeti gösterir;
///      ayrıntı için tıklanabilir.
///   3. **Odakla:** tek vurgu rengi ve sakin yüzey; göz yorulmaz.
///
/// Renk anlamı `RENK_SISTEMI.md` ile aynıdır: `success` = tamam, `warning` =
/// bekleyen/dikkat, `danger` = hata, `info` = nötr bilgi, `primary` = odak.
/// Anlam **asla** yalnızca renge bırakılmaz; her rozette ikon + metin birlikte
/// gösterilir (erişilebilirlik).
class BeyannameGuideStrip extends StatelessWidget {
  const BeyannameGuideStrip({super.key, required this.provider});

  final BeyannameProvider provider;

  @override
  Widget build(BuildContext context) {
    final sayim = _sayim();

    final uyarilar = BeyannameDogrulama.denetle(
      kdv1: provider.kdv1Satirlari,
      tevkifat: provider.tevkifatKayitlari,
      muhtasar: provider.muhtasarSatirlari,
      hasiat600: provider.hasiat600Satirlari,
      oncekiDonemdenDevredenKdv: provider.oncekiAydanDevredenKdv,
      konfig: provider.konfig,
    );
    final hataSayisi = BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata);
    final dikkatSayisi = BeyannameDogrulama.sayi(uyarilar, UyariSeviye.dikkat);
    final sorunVar = hataSayisi > 0 || dikkatSayisi > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Yatay taşma olursa kaydırılır; dar ekranda hiçbir rozet kırpılmaz.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              icon: Icons.check_circle_rounded,
              label: 'Girilen: ${sayim.dolu} hücre',
              fg: AppColors.success,
              bg: AppColors.successSubtle,
              border: AppColors.successBorder,
            ),
            const SizedBox(width: 8),
            _chip(
              icon: Icons.pending_outlined,
              label: 'Boş / Bekleyen: ${sayim.bos} hücre',
              fg: AppColors.warning,
              bg: AppColors.warningSubtle,
              border: AppColors.warningBorder,
            ),
            if (sorunVar) ...[
              const SizedBox(width: 8),
              _chip(
                icon: hataSayisi > 0
                    ? Icons.error_rounded
                    : Icons.warning_amber_rounded,
                label: hataSayisi > 0
                    ? 'Dikkat: $hataSayisi hata, $dikkatSayisi uyarı'
                    : 'Dikkat: $dikkatSayisi uyarı',
                fg: hataSayisi > 0 ? AppColors.danger : AppColors.warning,
                bg: hataSayisi > 0
                    ? AppColors.dangerSubtle
                    : AppColors.warningSubtle,
                border: hataSayisi > 0
                    ? AppColors.dangerBorder
                    : AppColors.warningBorder,
                onTap: () => _denetimDialog(context, uyarilar),
              ),
            ],
            const SizedBox(width: 12),
            const Icon(Icons.keyboard_outlined,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text(
              'Hücreye tıklayıp sayıyı yazın; Enter veya Tab ile bir sonraki hücreye geçebilirsiniz.',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              '🟢 Dolu   🟡 Bekliyor   🔵 Aktif',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Doluluk özeti: yalnızca okunabilir girdiler sayılır.
  _DolulukSayimi _sayim() {
    int toplam = 0;
    int dolu = 0;

    for (final s in provider.kdv1Satirlari) {
      toplam += 4;
      if (s.hesaplananKdv10 > 0) dolu++;
      if (s.hesaplananKdv20 > 0) dolu++;
      if (s.indirilecekKdv10 > 0) dolu++;
      if (s.indirilecekKdv20 > 0) dolu++;
    }
    for (final d in provider.damgaSatirlari) {
      toplam++;
      if (d.damgaVergisi > 0) dolu++;
    }
    for (final h in provider.hasiat600Satirlari) {
      toplam += 3;
      if (h.kumulatifHasilat600 > 0) dolu++;
      if (h.aylikHasilat600 > 0) dolu++;
      if (h.krediKarti123 > 0) dolu++;
    }
    if (dolu > toplam) dolu = toplam;
    return _DolulukSayimi(dolu: dolu, toplam: toplam);
  }

  /// Tek bir bilgi rozeti (ikon + metin zorunlu).
  Widget _chip({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
    required Color border,
    VoidCallback? onTap,
  }) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: fg),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return Tooltip(
      message: 'Denetim sonuçlarını görüntüle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: body,
      ),
    );
  }

  /// Denetim sonuçlarını seviyeye göre gruplayıp gösteren iletişim kutusu.
  void _denetimDialog(BuildContext context, List<BeyannameUyari> uyarilar) {
    final hatalar = uyarilar.where((u) => u.seviye == UyariSeviye.hata).toList();
    final dikkatlar =
        uyarilar.where((u) => u.seviye == UyariSeviye.dikkat).toList();
    final bilgiler =
        uyarilar.where((u) => u.seviye == UyariSeviye.bilgi).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Giriş Denetimi'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (uyarilar.isEmpty)
                  const Text(
                    'Girilen verilerde tutarsızlık bulunmadı. Devam edebilirsiniz.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                if (hatalar.isNotEmpty)
                  _grup('Hatalar (düzeltilmeli)', hatalar,
                      AppColors.danger, Icons.error_rounded),
                if (dikkatlar.isNotEmpty)
                  _grup('Uyarılar (gözden geçirin)', dikkatlar,
                      AppColors.warning, Icons.warning_amber_rounded),
                if (bilgiler.isNotEmpty)
                  _grup('Bilgi', bilgiler, AppColors.info,
                      Icons.info_outline_rounded),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _grup(
    String baslik,
    List<BeyannameUyari> liste,
    Color renk,
    IconData ikon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 15, color: renk),
              const SizedBox(width: 6),
              Text(
                '$baslik (${liste.length})',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: renk),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...liste.map(
            (u) => Padding(
              padding: const EdgeInsets.only(left: 21, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.baslik,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    u.aciklama,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kılavuz şeridi için küçük doluluk özeti.
class _DolulukSayimi {
  const _DolulukSayimi({required this.dolu, required this.toplam});

  final int dolu;
  final int toplam;

  int get bos => toplam - dolu;
}
