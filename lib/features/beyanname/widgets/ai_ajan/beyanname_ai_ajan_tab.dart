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
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withValues(alpha: 0.08),
                blurRadius: 8,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '🤖 Akıllı Mizan & Beyanname Denetim Ajanı',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1B4B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF818CF8), width: 1),
                              ),
                              child: Text(
                                '${provider.seciliYil} / ${provider.seciliAy.toString().padLeft(2, '0')} Dönemi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Birimlerin Aylık Mizan, Yardımcı Mizan (Muavin), Yıllık Kümülatif Mizan ve Ek Belgelerini yükleyin. Sistem tek tek derinlemesine inceler, 10 senaryolu çapraz denetim yapar ve beyannamenizi hatasız doldurur.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(
                      isCalisiyor ? 'Derin Mizan Denetimi Yapılıyor...' : '🚀 Beyannameyi Otomatik Analiz Et ve Hazırla',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: (isCalisiyor || toplamEvrak == 0) ? 0 : 3,
                      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

        // ==================== GÜVENLİK VE DENETİM KALKANI REHBERİ ====================
        _buildGuvenlikRehberi(context),

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

  Widget _buildGuvenlikRehberi(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFAFE), Color(0xFFF1F5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                '🛡️ Yapay Zeka Denetim & Doğruluk Kalkanı',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF16A34A), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                    SizedBox(width: 4),
                    Text(
                      '10 Senaryo Aktif',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'Vision OCR & Çapraz Mutabakat',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0284C7), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_person_rounded, size: 12, color: Color(0xFF0369A1)),
                    SizedBox(width: 4),
                    Text(
                      '%100 İnsan Onaylı',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Yapay zeka asla tek başına karar verip doğrudan beyannameye yazmaz; okunan her veri 10 senaryolu matematiksel kural motorundan geçer ve onayınıza sunulur.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 800;
                      final item1 = _buildRehberKarti(
                        icon: Icons.calculate_rounded,
                        renk: const Color(0xFF0284C7),
                        bgRenk: const Color(0xFFF0F9FF),
                        baslik: '1. Matematiksel & Oran Kontrolü',
                        aciklama:
                            'AI\'ın okuduğu matrahlar otomatik olarak %20, %10 ve binde 9,48 ile çarpılarak kuruşu kuruşuna test edilir. 1 TL dahi tutarsızlık varsa sistem kırmızı uyarı verir, yanlış hesap beyannameye giremez.',
                      );
                      final item2 = _buildRehberKarti(
                        icon: Icons.document_scanner_rounded,
                        renk: const Color(0xFFD97706),
                        bgRenk: const Color(0xFFFFFBEB),
                        baslik: '2. Taranmış Fatura & OCR Mizan Çapraz Mutabakatı',
                        aciklama:
                            'Tarayıcıdan taranmış PDF ve fotoğraflar Vision AI ile optik okunur (OCR). Faturalar ile mizandaki 600/391 hesapları kıyaslanır; fatura kesilmiş ama mizana henüz yansımamışsa ekranda "Mizana Yansımamış Fatura" uyarısı çıkar.',
                      );
                      final item3 = _buildRehberKarti(
                        icon: Icons.account_balance_wallet_rounded,
                        renk: const Color(0xFF4F46E5),
                        bgRenk: const Color(0xFFEEF2FF),
                        baslik: '3. Yardımcı Mizan (Muavin) & %10 / %20 KDV Ayrımı',
                        aciklama:
                            'Ana mizan 391 ve 191 hesaplarını tek kalemde toplar. Yardımcı Mizan yuvasına dosya yüklendiğinde, AI 391.10 ve 391.20 alt hesaplarını net olarak ayrıştırır ve Senaryo 10 kuralıyla ana mizanla eşitliğini kuruşu kuruşuna denetler.',
                      );
                      final item4 = _buildRehberKarti(
                        icon: Icons.rule_rounded,
                        renk: const Color(0xFFDC2626),
                        bgRenk: const Color(0xFFFEF2F2),
                        baslik: '4. Muhasebe Mantık Filtresi (Ters Bakiye, 600 Borç & VKN)',
                        aciklama:
                            'Muhasebe kuralları gereği 191 asla alacak, 391 ve 600 asla borç veremez. AI yanlış sütun okursa ters bakiye dedektörü devreye girer. Ayrıca tüm VKN ve TCKN\'ler Gelir İdaresi algoritmalarıyla doğrulanır.',
                      );
                      final item5 = _buildRehberKarti(
                        icon: Icons.security_rounded,
                        renk: const Color(0xFF7C3AED),
                        bgRenk: const Color(0xFFFAF5FF),
                        baslik: '5. 10 Senaryolu Çapraz Denetim Kalkanı',
                        aciklama:
                            'Satır 45 POS tahsilatı 1.5 kat kuralı (izaha davet riski), 190 Devreden KDV geçmiş ay beyanname mutabakatı, aylık ve yıllık hasılat uyumu gibi 10 ayrı denetim senaryosu otomatik işletilir.',
                      );
                      final item6 = _buildRehberKarti(
                        icon: Icons.thumb_up_alt_rounded,
                        renk: const Color(0xFF15803D),
                        bgRenk: const Color(0xFFF0FDF4),
                        baslik: '6. Şeffaflık & İnsan Onayı (Human-in-the-Loop)',
                        aciklama:
                            'AI doğrudan beyannameye ASLA yazmaz. Önce "Nereden Nereye" şeffaf denetim raporu açılır. Siz gözünüzle inceleyip "Verileri Beyannameye Aktar" butonuna basana kadar hiçbir veri aktarılmaz. Aktarımdan sonra da tüm sayılar elle düzenlenebilir.',
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            item1,
                            const SizedBox(height: 10),
                            item2,
                            const SizedBox(height: 10),
                            item3,
                            const SizedBox(height: 10),
                            item4,
                            const SizedBox(height: 10),
                            item5,
                            const SizedBox(height: 10),
                            item6,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: item1),
                              const SizedBox(width: 12),
                              Expanded(child: item2),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: item3),
                              const SizedBox(width: 12),
                              Expanded(child: item4),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: item5),
                              const SizedBox(width: 12),
                              Expanded(child: item6),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ==================== ŞEFFAF OKUMA POLİTİKASI BANDI ====================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                          blurRadius: 8,
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
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified_rounded, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '🎯 Şeffaf Okuma Politikası: Sistem Neleri Okur, Neleri Okumaz?',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _hesapHaritasiDialogGoster(context),
                              icon: const Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                '🔍 Neyi Okur / Neyi Okumaz? (Detaylı Kılavuz)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, c) {
                            final isMobile = c.maxWidth < 750;
                            final solKutu = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sistem Neleri Otomatik Okur & Eşler:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '• 391 Hesap (%20 ve %10 KDV Alt Hesapları)\n'
                                    '• 191 İndirilecek KDV & 190 Devreden KDV\n'
                                    '• 600 Hasılat (Aylık Net ve Yıllık Kümülatif)\n'
                                    '• 123 Kredi Kartı POS Tahsilatları\n'
                                    '• 360.03.05 Damga Vergisi Kesintileri\n'
                                    '• Tevkifatlı Faturalar & Yardımcı Mizan (Muavin)',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.4, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );

                            final sagKutu = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sistem Neleri Okumaz / Size Bırakır:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '• Mizanda alt hesabı açılmamış istisnalar (KDVK 17 vb.)\n'
                                    '• Sisteme yüklenmemiş harici faturalar\n'
                                    '• Serbest fiş ve açıklamalı manuel giderler\n'
                                    '(Bu alanları kullanıcı dilediğinde beyanname masalarından elle girebilir veya değiştirebilir).',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );

                            if (isMobile) {
                              return Column(
                                children: [
                                  solKutu,
                                  const SizedBox(height: 10),
                                  sagKutu,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: solKutu),
                                const SizedBox(width: 12),
                                Expanded(child: sagKutu),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hesapHaritasiDialogGoster(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 780),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_tree_rounded, size: 22, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🔍 Beyanname Akıllı Ajanı — Detaylı Belge, Hesap & Kapsam Haritası',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Yapay zeka hiçbir veriyi uydurmaz. Aşağıda sistemin neleri okuduğunu, neleri kapsam dışı bıraktığını ve nasıl denetlediğini görebilirsiniz.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          tooltip: 'Kapat',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                          text: '✅ Neleri Okur? (9 Kapsam İçi Hesap)',
                        ),
                        Tab(
                          icon: Icon(Icons.do_not_disturb_on_rounded, size: 16, color: AppColors.warning),
                          text: '⚠️ Neleri Okumaz? (Kapsam Dışı / Manuel)',
                        ),
                        Tab(
                          icon: Icon(Icons.security_rounded, size: 16, color: AppColors.info),
                          text: '🛡️ 10 Senaryolu Çapraz Denetim Motoru',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // ------------------ SEKME 1: NELERİ OKUR? ------------------
                          SingleChildScrollView(
                            child: Column(
                              children: [
                          _buildHaritaKarti(
                            hesapKodu: '391.20',
                            hesapAdi: 'Hesaplanan KDV (%20)',
                            bakilanBelge: 'Aylık Mizan veya Yardımcı Mizan (Muavin)',
                            tarananVeri: '391.20 Alacak Bakiyesi (veya 391 Bakiye Satırı)',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 2 Satır 6 (%20 Matrah ve KDV)',
                            denetimKurali: 'Matrah = KDV / 0,20 formülüyle test edilir. 1 TL fark olursa Senaryo 4/10 kalkanı devreye girer.',
                            rozetRenk: AppColors.primary,
                            rozetBg: AppColors.primarySubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '391.10',
                            hesapAdi: 'Hesaplanan KDV (%10)',
                            bakilanBelge: 'Aylık Mizan veya Yardımcı Mizan (Muavin)',
                            tarananVeri: '391.10 Alacak Bakiyesi',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 2 Satır 4 (%10 Matrah ve KDV)',
                            denetimKurali: 'Matrah = KDV / 0,10 formülüyle test edilir. Yardımcı mizan varsa ana mizanla çapraz teyit edilir.',
                            rozetRenk: AppColors.primary,
                            rozetBg: AppColors.primarySubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '191',
                            hesapAdi: 'İndirilecek KDV (Dönem Borç Hareketi)',
                            bakilanBelge: 'Aylık Mizan / Yardımcı Mizan',
                            tarananVeri: '191 Hesabı Borç Hareketi / Dönem Borç Bakiyesi',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 5 Satır 34 (Bu Döneme Ait İndirilecek KDV)',
                            denetimKurali: 'Borç bakiyesi kontrol edilir. Muhasebe kuralı: 191 asla alacak bakiyesi veremez (Senaryo 6b).',
                            rozetRenk: AppColors.info,
                            rozetBg: AppColors.infoSubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '190',
                            hesapAdi: 'Devreden KDV (Açılış Borç Bakiyesi)',
                            bakilanBelge: 'Aylık Mizan (190 Borç Kalanı) & Önceki Ay Beyannamesi',
                            tarananVeri: '190 Hesabı Açılış / Devir Bakiyesi',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 5 Satır 33 (Önceki Dönemden Devreden KDV)',
                            denetimKurali: 'Sistemde kayıtlı önceki ay beyannamesinin kapanış devir KDV\'si ile kuruşu kuruşuna eşitliği test edilir (Senaryo 5).',
                            rozetRenk: AppColors.warning,
                            rozetBg: AppColors.warningSubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '600',
                            hesapAdi: 'Gelirler / Hasılat (Aylık & Kümülatif)',
                            bakilanBelge: 'Aylık Mizan & Yıllık Mizan',
                            tarananVeri: '600 Alacak Bakiyesi (Dönem İçi ve Yıl Kümülatifi)',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 8 (Teslim ve Hizmetlerin Karşılığını Teşkil Eden Bedel)',
                            denetimKurali: 'Aylık 600 + Geçmiş Aylar Hasılatı = Yıllık Kümülatif 600 eşitliği denetlenir (Senaryo 2). 600 asla borç veremez (Senaryo 6c).',
                            rozetRenk: AppColors.success,
                            rozetBg: AppColors.successSubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '123',
                            hesapAdi: 'Kredi Kartı / POS Tahsilatları',
                            bakilanBelge: 'Aylık Mizan (123 Borç Bakiyesi)',
                            tarananVeri: '123 Hesabı Dönem Borç Hareketi / Bakiyesi',
                            hedefMasa: 'KDV 1 Masası ➔ Tablo 11 Satır 45 (Kredi Kartı ile Tahsil Edilen Bedel)',
                            denetimKurali: 'POS tahsilatı aylık hasılatın 1.5 katını aşarsa GİB izaha davet risk uyarısı üretilir (Senaryo 1).',
                            rozetRenk: AppColors.neutral,
                            rozetBg: AppColors.neutralSubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: '360.03.05',
                            hesapAdi: 'Damga Vergisi (Döner Sermaye)',
                            bakilanBelge: 'Aylık Mizan (360.03.05 Alacak Bakiyesi)',
                            tarananVeri: 'Alacak Kalanı',
                            hedefMasa: 'Damga Vergisi Masası & 301 Kodu İcmali',
                            denetimKurali: 'Damga Vergisi / 0,00948 (Binde 9,48) matematiksel matrah sağlaması yapılır (Senaryo 7).',
                            rozetRenk: AppColors.primary,
                            rozetBg: AppColors.primarySubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: 'FATURA / SMM',
                            hesapAdi: 'Tevkifatlı Faturalar & Ekler',
                            bakilanBelge: 'PDF veya Taranmış Görüntü (OCR Destekli)',
                            tarananVeri: 'Firma Adı, VKN/TCKN, Matrah, KDV Tutarı, Tevkifat Oranı (9/10, 7/10, 5/10 vb.)',
                            hedefMasa: 'KDV 2 Masası ➔ Tablo 2 (Kesinti Listesi) & %20/%10 Birim Kırılımları',
                            denetimKurali: 'GİB 10 haneli VKN / 11 haneli TCKN algoritma sağlaması ve KDV x Oran matematik testi (Senaryo 8).',
                            rozetRenk: AppColors.danger,
                            rozetBg: AppColors.dangerSubtle,
                          ),
                          const SizedBox(height: 8),
                          _buildHaritaKarti(
                            hesapKodu: 'MUAVİN / Y.MİZAN',
                            hesapAdi: 'Yardımcı Mizan Alt Hesapları',
                            bakilanBelge: 'Yardımcı Mizan Yuvasına Yüklenen Belge',
                            tarananVeri: '391.10 (%10), 391.20 (%20), 191.10, 191.20, 600 Gelir Kırılımları',
                            hedefMasa: 'KDV 1 Oran Ayrımı ve KDV 2 Çapraz Teyidi',
                            denetimKurali: 'Senaryo 10: 391 ve 191 alt hesap toplamlarının ana mizan 391/191 ile birebir eşitliği çapraz test edilir.',
                            rozetRenk: AppColors.success,
                            rozetBg: AppColors.successSubtle,
                          ),
                        ],
                      ),
                    ),

                    // ---------------- SEKME 2: NELERİ OKUMAZ? -----------------
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildKapsamDisiKarti(
                            baslik: '1. Mizanda Alt Hesabı Bulunmayan Kanuni İstisnalar (KDVK 17 vb.)',
                            altBaslik: 'Örn: Eğitim, sağlık veya ihracat kapsamındaki vergiden muaf işlemler',
                            nedenOkumaz: 'Eğer birim bu gelirleri genel 600 hesabının içine karma şekilde kaydetmişse ve mizanda ayrı bir istisna kodu açmamışsa, yapay zeka bunları tahmini olarak ayıramaz.',
                            kullaniciNeYapmali: 'İstisna teslim tutarı KDV 1 Masasında "Tablo 8 - İstisnalar" satırına kullanıcı tarafından elle eklenmelidir.',
                          ),
                          const SizedBox(height: 8),
                          _buildKapsamDisiKarti(
                            baslik: '2. Sisteme Dosyası Yüklenmemiş Harici Faturalar',
                            altBaslik: 'Birimde kesilmiş fakat sisteme taranıp eklenmemiş tevkifat faturaları',
                            nedenOkumaz: 'AI yalnızca sisteme yüklenen PDF ve taranmış görüntüleri OCR ile okur. Sisteme sunulmayan fiziksel evrakları tahmin edemez.',
                            kullaniciNeYapmali: 'Eğer mizan ile faturalar arasında fark çıkarsa Senaryo 9 (Mizana Yansımamış Evrak) uyarısı verilir. Eksik faturalar "Diğer / Fatura" yuvasına yüklenmelidir.',
                          ),
                          const SizedBox(height: 8),
                          _buildKapsamDisiKarti(
                            baslik: '3. Muhtasar & SGK Personel Bordro Kesintileri',
                            altBaslik: '011 / 012 Ücret bordrosu ve GMSI kira stopajları',
                            nedenOkumaz: 'Bu modül münhasıran KDV 1, KDV 2 ve Damga Vergisi beyannamelerini hazırlamak üzere özelleştirilmiştir.',
                            kullaniciNeYapmali: 'KDV dışı muhtasar stopaj bildirimleri ilgili bordro/muhtasar modülünden takip edilmelidir.',
                          ),
                          const SizedBox(height: 8),
                          _buildKapsamDisiKarti(
                            baslik: '4. Muhasebe Fişlerindeki Serbest Metin Açıklamaları',
                            altBaslik: 'Yevmiye fişlerine yazılan subjektif veya resmi format dışı metinler',
                            nedenOkumaz: 'Sistem keyfi metin yorumları yapmaz; resmi mizan bakiyelerini ve fatura üzerindeki kurumsal VKN/Matrah alanlarını esas alır.',
                            kullaniciNeYapmali: 'Özel notlar ve birim açıklamaları beyanname ekranındaki manuel not alanına kaydedilebilir.',
                          ),
                        ],
                      ),
                    ),

                    // ---------------- SEKME 3: 10 SENARYOLU DENETİM ----------
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 1,
                            baslik: 'Kredi Kartı 123 Hesabı vs Satır 45 (İzaha Davet Riski)',
                            aciklama: 'Kredi kartı tahsilatlarının aylık hasılatın 1.5 katını aşıp aşmadığını test eder.',
                            ornekKural: '123 Bakiyesi > (600 Aylık x 1.5) ise GİB avans/taksit inceleme uyarısı üretilir.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 2,
                            baslik: 'Aylık Mizan + Önceki Aylar vs Yıllık Kümülatif 600 Mutabakatı',
                            aciklama: 'Önceki aylar toplamı ile bu ayki hasılatın yıllık mizanla eşitliğini denetler.',
                            ornekKural: 'Önceki Aylar Toplamı + Aylık 600 = Yıllık 600 Kümülatif eşitliği aranır (1 TL farkta hata verir).',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 3,
                            baslik: '600 Hasılat vs KDV 1 Matrahı (391) İstisna Kontrolü',
                            aciklama: 'Gelirler toplamının beyan edilen KDV matrahıyla uyumunu kontrol eder.',
                            ornekKural: '600 Gelirler > KDV 1 Matrahı ise aradaki farkın istisna teslim olup olmadığını sorgular.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 4,
                            baslik: 'Matrah x KDV Oranı Matematiksel Çarpım Sağlaması',
                            aciklama: '%20 ve %10 KDV hesaplamalarını kuruşu kuruşuna doğrular.',
                            ornekKural: 'Matrah = KDV / 0.20 ve Matrah = KDV / 0.10 denklemi test edilir.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 5,
                            baslik: '190 Devreden KDV Geçmiş Dönem Kapanış Uyuşmazlığı',
                            aciklama: 'Önceki ay beyannamesindeki devreden KDV ile mizan 190 açılış bakiyesini kıyaslar.',
                            ornekKural: 'Önceki Ay Devreden KDV == Bu Ay Mizan 190 Borç Bakiyesi (Fark varsa doğrudan uyarır).',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 6,
                            baslik: 'Muhasebe Mantık Filtresi (Ters Bakiye Dedektörü)',
                            aciklama: 'Hesapların borç/alacak çalışma kurallarını kontrol eder.',
                            ornekKural: '191 alacak veremez, 391 borç veremez, 600 borç veremez (Ters kayıt engellenir).',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 7,
                            baslik: '360.03.05 Damga Vergisi Binde 9,48 Matrah Sağlaması',
                            aciklama: 'Damga vergisinin resmi binde 9,48 oranıyla matematiksel uyumunu kontrol eder.',
                            ornekKural: 'Damga Matrahı == Damga Vergisi / 0.00948 sağlaması yapılır.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 8,
                            baslik: 'KDV 2 Tevkifat VKN / TCKN Checksum ve Oran Sağlaması',
                            aciklama: 'Fatura üzerindeki 10 haneli VKN veya 11 haneli TCKN algoritmasını ve kesinti oranını test eder.',
                            ornekKural: 'GİB Algoritması + KDV x Oran (9/10, 7/10 vb.) matematik sağlaması.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 9,
                            baslik: 'Taranmış Fatura OCR ile Mizandaki 600/391 Çapraz Karşılaştırması',
                            aciklama: 'Manuel taranan faturalar ile mizandaki gelirlerin örtüşüp örtüşmediğini denetler.',
                            ornekKural: 'Fatura kesilmiş ama mizana işlenmemişse "Mizana Yansımamış Evrak" uyarısı basılır.',
                          ),
                          const SizedBox(height: 8),
                          _buildDenetimSenaryoKarti(
                            senaryoNo: 10,
                            baslik: 'Ana Mizan & Yardımcı Mizan (Muavin) Çapraz Mutabakatı',
                            aciklama: 'Yardımcı mizandaki %10 ve %20 kırılımlarının ana mizanla eşitliğini kuruşu kuruşuna denetler.',
                            ornekKural: 'Yardımcı Mizan (391.10 + 391.20) == Ana Mizan 391 Alacak Bakiyesi (1 TL farkta hata verir).',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Anladım, Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  Widget _buildHaritaKarti({
    required String hesapKodu,
    required String hesapAdi,
    required String bakilanBelge,
    required String tarananVeri,
    required String hedefMasa,
    required String denetimKurali,
    required Color rozetRenk,
    required Color rozetBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rozetBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: rozetRenk.withAlpha(80)),
                ),
                child: Text(
                  hesapKodu,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rozetRenk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hesapAdi,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withAlpha(120),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHaritaSatir('📄 Bakılan Belge:', bakilanBelge),
                const SizedBox(height: 4),
                _buildHaritaSatir('🔍 Taranan Veri / Alan:', tarananVeri),
                const SizedBox(height: 4),
                _buildHaritaSatir('🎯 Aktarılan Masa & Satır:', hedefMasa),
                const SizedBox(height: 4),
                _buildHaritaSatir('🛡️ Güvenlik & Denetim Kuralı:', denetimKurali, isKural: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHaritaSatir(String baslik, String icerik, {bool isKural = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            baslik,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isKural ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            icerik,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isKural ? FontWeight.w600 : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKapsamDisiKarti({
    required String baslik,
    required String altBaslik,
    required String nedenOkumaz,
    required String kullaniciNeYapmali,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warningSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.block_rounded, size: 16, color: AppColors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      altBaslik,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withAlpha(120),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHaritaSatir('⚠️ Neden Okumaz?', nedenOkumaz),
                const SizedBox(height: 4),
                _buildHaritaSatir('✍️ Ne Yapılmalı?', kullaniciNeYapmali, isKural: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenetimSenaryoKarti({
    required int senaryoNo,
    required String baslik,
    required String aciklama,
    required String ornekKural,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'Senaryo $senaryoNo',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withAlpha(120),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHaritaSatir('🛡️ Kontrol Mantığı:', aciklama),
                const SizedBox(height: 4),
                _buildHaritaSatir('📋 Test Kuralı:', ornekKural, isKural: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRehberKarti({
    required IconData icon,
    required Color renk,
    required Color bgRenk,
    required String baslik,
    required String aciklama,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, bgRenk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: renk.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [renk, renk.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: renk.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: renk,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  aciklama,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF334155),
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
