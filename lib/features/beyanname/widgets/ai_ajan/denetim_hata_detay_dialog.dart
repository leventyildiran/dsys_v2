import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/turkce_format.dart';
import '../../models/beyanname_denetim_rapor_model.dart';
import '../../providers/beyanname_provider.dart';

/// Çapraz denetim kartındaki uyarı/hata için detaylı inceleme penceresi.
/// Mevzuat rehberi yerel (0 TL); AI mütalaası yalnızca kullanıcı isterse çağrılır.
class DenetimHataDetayDialog extends StatefulWidget {
  final MutabakatKontrolKaydi kontrol;
  final BeyannameProvider provider;

  const DenetimHataDetayDialog({super.key, required this.kontrol, required this.provider});

  static Future<void> goster(
    BuildContext context, {
    required MutabakatKontrolKaydi kontrol,
    required BeyannameProvider provider,
  }) {
    return showDialog(
      context: context,
      builder: (_) => DenetimHataDetayDialog(kontrol: kontrol, provider: provider),
    );
  }

  @override
  State<DenetimHataDetayDialog> createState() => _DenetimHataDetayDialogState();
}

class _DenetimHataDetayDialogState extends State<DenetimHataDetayDialog> {
  bool _yukleniyor = false;
  String? _mutalaa;
  String? _hata;

  Future<void> _mutalaaAl() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final m = await widget.provider.denetimMutalaasiAl(widget.kontrol);
      if (mounted) setState(() => _mutalaa = m);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kontrol;
    final renk = k.seviye == DenetimSeviyesi.hata ? AppColors.danger : AppColors.warning;
    final rehber = _mevzuatRehberi(k);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.psychology_alt_rounded, color: renk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '[Senaryo ${k.senaryoNo}] ${k.baslik}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kart(
                baslik: 'Sayısal Durum — ${k.birimAdi}',
                ikon: Icons.calculate_rounded,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _deger('Beklenen', k.beklenenDeger, AppColors.textPrimary),
                    _deger('Bulunan', k.bulunanDeger, AppColors.textPrimary),
                    _deger('Fark', k.fark, AppColors.danger),
                  ],
                ),
              ),
              _kart(
                baslik: 'Uzman Mevzuat İncelemesi',
                ikon: Icons.gavel_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rehber
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $s',
                                style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary)),
                          ))
                      .toList(),
                ),
              ),
              _kart(
                baslik: 'Canlı AI Mütalaası (İsteğe Bağlı)',
                ikon: Icons.smart_toy_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_mutalaa == null && !_yukleniyor)
                      OutlinedButton.icon(
                        onPressed: _mutalaaAl,
                        icon: const Icon(Icons.smart_toy_outlined, size: 16),
                        label: const Text('Yapay Zekadan Bu Hata İçin Canlı Mütalaa Al'),
                      ),
                    if (_yukleniyor)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(color: AppColors.primary),
                      ),
                    if (_hata != null)
                      Text('Mütalaa alınamadı: $_hata',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                    if (_mutalaa != null)
                      SelectableText(_mutalaa!,
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
      ],
    );
  }

  Widget _kart({required String baslik, required IconData ikon, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ikon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(baslik,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _deger(String etiket, double? v, Color renk) {
    return Text(
      '$etiket: ${v == null ? '-' : TurkceFormat.para(v)}',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk),
    );
  }

  /// Senaryo numarasına göre yerel (AI'sız) mevzuat rehberi.
  List<String> _mevzuatRehberi(MutabakatKontrolKaydi k) {
    final genel = <String>[
      k.aciklama,
      if (k.cozumOnerisi != null && k.cozumOnerisi!.isNotEmpty) 'Sistem önerisi: ${k.cozumOnerisi}',
    ];
    switch (k.senaryoNo) {
      case 3:
        return [
          ...genel,
          'Sağlık (ağız-diş, uygulama merkezi) ve eğitim (TÖMER, USEM vb.) hizmetleri KDVK md. 17/1 ve 17/2-b kapsamında KDV\'den İSTİSNA olabilir.',
          'Bu durumda KDV 1 matrahının 0 olması bir hata DEĞİL, yasal istisnadır.',
          'İstisna kapsamındaki tutar KDV 1 beyannamesinde "Tablo 8 — İstisnalar / Diğer İadeler" bölümünde ilgili istisna koduyla gösterilmelidir.',
          'İstisna dışı (KDV\'li) satış varsa, 391 alt hesaplarını kontrol edip yalnız o kısmı matraha yazın.',
        ];
      case 2:
        return [
          ...genel,
          'Yıllık kümülatif 600 = önceki aylar toplamı + bu ay olmalıdır.',
          'Fark varsa önceki ay beyanlarını veya yanlış dönem mizan yüklenip yüklenmediğini kontrol edin.',
        ];
      case 5:
        return [
          ...genel,
          '190 Devreden KDV, önceki ay KDV 1 beyannamesindeki "Sonraki Döneme Devreden KDV" ile eşit olmalıdır.',
          'Fark varsa önceki ay beyannamesi veya mizan kaydı düzeltilmelidir (düzeltme beyannamesi gerekebilir).',
        ];
      case 6:
        return [
          ...genel,
          'Ters bakiye (ör. 600\'ün borç, 391\'in borç bakiye vermesi) genelde iade/iptal faturası veya hatalı yevmiye kaydından kaynaklanır.',
          'İlgili hesabın muavin (yardımcı defter) dökümünden kaydı bulup muhasebe birimiyle teyit edin.',
        ];
      case 7:
        return [
          ...genel,
          'Damga Vergisi Kanunu (1) sayılı tablo: sözleşme/ihale kararlarında binde 9,48 oranı uygulanır.',
          '360.03.05 bakiyesi / 0,00948 = damga matrahı olmalıdır; sapma varsa farklı oranlı kâğıt (makbuz, karar) olabilir.',
        ];
      case 8:
        return [
          ...genel,
          'KDV tevkifatında oran (2/10, 5/10, 7/10, 9/10) KDV Genel Uygulama Tebliği I/C-2.1.3 bölümüne göre hizmet türünden belirlenir.',
          'VKN eksik/geçersizse KDV 2 beyannamesi kabul edilmez; faturadan VKN\'yi elle doğrulayın.',
        ];
      case 9:
        return [
          ...genel,
          'Ek belgedeki (fatura) tutar ile mizan hareketi eşleşmiyorsa faturanın başka döneme kaydedilip kaydedilmediğini kontrol edin.',
          'Taranmış faturalarda OCR rakam kayması olabilir; tutarı faturadan gözle teyit edin.',
        ];
      default:
        return [
          ...genel,
          '123 POS farkı: Kredi kartı tahsilatları GİB KDV 1 "Kredi Kartı ile Tahsil Edilen Teslim ve Hizmet" satırıyla uyumlu olmalıdır.',
          'Fark nedeni belirsizse ilgili hesabın yardımcı defter dökümünü inceleyin veya canlı AI mütalaası alın.',
        ];
    }
  }
}
