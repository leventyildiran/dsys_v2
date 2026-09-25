import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import 'danismanlik_form_screen.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../providers/danismanlik_detay_provider.dart';
import '../services/danismanlik_service.dart';
import '../widgets/danismanlik_layout.dart';
import '../widgets/taksit_pipeline.dart';
import '../services/taksit_onay_akisi.dart';
import '../../../core/theme/app_colors.dart';

class DanismanlikDetayScreen extends StatelessWidget {
  const DanismanlikDetayScreen({super.key, required this.danismanlik});

  final DanismanlikModel danismanlik;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DanismanlikDetayProvider(danismanlik),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DanismanlikLayout.kompaktBaslik(
              baslik: danismanlik.firmaUnvan ?? 'Danışmanlık Detay',
              altBaslik: danismanlik.konusu,
              aksiyon: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Geri',
              ),
            ),
            const Expanded(child: _DanismanlikDetayBody()),
          ],
        ),
      ),
    );
  }
}

/// Firestore'dan id ile danışmanlık yükler.
class DanismanlikDetayLoader extends StatelessWidget {
  const DanismanlikDetayLoader({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DanismanlikModel?>(
      future: DanismanlikService().getById(id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Danışmanlık kaydı bulunamadı.'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/danismanlik'),
                    child: const Text('Listeye dön'),
                  ),
                ],
              ),
            ),
          );
        }
        return DanismanlikDetayScreen(danismanlik: snap.data!);
      },
    );
  }
}

class _DanismanlikDetayBody extends StatelessWidget {
  const _DanismanlikDetayBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DanismanlikDetayProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSozlesmeAsamasi(context, provider),
              const SizedBox(height: 24),
              _buildUygulamaAsamasi(context, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSozlesmeAsamasi(BuildContext context, DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final bool hasYkOnay = d.ykKararNo != null && d.ykKararNo!.trim().isNotEmpty;
    final String birimAdi = d.birimKisaAd?.isNotEmpty == true
        ? d.birimKisaAd!
        : 'Bağlı Birim';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Aşama: Danışmanlık Sözleşmesi & Kurul Onayları',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Bağlı birim teklif yazısı, BYK kararı ve Döner Sermaye Yürütme Kurulu (YKK) onay kaydı',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showKurulKararlariDuzenleDialog(context, provider),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Karar & Evrak Bilgilerini Düzenle', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.borderStrong),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              tooltip: 'Tüm Sözleşmeyi Düzenle',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DanismanlikFormScreen(mevcutDanismanlik: d),
                ));
                if (context.mounted) {
                  context.replace('/danismanlik/detay/${d.id}');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              tooltip: 'Sözleşmeyi Sil',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showDeleteDialog(context, d),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol Kısım: Sözleşme Özeti ve Firma Künyesi
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.apartment_rounded, size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 5),
                              Text(
                                birimAdi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SÖZLEŞME ÖZETİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d.firmaUnvan?.isNotEmpty == true ? d.firmaUnvan! : 'Firma Belirtilmemiş',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.konusu,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(Icons.category_outlined, d.danismanlikTuru.displayName),
                        _buildInfoChip(Icons.timer_outlined, '${d.suresi} Ay'),
                        _buildInfoChip(Icons.percent_rounded, 'KDV %${d.kdvOrani}'),
                        if (d.personeller.isNotEmpty)
                          _buildInfoChip(Icons.people_alt_outlined, '${d.personeller.length} Akademisyen'),
                      ],
                    ),
                    if (d.personeller.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Görevli Akademisyenler:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: d.personeller.map((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${p.personel.unvan} ${p.personel.adSoyad}${p.faaliyetPuani > 0 ? " (${p.faaliyetPuani.toInt()} Puan)" : ""}',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const Divider(height: 20, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sözleşme Toplam Bedeli (+KDV)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              TurkceFormat.para(d.toplamTutar),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(width: 1, height: 210, color: AppColors.border),
              const SizedBox(width: 18),
              // Sağ Kısım: Kurul Kararları ve EBYS Evrak Bilgileri
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'KURUL KARARLARI & EBYS EVRAK TAKİBİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (hasYkOnay)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.successSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.successBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'YKK Onaylı',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warningSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.warningBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top_rounded, size: 12, color: AppColors.warning),
                                SizedBox(width: 4),
                                Text(
                                  'YKK Onayı Bekliyor',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kart 1: Bağlı Birim Üst Yazı (EBYS)
                        Expanded(
                          child: _buildDecisionCard(
                            title: 'Birim Üst Yazı (EBYS)',
                            icon: Icons.mark_email_read_outlined,
                            accentColor: AppColors.info,
                            items: [
                              _DecisionItem('Birim', birimAdi),
                              _DecisionItem(
                                'Evrak Sayısı',
                                d.birimEvrakSayisi?.isNotEmpty == true ? d.birimEvrakSayisi! : 'Belirtilmedi',
                                isHighlight: d.birimEvrakSayisi?.isNotEmpty == true,
                              ),
                              _DecisionItem(
                                'Evrak Tarihi',
                                d.birimEvrakTarihi?.isNotEmpty == true ? d.birimEvrakTarihi! : '-',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Kart 2: Birim Yönetim Kurulu (BYK)
                        Expanded(
                          child: _buildDecisionCard(
                            title: 'Birim YK Kararı (BYK)',
                            icon: Icons.account_balance_outlined,
                            accentColor: AppColors.warning,
                            items: [
                              _DecisionItem(
                                'Karar No',
                                d.birimKararNo?.isNotEmpty == true ? d.birimKararNo! : 'Belirtilmedi',
                                isHighlight: d.birimKararNo?.isNotEmpty == true,
                              ),
                              _DecisionItem(
                                'Karar Tarihi',
                                d.birimKararTarihi?.isNotEmpty == true ? d.birimKararTarihi! : '-',
                              ),
                              if (d.birimToplantiSayisi?.isNotEmpty == true)
                                _DecisionItem('Toplantı No', d.birimToplantiSayisi!),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Kart 3: Yürütme Kurulu Kararı (YKK)
                        Expanded(
                          child: _buildDecisionCard(
                            title: 'Merkez Kararı (YKK)',
                            icon: Icons.gavel_rounded,
                            accentColor: hasYkOnay ? AppColors.success : AppColors.neutral,
                            items: [
                              _DecisionItem(
                                'Karar No',
                                d.ykKararNo?.isNotEmpty == true ? d.ykKararNo! : 'Bekliyor',
                                isHighlight: hasYkOnay,
                                highlightColor: hasYkOnay ? AppColors.success : AppColors.warning,
                              ),
                              _DecisionItem(
                                'Karar Tarihi',
                                d.ykKararTarihi?.isNotEmpty == true ? d.ykKararTarihi! : '-',
                              ),
                              if (d.ykToplantiSayisi?.isNotEmpty == true)
                                _DecisionItem('Toplantı No', d.ykToplantiSayisi!),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bu bilgiler bağlı birim teklifi ve Yürütme Kurulu sözleşme kabul kararının resmi kaydıdır. '
                              'Dağıtım havuzu kararları aşağıda ilgili havuz kartında takip edilir.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                            ),
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
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUygulamaAsamasi(BuildContext context, DanismanlikDetayProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              '2. Aşama: Hizmet Uygulama ve Dağıtım Havuzları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _yeniTaksitDialog(context, provider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni Havuz Ekle', style: TextStyle(fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildBakiyeCari(provider),
        const SizedBox(height: 12),
        if (provider.taksitler.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Henüz bir ödeme havuzu başlatılmadı.', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Hizmet verildikten ve fatura kesildikten sonra dağıtım havuzu ekleyebilirsiniz.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ...provider.taksitler.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildTaksitCard(context, t, provider),
              )),
      ],
    );
  }

  Widget _buildTaksitCard(BuildContext context, TaksitModel taksit, DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final islemAyi = DanismanlikDetayProvider.guncelIslemAyi();
    final akis = IsAkisiMotoru.forTur(d.tur);

    final bool isDagitimAsamasi = akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.dagitimHesaplandi);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primary,
                  child: Text('${taksit.ayNo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text('${taksit.ayNo}. Dağıtım Havuzu', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    taksit.durum.displayName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: taksit.durum == TaksitDurum.ykOnaylandi || taksit.durum == TaksitDurum.odendi ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
                const Spacer(),
                const Text('Brüt Tutar: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(TurkceFormat.para(taksit.brutTutar), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                  onPressed: () => provider.taksitSil(taksit.id),
                  tooltip: 'Havuzu Sil',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: TaksitPipeline(durum: taksit.durum, tur: d.tur, compact: true),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildDurumCheckbox(
                  label: 'Fatura Kesildi / Dekont Alındı',
                  value: akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.faturaKesildi),
                  isEnabled: taksit.durum == TaksitDurum.taslak || taksit.durum == TaksitDurum.faturaKesildi,
                  onChanged: (val) {
                    if (val == true) {
                      provider.durumIlerlet(taksit);
                    } else {
                      provider.durumGeriAl(taksit);
                    }
                  },
                ),
                const SizedBox(width: 32),
                _buildDurumCheckbox(
                  label: 'Para Döner Sermaye Hesabına Geldi',
                  value: akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.paraGeldi),
                  isEnabled: taksit.durum == TaksitDurum.faturaKesildi || taksit.durum == TaksitDurum.paraGeldi,
                  onChanged: (val) {
                    if (val == true) {
                      provider.durumIlerlet(taksit);
                    } else {
                      provider.durumGeriAl(taksit);
                    }
                  },
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          if (isDagitimAsamasi)
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.orange.shade50.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_document, size: 20, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text('Bu Dağıtıma Özel Kurul Kararları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _TaksitKararForm(taksit: taksit, provider: provider),
                ],
              ),
            ),
          
          if (isDagitimAsamasi)
            const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (akis.oncekiDurum(taksit.durum) != null)
                  TextButton.icon(
                    onPressed: provider.isLoading ? null : () => provider.durumGeriAl(taksit),
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('İşlemi Geri Al'),
                  ),
                const Spacer(),
                if (taksit.durum == TaksitDurum.dagitimHesaplandi || taksit.durum == TaksitDurum.ykOnaylandi || taksit.durum == TaksitDurum.odendi)
                  OutlinedButton.icon(
                    onPressed: () {
                      context.push('/danismanlik/dagitim', extra: DanismanlikRouteExtra(model: d, taksit: taksit));
                    },
                    icon: const Icon(Icons.table_view, size: 16),
                    label: const Text('Dağıtım Tablosuna Git'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                  ),
                const SizedBox(width: 12),
                if (taksit.durum == TaksitDurum.dagitimHesaplandi)
                  ElevatedButton.icon(
                    onPressed: provider.isLoading ? null : () => provider.dagitimiHesaplaVeKaydet(taksit, islemAyi, false),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Baştan Hesapla (Sıfırla)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                    ),
                  ),
                const SizedBox(width: 12),
                if (akis.sonrakiDurum(taksit.durum) != null)
                  ElevatedButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            await provider.durumIlerlet(taksit);
                            if (context.mounted && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!), backgroundColor: Colors.red));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                    ),
                    icon: Icon(akis.sonrakiDurum(taksit.durum) == TaksitDurum.odendi ? Icons.check_circle : Icons.arrow_forward, size: 18),
                    label: Text(akis.ilerletEtiketi(taksit.durum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumCheckbox({
    required String label,
    required bool value,
    required bool isEnabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: isEnabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: isEnabled ? onChanged : null,
                activeColor: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled ? Colors.blueGrey.shade800 : Colors.blueGrey.shade300,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniTaksitDialog(BuildContext context, DanismanlikDetayProvider provider) {
    final ayCtrl = TextEditingController(text: '${provider.taksitler.length + 1}');
    final tutarCtrl = TextEditingController(text: '${provider.danismanlik.toplamTutar}');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Ödeme Havuzu Başlat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ayCtrl,
              decoration: const InputDecoration(labelText: 'Kaçıncı Ay / Dönem?'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tutarCtrl,
              decoration: const InputDecoration(labelText: 'Gelen Para (KDV Dahil/Hariç Brüt Tutar)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              provider.yeniTaksitEkle(
                int.tryParse(ayCtrl.text) ?? 1,
                double.tryParse(tutarCtrl.text) ?? 0.0,
              );
              Navigator.pop(c);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<_DecisionItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: item.isHighlight ? FontWeight.bold : FontWeight.w500,
                      color: item.highlightColor ?? (item.isHighlight ? AppColors.textPrimary : AppColors.textSecondary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showKurulKararlariDuzenleDialog(
    BuildContext context,
    DanismanlikDetayProvider provider,
  ) async {
    final d = provider.danismanlik;
    final birimKisaAdCtrl = TextEditingController(text: d.birimKisaAd ?? '');
    final evrakTarihCtrl = TextEditingController(text: d.birimEvrakTarihi ?? '');
    final evrakSayiCtrl = TextEditingController(text: d.birimEvrakSayisi ?? '');
    final bykTarihCtrl = TextEditingController(text: d.birimKararTarihi ?? '');
    final bykToplantiCtrl = TextEditingController(text: d.birimToplantiSayisi ?? '');
    final bykKararCtrl = TextEditingController(text: d.birimKararNo ?? '');
    final ykkTarihCtrl = TextEditingController(text: d.ykKararTarihi ?? '');
    final ykkToplantiCtrl = TextEditingController(text: d.ykToplantiSayisi ?? '');
    final ykkKararCtrl = TextEditingController(text: d.ykKararNo ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 12),
              Text(
                'Sözleşme Kurul ve Evrak Bilgileri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bağlı birimden (Fakülte/Yüksekokul/Merkez) gelen üst yazı, BYK kararı ve Döner Sermaye Yürütme Kurulu sözleşme onay numaralarını güncelleyin.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  const Text('1. Bağlı Birim & EBYS Üst Yazı Bilgileri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: birimKisaAdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bağlı Birim Adı / Kodu',
                            hintText: 'Örn: DTS, USEM',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: evrakSayiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Birim Üst Yazı (Evrak) No',
                            hintText: 'Örn: E.345322',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDialogDateField(
                          context: dialogCtx,
                          label: 'Üst Yazı Tarihi',
                          controller: evrakTarihCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('2. Birim Yönetim Kurulu Kararı (BYK)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogDateField(
                          context: dialogCtx,
                          label: 'BYK Karar Tarihi',
                          controller: bykTarihCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bykToplantiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'BYK Toplantı No',
                            hintText: 'Örn: 2026/13',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bykKararCtrl,
                          decoration: const InputDecoration(
                            labelText: 'BYK Karar No',
                            hintText: 'Örn: 02',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('3. Döner Sermaye Yürütme Kurulu Kabul Kararı (YKK)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogDateField(
                          context: dialogCtx,
                          label: 'YKK Karar Tarihi',
                          controller: ykkTarihCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ykkToplantiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'YKK Toplantı No',
                            hintText: 'Örn: 2026/04',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ykkKararCtrl,
                          decoration: const InputDecoration(
                            labelText: 'YKK Karar No',
                            hintText: 'Örn: 03',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await provider.sozlesmeKararBilgileriniGuncelle(
                  birimKisaAd: birimKisaAdCtrl.text.trim(),
                  birimEvrakTarihi: evrakTarihCtrl.text.trim(),
                  birimEvrakSayisi: evrakSayiCtrl.text.trim(),
                  birimKararTarihi: bykTarihCtrl.text.trim(),
                  birimToplantiSayisi: bykToplantiCtrl.text.trim(),
                  birimKararNo: bykKararCtrl.text.trim(),
                  ykKararTarihi: ykkTarihCtrl.text.trim(),
                  ykToplantiSayisi: ykkToplantiCtrl.text.trim(),
                  ykKararNo: ykkKararCtrl.text.trim(),
                );
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Kurul ve evrak bilgileri başarıyla güncellendi.' : 'Güncelleme hatası oluştu.'),
                        backgroundColor: success ? AppColors.success : AppColors.danger,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogDateField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'gg.aa.yyyy',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          tooltip: 'Takvimden Seç',
          onPressed: () async {
            DateTime initialDate = DateTime.now();
            final raw = controller.text.trim();
            if (raw.isNotEmpty) {
              final parts = raw.split('.');
              if (parts.length == 3) {
                final d = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final y = int.tryParse(parts[2]);
                if (d != null && m != null && y != null && y > 2000 && y < 2100) {
                  initialDate = DateTime(y, m, d);
                }
              }
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
              controller.text = formatted;
            }
          },
        ),
      ),
    );
  }

  Widget _buildBakiyeCari(DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final toplamTutar = d.toplamTutar;
    final kullanilanTutar = provider.taksitler.fold<double>(0, (sum, t) => sum + t.brutTutar);
    final kalanTutar = toplamTutar - kullanilanTutar;
    final oran = toplamTutar > 0 ? (kullanilanTutar / toplamTutar) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dağıtılan: ${TurkceFormat.para(kullanilanTutar)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              Text(
                'Kalan Bakiye: ${TurkceFormat.para(kalanTutar)}',
                style: TextStyle(
                  color: kalanTutar < 0 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: oran.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceVariant,
            color: kalanTutar < 0 ? AppColors.danger : AppColors.success,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, DanismanlikModel d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sözleşmeyi Sil'),
        content: const Text('Bu sözleşmeyi kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await DanismanlikService().delete(d.id);
      if (context.mounted) context.go('/danismanlik');
    }
  }
}

class _DecisionItem {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? highlightColor;

  const _DecisionItem(this.label, this.value, {this.isHighlight = false, this.highlightColor});
}

class _TaksitKararForm extends StatefulWidget {
  final TaksitModel taksit;
  final DanismanlikDetayProvider provider;

  const _TaksitKararForm({required this.taksit, required this.provider});

  @override
  State<_TaksitKararForm> createState() => _TaksitKararFormState();
}

class _TaksitKararFormState extends State<_TaksitKararForm> {
  late TextEditingController evrakTarih;
  late TextEditingController evrakSayi;
  late TextEditingController bykTarih;
  late TextEditingController bykToplanti;
  late TextEditingController bykKarar;
  late TextEditingController ykkTarih;
  late TextEditingController ykkToplanti;
  late TextEditingController ykkKarar;

  @override
  void initState() {
    super.initState();
    final t = widget.taksit;
    evrakTarih = TextEditingController(text: t.birimEvrakTarihi ?? '');
    evrakSayi = TextEditingController(text: t.birimEvrakSayisi ?? '');
    bykTarih = TextEditingController(text: t.birimKurulTarihi ?? '');
    bykToplanti = TextEditingController(text: t.birimToplantiSayisi ?? '');
    bykKarar = TextEditingController(text: t.birimKararNo ?? '');
    ykkTarih = TextEditingController(text: t.ykKararTarihi ?? '');
    ykkToplanti = TextEditingController(text: t.ykToplantiSayisi ?? '');
    ykkKarar = TextEditingController(text: t.ykKararNo ?? '');
  }

  @override
  void dispose() {
    evrakTarih.dispose();
    evrakSayi.dispose();
    bykTarih.dispose();
    bykToplanti.dispose();
    bykKarar.dispose();
    ykkTarih.dispose();
    ykkToplanti.dispose();
    ykkKarar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Bağlı Birim Teklif Üst Yazısı (EBYS)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDateField('Birim Üst Yazı Tarihi', evrakTarih)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('Birim Üst Yazı (Evrak) No (Örn: E.450123)', evrakSayi)),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '2. Dağıtım Teklifi Birim Yönetim Kurulu Kararı (BYK)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDateField('Dağıtım BYK Tarihi', bykTarih)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('BYK Toplantı No', bykToplanti)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('BYK Karar No', bykKarar)),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          '3. Dağıtım Onayı Döner Sermaye Yürütme Kurulu Kararı (YKK)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDateField('Dağıtım YKK Tarihi', ykkTarih)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('YKK Toplantı No', ykkToplanti)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('YKK Karar No', ykkKarar)),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              final guncel = widget.taksit.copyWith(
                birimEvrakTarihi: evrakTarih.text.trim(),
                birimEvrakSayisi: evrakSayi.text.trim(),
                birimKurulTarihi: bykTarih.text.trim(),
                birimToplantiSayisi: bykToplanti.text.trim(),
                birimKararNo: bykKarar.text.trim(),
                ykKararTarihi: ykkTarih.text.trim(),
                ykToplantiSayisi: ykkToplanti.text.trim(),
                ykKararNo: ykkKarar.text.trim(),
              );
              await widget.provider.taksitKararGuncelle(widget.taksit.id, guncel);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Havuz Karar ve Evrak bilgileri kaydedildi.'), backgroundColor: AppColors.success)
                );
              }
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Kararları Kaydet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, 
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'gg.aa.yyyy',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          tooltip: 'Takvimden Seç',
          onPressed: () async {
            DateTime initialDate = DateTime.now();
            final raw = controller.text.trim();
            if (raw.isNotEmpty) {
              final parts = raw.split('.');
              if (parts.length == 3) {
                final d = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final y = int.tryParse(parts[2]);
                if (d != null && m != null && y != null && y > 2000 && y < 2100) {
                  initialDate = DateTime(y, m, d);
                }
              }
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
              controller.text = formatted;
            }
          },
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
