import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/turkce_format.dart';
import '../../../birim/models/birim_model.dart';
import '../../models/beyanname_belge_model.dart';
import '../../models/beyanname_denetim_rapor_model.dart';
import '../../providers/beyanname_provider.dart';
import 'toplu_belge_yukleme_diyalogu.dart';
import 'ai_denetim_rapor_dialog.dart';
import 'tekil_fatura_ai_dialog.dart';

/// Birim başına yüklenen evrakları aşağıya doğru listeleyen,
/// tür değiştirmeye ve tek tek yönetmeye olanak tanıyan modern kart bileşeni.
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
    final belgeler = provider.getBirimBelgeleri(birimAdi);
    final hasAylik = belgeler.any((b) => b.slotTuru == BirimBelgeSlotTuru.aylikMizan);
    final hasYillik = belgeler.any((b) => b.slotTuru == BirimBelgeSlotTuru.yillikMizan);
    final isTamDolu = hasAylik && hasYillik;
    final yukluSayisi = belgeler.length;
    final birimSonuc = provider.getBirimAnalizSonucu(birimAdi);

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
          // 1. Başlık ve Üst Eylem Çubuğu
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

              // Bu birim için evrak seçme butonu
              TextButton.icon(
                onPressed: provider.isAiAjanCalisiyor
                    ? null
                    : () => _cokluDosyaSecVeOtomatikYerlestir(context),
                icon: const Icon(Icons.drive_folder_upload_rounded, size: 14),
                label: const Text(
                  'Çoklu Evrak Seç',
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
                _buildBirimAksiyonMenusu(context),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 2. Aşağıya Doğru Listelenen Evraklar Bölümü
          if (belgeler.isEmpty)
            _buildBosEvrakAlani(context)
          else
            _buildEvrakListesi(context, belgeler),

          // 3. Birim Analiz ve Denetim Özeti (Her Birim İçin Bağımsız Rapor ve Gösterge)
          if (birimSonuc != null) ...[
            const SizedBox(height: 8),
            _buildBirimAnalizOzeti(context, birimSonuc),
          ],
        ],
      ),
    );
  }

  /// Birim için çıkarılan verileri ve bağımsız rapor butonunu gösteren modern özet alanı
  Widget _buildBirimAnalizOzeti(BuildContext context, BirimMizanAnalizSonucu sonuc) {
    final denetimler = provider.getBirimDenetimKayitlari(birimAdi);
    final hasHata = denetimler.any((d) => d.seviye == DenetimSeviyesi.hata);
    final hasUyari = denetimler.any((d) => d.seviye == DenetimSeviyesi.uyari);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasHata
              ? AppColors.danger.withAlpha(120)
              : (hasUyari ? AppColors.warning.withAlpha(120) : AppColors.success.withAlpha(120)),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık ve Eylemler
          Row(
            children: [
              Icon(
                hasHata
                    ? Icons.warning_amber_rounded
                    : (hasUyari ? Icons.info_outline_rounded : Icons.check_circle_rounded),
                size: 15,
                color: hasHata
                    ? AppColors.danger
                    : (hasUyari ? AppColors.warning : AppColors.success),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '📊 $birimAdi Analiz Çıktısı & Birim Denetimi (${sonuc.analizTarihi.hour.toString().padLeft(2, "0")}:${sonuc.analizTarihi.minute.toString().padLeft(2, "0")})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Bu birime özel rapor butonu (Diğer birimlerle karışmaz)
              OutlinedButton.icon(
                onPressed: () {
                  final birimRapor = provider.getBirimRaporu(birimAdi);
                  if (birimRapor != null) {
                    AiDenetimRaporDialog.goster(
                      context,
                      rapor: birimRapor,
                      provider: provider,
                    );
                  }
                },
                icon: const Icon(Icons.description_outlined, size: 13),
                label: Text(
                  '$birimAdi Raporu (${denetimler.length})',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),

              // Masadan Geri Çek Butonu
              OutlinedButton.icon(
                onPressed: () => _onayliMasadanGeriCek(context),
                icon: const Icon(Icons.undo_rounded, size: 13, color: AppColors.danger),
                label: const Text(
                  'Masadan Geri Çek',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withAlpha(140), width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),

              // Masaya Aktar / Yenile Butonu
              FilledButton.tonalIcon(
                onPressed: () {
                  provider.birimVerileriniMasayaAktar(birimAdi);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ $birimAdi verileri masalara aktarıldı ve güncellendi.'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.sync_rounded, size: 13),
                label: const Text(
                  'Masaya Aktar',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Değer Kutucukları (KDV, 600, 123, Damga, Tevkifat)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildVeriKutusu(
                '600 Net Hasılat',
                TurkceFormat.para(sonuc.hasilat600Aylik),
                AppColors.primary,
              ),
              if (sonuc.krediKarti123 > 0)
                _buildVeriKutusu(
                  '123 POS (Borç Kalan)',
                  TurkceFormat.para(sonuc.krediKarti123),
                  AppColors.info,
                ),
              _buildVeriKutusu(
                'Hesaplanan KDV (391)',
                TurkceFormat.para(sonuc.toplamHesaplananKdv),
                AppColors.textPrimary,
              ),
              _buildVeriKutusu(
                'İndirilecek KDV (191)',
                TurkceFormat.para(sonuc.toplamIndirilecekKdv),
                AppColors.textSecondary,
              ),
              if (sonuc.damgaVergisi360 > 0)
                _buildVeriKutusu(
                  '360 Damga',
                  TurkceFormat.para(sonuc.damgaVergisi360),
                  AppColors.neutral,
                ),
              if (sonuc.muhtasarGelir360 > 0)
                _buildVeriKutusu(
                  'Muhtasar GV (360.01)',
                  TurkceFormat.para(sonuc.muhtasarGelir360),
                  AppColors.warning,
                ),
              if (sonuc.muhtasarDamga360 > 0)
                _buildVeriKutusu(
                  'Muhtasar DV (360.03.01)',
                  TurkceFormat.para(sonuc.muhtasarDamga360),
                  AppColors.warning,
                ),
              if (sonuc.tevkifatFaturalari.isNotEmpty)
                _buildVeriKutusu(
                  'Tevkifat Faturası',
                  '${sonuc.tevkifatFaturalari.length} Adet',
                  AppColors.success,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVeriKutusu(String etiket, String deger, Color vurgu) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiket, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
          const SizedBox(height: 1),
          Text(
            deger,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: vurgu),
          ),
        ],
      ),
    );
  }

  /// Evrak yüklenmediğinde gösterilen sade seçim alanı
  Widget _buildBosEvrakAlani(BuildContext context) {
    return InkWell(
      onTap: () => _cokluDosyaSecVeOtomatikYerlestir(context),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withAlpha(40),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_rounded, size: 15, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Bu birim için mizanları seçin (Aylık/Yıllık Mizan, Yardımcı Defter, varsa Tevkifat Faturası)...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yüklenen evrakların aşağıya doğru listelendiği ana gövde
  Widget _buildEvrakListesi(BuildContext context, List<BirimYuklenenBelge> belgeler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < belgeler.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _buildTekilBelgeSatiri(context, belgeler[i]),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _cokluDosyaSecVeOtomatikYerlestir(context),
            icon: const Icon(Icons.add_rounded, size: 13),
            label: const Text(
              '+ Bu Birime Başka Evrak Ekle',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  /// Aşağıya doğru listelenen tek bir evrak satırı
  Widget _buildTekilBelgeSatiri(BuildContext context, BirimYuklenenBelge b) {
    final isFaturaSlot = b.slotTuru == BirimBelgeSlotTuru.diger || b.slotTuru == BirimBelgeSlotTuru.faturaListesi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withAlpha(150)),
      ),
      child: Row(
        children: [
          // Dosya Türü İkonu
          Icon(
            b.isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
            size: 15,
            color: b.isPdf ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(width: 8),

          // Dosya Adı ve Boyutu
          Expanded(
            child: Tooltip(
              message: '${b.dosyaAdi} (${b.okunabilirBoyut})',
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      b.dosyaAdi,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${b.okunabilirBoyut})',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Tekil AI Fatura Çözümleme Butonu (İstenen tekil AI okuma)
          if (isFaturaSlot)
            FilledButton.tonalIcon(
              onPressed: () => TekilFaturaAiDialog.goster(
                context,
                birimAdi: birimAdi,
                belge: b,
                provider: provider,
              ),
              icon: const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
              label: const Text(
                'AI ile Faturayı Çöz',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySubtle,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
              tooltip: 'Bu Belgeyi AI ile Çözümle',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => TekilFaturaAiDialog.goster(
                context,
                birimAdi: birimAdi,
                belge: b,
                provider: provider,
              ),
            ),

          const SizedBox(width: 6),

          // Yuva / Tür Değiştirme Butonu (Dropdown Pill)
          _buildSlotSeciciPill(context, b),
          const SizedBox(width: 6),

          // Başka Birime Taşı Butonu (Menü)
          _buildBirimDegistirMenusu(context, b),
          const SizedBox(width: 4),

          // Silme Butonu
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.neutral),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            tooltip: 'Bu Belgeyi Kaldır',
            hoverColor: AppColors.dangerSubtle,
            onPressed: () => provider.tekilBelgeSil(birimAdi: birimAdi, belgeId: b.id),
          ),
        ],
      ),
    );
  }

  /// Evrak slotunu (Aylık/Yıllık/Yardımcı/Fatura) gösteren ve tek tıkla değiştirmeyi sağlayan etiket
  Widget _buildSlotSeciciPill(BuildContext context, BirimYuklenenBelge b) {
    Color bg;
    Color fg;

    switch (b.slotTuru) {
      case BirimBelgeSlotTuru.aylikMizan:
        bg = AppColors.primarySubtle;
        fg = AppColors.primary;
        break;
      case BirimBelgeSlotTuru.yillikMizan:
        bg = AppColors.infoSubtle;
        fg = AppColors.info;
        break;
      case BirimBelgeSlotTuru.yardimciMizan:
        bg = AppColors.warningSubtle;
        fg = AppColors.warning;
        break;
      case BirimBelgeSlotTuru.diger:
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        break;
    }

    return PopupMenuButton<BirimBelgeSlotTuru>(
      tooltip: 'Belge Türünü Değiştir',
      initialValue: b.slotTuru,
      onSelected: (yeniSlot) {
        provider.belgeSlotDegistir(
          birimAdi: birimAdi,
          belgeId: b.id,
          yeniSlot: yeniSlot,
        );
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: BirimBelgeSlotTuru.aylikMizan,
          child: Text('Aylık Mizan', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: BirimBelgeSlotTuru.yillikMizan,
          child: Text('Yıllık Mizan', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: BirimBelgeSlotTuru.yardimciMizan,
          child: Text('Yardımcı Mizan (Muavin)', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem(
          value: BirimBelgeSlotTuru.diger,
          child: Text('Fatura / Ek Evrak', style: TextStyle(fontSize: 12)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: fg.withAlpha(80), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              b.slotTuru.baslik,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: fg),
          ],
        ),
      ),
    );
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
            content: Text('Dosya seçme hatası: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Birim kartı üst menüsü: Masadan Geri Çek, Belgeleri Temizle veya Tam Sıfırla
  Widget _buildBirimAksiyonMenusu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Birim İşlemleri & Sıfırlama',
      icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.neutral),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      onSelected: (secim) {
        if (secim == 'masadan_geri_cek') {
          _onayliMasadanGeriCek(context);
        } else if (secim == 'belgeleri_temizle') {
          provider.birimiTamamenSifirla(birimAdi, masalariDaTemizle: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ $birimAdi yüklenen belgeleri ve analiz taslağı temizlendi.'),
              backgroundColor: AppColors.neutral,
            ),
          );
        } else if (secim == 'tam_sifirla') {
          _onayliBirimiTamSifirla(context);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'masadan_geri_cek',
          child: Row(
            children: [
              Icon(Icons.undo_rounded, size: 15, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Masadan Geri Çek (KDV, 600, Damga)', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'belgeleri_temizle',
          child: Row(
            children: [
              Icon(Icons.folder_delete_outlined, size: 15, color: AppColors.neutral),
              SizedBox(width: 8),
              Text('Yüklenen Belgeleri Kaldır', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'tam_sifirla',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 15, color: AppColors.danger),
              SizedBox(width: 8),
              Text(
                'Tam Sıfırla (Belgeler + Masalar)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bir evrak yanlış birime yüklendiyse tek tıkla başka birime taşımayı sağlar
  Widget _buildBirimDegistirMenusu(BuildContext context, BirimYuklenenBelge b) {
    final digerBirimler = <String>{};
    for (final k in provider.kdv1Satirlari) {
      if (k.birimAdi.trim().isNotEmpty) digerBirimler.add(k.birimAdi);
    }
    for (final def in BirimModel.varsayilanBirimler) {
      digerBirimler.add(def.ad);
    }
    digerBirimler.remove(birimAdi);
    final sortedBirimler = digerBirimler.toList()..sort();

    return PopupMenuButton<String>(
      tooltip: 'Yanlış Birim Seçildiyse Başka Birime Taşı',
      icon: const Icon(Icons.drive_file_move_outlined, size: 15, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      onSelected: (hedefBirim) {
        provider.belgeBiriminiDegistir(
          eskiBirimAdi: birimAdi,
          yeniBirimAdi: hedefBirim,
          belgeId: b.id,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "${b.dosyaAdi}" $hedefBirim birimine taşındı.'),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Belgeyi Hangi Birime Taşımak İstiyorsunuz?',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        const PopupMenuDivider(),
        ...sortedBirimler.map(
          (hedef) => PopupMenuItem<String>(
            value: hedef,
            child: Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hedef,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Masadan geri çekme onay diyaloğu
  Future<void> _onayliMasadanGeriCek(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(child: Text('$birimAdi Verilerini Masadan Geri Çek')),
          ],
        ),
        content: Text(
          '$birimAdi için KDV 1, Damga Vergisi, 600 Hasılat ve Tevkifat masalarındaki kayıtlar sıfırlanacaktır.\n\n'
          'Yüklediğiniz evraklar ve analiz raporunuz korunur.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: AppColors.white),
            child: const Text('Geri Çek'),
          ),
        ],
      ),
    );

    if (onay == true && context.mounted) {
      provider.birimMasalariniGeriCek(birimAdi);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('↩ $birimAdi verileri masalardan geri çekildi ve sıfırlandı.'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  /// Birimi tamamen sıfırlama onay diyaloğu
  Future<void> _onayliBirimiTamSifirla(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text('$birimAdi Birimini Tam Sıfırla')),
          ],
        ),
        content: const Text(
          'Yanlış birim seçimi veya sıfırdan yeniden okuma için:\n\n'
          '• Yüklenen tüm mizan ve evraklar kaldırılacak,\n'
          '• Yapılan analiz ve denetim sonuçları silinecek,\n'
          '• Masalara aktarılan tüm satırlar sıfırlanacaktır.\n\n'
          'Devam etmek istiyor musunuz?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.white),
            child: const Text('Tam Sıfırla'),
          ),
        ],
      ),
    );

    if (onay == true && context.mounted) {
      provider.birimiTamamenSifirla(birimAdi, masalariDaTemizle: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $birimAdi tamamen sıfırlandı. Yeniden temiz okuma yapabilirsiniz.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
