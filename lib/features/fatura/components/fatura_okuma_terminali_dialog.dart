import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fatura_okuma_oturumu.dart';

/// Beyanname modülündeki canlı terminal gibi çalışan,
/// fatura okuma sürecini adım adım, şeffaf ve canlı olarak gösteren terminal diyalogu.
class FaturaOkumaTerminaliDialog extends StatefulWidget {
  const FaturaOkumaTerminaliDialog({
    super.key,
    required this.oturum,
    required this.islemGorevi,
  });

  final FaturaOkumaOturumu oturum;
  final Future<void> Function() islemGorevi;

  /// Terminali modal olarak açar ve işlemi çalıştırır.
  static Future<bool> goster({
    required BuildContext context,
    required FaturaOkumaOturumu oturum,
    required Future<void> Function() islemGorevi,
  }) async {
    final sonuc = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FaturaOkumaTerminaliDialog(
        oturum: oturum,
        islemGorevi: islemGorevi,
      ),
    );
    return sonuc == true;
  }

  @override
  State<FaturaOkumaTerminaliDialog> createState() => _FaturaOkumaTerminaliDialogState();
}

class _FaturaOkumaTerminaliDialogState extends State<FaturaOkumaTerminaliDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _bitti = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    widget.oturum.addListener(_onOturumGuncellendi);
    widget.oturum.ucretliOnayIstegi = _ucretliOnaySor;
    _baslat();
  }

  Future<void> _baslat() async {
    try {
      await widget.islemGorevi();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _bitti = true;
        });
      }
    }
  }

  void _onOturumGuncellendi() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.oturum.ucretliOnayIstegi = null;
    widget.oturum.removeListener(_onOturumGuncellendi);
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _ucretliOnaySor({
    required String dosyaAdi,
    required String yerelDurum,
    required double tahminiMaliyetTl,
  }) async {
    if (!mounted) return false;
    final onay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.monetization_on_outlined, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text(
              'Ücretli API Onayı',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ücretsiz Google API 10 deneme yaptı ve yanıt veremedi (sunucu yoğunluğu/kota).',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Belge: $dosyaAdi', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• Durum: $yerelDurum', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '• Tahmini Maliyet: ~${tahminiMaliyetTl.toStringAsFixed(2)} TL',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Faturanın kalanını tamamlamak için ücretli yedek API anahtarına gönderilsin mi?',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF94A3B8),
              side: const BorderSide(color: Color(0xFF475569)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır, Yerelde Kalsın (0 TL)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Ücretliye Gönder'),
          ),
        ],
      ),
    );
    return onay == true;
  }

  @override
  Widget build(BuildContext context) {
    final oturum = widget.oturum;
    final loglar = oturum.loglar;
    final yuzde = (oturum.ilerleme * 100).toInt().clamp(0, 100);

    return Dialog(
      backgroundColor: AppColors.terminalZemin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.terminalKenarlik, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── 1. Konsol Üst Başlık Çubuğu ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.terminalBaslik,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  if (oturum.calisiyor)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.terminalVurgu,
                      ),
                    )
                  else if (_hata != null || oturum.hataliDosya > 0 && oturum.faturaSayisi == 0)
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.terminalHata,
                    )
                  else
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.terminalBasari,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      oturum.calisiyor
                          ? '⚡ AKILLI FATURA MOTORU — CANLI OKUMA VE DENETİM AKIŞI'
                          : '📋 İŞLEM ÖZETİ — OKUMA GÜNLÜĞÜ',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '%$yuzde',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terminalVurgu,
                    ),
                  ),
                ],
              ),
            ),

            // ─── 2. Canlı İlerleme Çubuğu ───
            LinearProgressIndicator(
              value: oturum.ilerleme,
              backgroundColor: AppColors.terminalKenarlik,
              color: AppColors.terminalVurgu,
              minHeight: 3,
            ),

            // ─── 3. Canlı İstatistik Şeridi ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.terminalBaslik.withValues(alpha: 0.6),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _sayacKutusu(
                    etiket: 'Aktif Katman',
                    deger: oturum.aktifKatman,
                    renk: AppColors.terminalVurgu,
                  ),
                  _sayacKutusu(
                    etiket: 'Fatura',
                    deger: '${oturum.faturaSayisi} Adet',
                    renk: AppColors.terminalBasari,
                  ),
                  _sayacKutusu(
                    etiket: 'API Çağrısı',
                    deger: '${oturum.apiCagriSayisi}',
                    renk: oturum.apiCagriSayisi == 0 ? AppColors.terminalBasari : AppColors.terminalUyari,
                  ),
                  _sayacKutusu(
                    etiket: 'Token',
                    deger: '${oturum.toplamToken}',
                    renk: AppColors.terminalSoluk,
                  ),
                  _sayacKutusu(
                    etiket: 'Tahmini Maliyet',
                    deger: FaturaOkumaOturumu.maliyetMetni(oturum.tahminiMaliyetTl),
                    renk: oturum.tahminiMaliyetTl == 0 ? AppColors.terminalBasari : AppColors.terminalUyari,
                  ),
                  _sayacKutusu(
                    etiket: 'Süre',
                    deger: '${(oturum.gecenSure.inMilliseconds / 1000).toStringAsFixed(1)} sn',
                    renk: AppColors.textOnDarkMuted,
                  ),
                ],
              ),
            ),

            // ─── 4. Terminal Metin Akışı ───
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: loglar.isEmpty
                    ? const Center(
                        child: Text(
                          'İşlem başlatılıyor...',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.terminalSoluk,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: loglar.length,
                        itemBuilder: (context, index) {
                          final l = loglar[index];
                          Color textColor = AppColors.terminalMetin;
                          FontWeight weight = FontWeight.normal;

                          switch (l.seviye) {
                            case FaturaLogSeviyesi.katman:
                              textColor = AppColors.terminalVurgu;
                              weight = FontWeight.bold;
                            case FaturaLogSeviyesi.basarili:
                              textColor = AppColors.terminalBasari;
                              weight = FontWeight.w600;
                            case FaturaLogSeviyesi.uyari:
                              textColor = AppColors.terminalUyari;
                            case FaturaLogSeviyesi.hata:
                              textColor = AppColors.terminalHata;
                              weight = FontWeight.bold;
                            case FaturaLogSeviyesi.maliyet:
                              textColor = AppColors.terminalUyari;
                              weight = FontWeight.w600;
                            case FaturaLogSeviyesi.bilgi:
                              textColor = AppColors.terminalMetin;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '[${l.formatliZaman}] ',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.terminalSoluk,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    l.mesaj,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      fontWeight: weight,
                                      color: textColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // ─── 5. Alt Eylem Çubuğu ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.terminalBaslik,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  if (_hata != null)
                    Expanded(
                      child: Text(
                        'Hata: $_hata',
                        style: const TextStyle(
                          color: AppColors.terminalHata,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (oturum.calisiyor)
                    OutlinedButton.icon(
                      onPressed: () => oturum.iptalEt(),
                      icon: const Icon(Icons.stop_circle_rounded, size: 16, color: AppColors.danger),
                      label: const Text(
                        'Durdur',
                        style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(oturum.faturaSayisi > 0),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        oturum.faturaSayisi > 0
                            ? 'Kuyruğu Göster (${oturum.faturaSayisi} Fatura)'
                            : 'Kapat',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: oturum.faturaSayisi > 0 ? AppColors.success : AppColors.neutral,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _sayacKutusu({
    required String etiket,
    required String deger,
    required Color renk,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$etiket: ',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: AppColors.terminalSoluk,
          ),
        ),
        Text(
          deger,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: renk,
          ),
        ),
      ],
    );
  }
}
