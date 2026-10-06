import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_excel_hesaplama.dart';
import '../../services/danismanlik_manuel_pdf_servisi.dart';
import 'excel_hesaplama_tablolari.dart';
import 'hoca_hakedis_ozet_karti.dart';

class TabKatkiPayi extends StatelessWidget {
  const TabKatkiPayi({
    super.key,
    required this.excelSonuc,
    required this.personeller,
    required this.maksAkademikPay,
    required this.manuelKatsayiController,
    required this.manuelKatsayiAktif,
    required this.onManuelKatsayiDegisti,
    required this.memurMaasKatsayisi,
    required this.memurMaasKatsayisiController,
    required this.onMemurMaasKatsayisiDegisti,
    this.onMemurMaasKatsayisiKaydet,
    required this.onPersonelEkle,
    required this.onCokluPersonelEkle,
    required this.onPersonelSil,
    required this.onPersonelGuncelle,
    this.is58k = false,
    this.is58e = false,
    this.gelirVergisiOrani = 15,
    this.onGelirVergisiOraniDegisti,
    this.odemeTekSeferde = true,
    this.toplamTaksitSayisi = 3,
    this.aktifTaksitNo = 1,
    this.ozelTaksitTutari,
    this.ozelTaksitController,
    this.onOdemeTekSeferdeDegisti,
    this.onToplamTaksitSayisiDegisti,
    this.onAktifTaksitNoDegisti,
    this.onOzelTaksitTutariDegisti,
    this.kesinti,
    this.sozlesmeBaslangicTarihi,
    this.danismanlikDonemi,
    this.onSozlesmeBaslangicDegisti,
    this.onDanismanlikDonemiDegisti,
    this.tavanUygula = false,
    this.onTavanUygulaDegisti,
    this.onTumSaatleriTavanaDengele,
    this.hazineOrani = 0,
    this.bapOrani = 0,
    this.aracGerecOrani = 0.15,
    this.digerOrani = 0.0,
    this.onKesintiOranlariDegisti,
  });

  final DanismanlikExcelSonuc excelSonuc;
  final List<ExcelPersonelGirdi> personeller;
  final double maksAkademikPay;
  final int hazineOrani;
  final int bapOrani;
  final double aracGerecOrani;
  final double digerOrani;
  final void Function(int hazine, int bap, double aracGerec, [double? diger])? onKesintiOranlariDegisti;
  final TextEditingController manuelKatsayiController;
  final bool manuelKatsayiAktif;
  final ValueChanged<bool> onManuelKatsayiDegisti;
  final double memurMaasKatsayisi;
  final TextEditingController memurMaasKatsayisiController;
  final ValueChanged<double> onMemurMaasKatsayisiDegisti;
  final VoidCallback? onMemurMaasKatsayisiKaydet;
  final VoidCallback onPersonelEkle;
  final VoidCallback onCokluPersonelEkle;
  final ValueChanged<int> onPersonelSil;
  final void Function(int index, ExcelPersonelGirdi girdi) onPersonelGuncelle;
  final bool is58k;
  final bool is58e;
  final int gelirVergisiOrani;
  final ValueChanged<int>? onGelirVergisiOraniDegisti;
  final bool odemeTekSeferde;
  final int toplamTaksitSayisi;
  final int aktifTaksitNo;
  final double? ozelTaksitTutari;
  final TextEditingController? ozelTaksitController;
  final ValueChanged<bool>? onOdemeTekSeferdeDegisti;
  final ValueChanged<int>? onToplamTaksitSayisiDegisti;
  final ValueChanged<int>? onAktifTaksitNoDegisti;
  final ValueChanged<double?>? onOzelTaksitTutariDegisti;
  final ExcelKesintiSonuc? kesinti;
  final DateTime? sozlesmeBaslangicTarihi;
  final String? danismanlikDonemi;
  final ValueChanged<DateTime>? onSozlesmeBaslangicDegisti;
  final ValueChanged<String>? onDanismanlikDonemiDegisti;
  final bool tavanUygula;
  final ValueChanged<bool>? onTavanUygulaDegisti;
  final VoidCallback? onTumSaatleriTavanaDengele;

  static const List<String> unvanListesi = [
    'Profesör',
    'Doçent',
    'Dr. Öğr. Üyesi',
    'Öğr. Gör. Dr.',
    'Öğr. Gör.',
    'Arş. Gör. Dr.',
    'Arş. Gör.',
  ];

  /// Gelen herhangi bir unvan metnini resmi standart unvanListesi öğelerinden birine eşler.
  static String unvanNormalize(String unvan) {
    if (unvanListesi.contains(unvan)) return unvan;
    final lower = unvan.trim().toLowerCase();
    if (lower.contains('prof')) return 'Profesör';
    if (lower.contains('doç') || lower.contains('doc')) return 'Doçent';
    if (lower.contains('dr. öğr') || lower.contains('dr.öğr') || lower.contains('öğretim üyesi') || lower.contains('ogretim uyesi') || lower.contains('yrd') || lower.contains('yard')) return 'Dr. Öğr. Üyesi';
    if ((lower.contains('öğr') || lower.contains('ogr')) && lower.contains('dr')) return 'Öğr. Gör. Dr.';
    if (lower.contains('öğr') || lower.contains('ogr') || lower.contains('görevli') || lower.contains('gorevli')) return 'Öğr. Gör.';
    if ((lower.contains('arş') || lower.contains('ars')) && lower.contains('dr')) return 'Arş. Gör. Dr.';
    if (lower.contains('arş') || lower.contains('ars')) return 'Arş. Gör.';
    return 'Öğr. Gör. Dr.';
  }

  @override
  Widget build(BuildContext context) {
    if (is58k || is58e) {
      return _build58kView(context);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bilgilendirme ve Üst Özet Barı
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_outlined, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Katkı Payı & Dönem Ek Katsayı Hesaplama',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          'Excel formülü: Dağıtılacak Maksimum Akademik Pay / Toplam Puan = Dönem Ek Katsayısı',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Excel F8-J9 Parametre Kutuları (Düzenlenebilir Memur Maaş Katsayısı)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Memur Maaş Katsayısı: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(
                              width: 85,
                              height: 26,
                              child: TextFormField(
                                controller: memurMaasKatsayisiController,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: Color(0xFF94A3B8)),
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                onChanged: (val) {
                                  final d = double.tryParse(val.replaceAll(',', '.').trim());
                                  if (d != null && d > 0) {
                                    onMemurMaasKatsayisiDegisti(d);
                                  }
                                },
                              ),
                            ),
                            if (onMemurMaasKatsayisiKaydet != null) ...[
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 26,
                                child: ElevatedButton.icon(
                                  onPressed: onMemurMaasKatsayisiKaydet,
                                  icon: const Icon(Icons.save_outlined, size: 13),
                                  label: const Text('Kaydet', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            SizedBox(
                              height: 26,
                              child: OutlinedButton.icon(
                                onPressed: () => _ekDersAyarlariDialogGoster(context),
                                icon: const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF0F766E)),
                                label: const Text('Ayarlar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  side: const BorderSide(color: Color(0xFF0F766E)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Yasal Tavan Bilgi Notu Doğrudan Aç/Kapat Butonu
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => onTavanUygulaDegisti?.call(!tavanUygula),
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: tavanUygula ? const Color(0xFFDCFCE7) : Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: tavanUygula ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        tavanUygula ? Icons.balance : Icons.balance_outlined,
                                        size: 13,
                                        color: tavanUygula ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tavanUygula ? '⚖️ Tavana Göre Dağıt: AÇIK' : '⚖️ Tavana Göre Dağıt: KAPALI',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: tavanUygula ? const Color(0xFF15803D) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: onPersonelEkle,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Personel Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Yasal & Kurumsal Kesintiler Ayar Kartı (Tüm şablonlar: USEM, DTS, TÖMER, DÖSİM)
          _buildKesintilerAyarKarti(context),
          const SizedBox(height: 16),

          // 3'lü Özet Kartları: Maks Pay, Toplam Puan, Dönem Katsayısı
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF3B82F6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Dağıtılacak Maks. Pay:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                Text(
                                  TurkceFormat.para(maksAkademikPay),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Dağıtılan Tutar:',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                ),
                                Text(
                                  TurkceFormat.para(excelSonuc.netOdemeToplam),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  (tavanUygula && excelSonuc.toplamTavanKesintisi > 0)
                                      ? 'Birim Havuzuna Kalan:'
                                      : 'Kalan Artık Bakiye:',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                                Text(
                                  TurkceFormat.para((tavanUygula && excelSonuc.toplamTavanKesintisi > 0)
                                      ? excelSonuc.havuzToplam
                                      : excelSonuc.artikBakiye),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: (excelSonuc.havuzToplam > 0 || excelSonuc.artikBakiye > 0)
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kartKutusu(
                  baslik: 'Toplam Katkı Puanı',
                  deger: excelSonuc.toplamPuan.toStringAsFixed(0),
                  altMetin: '${excelSonuc.personelSatirlari.length} personel katkısı',
                  renk: const Color(0xFF8B5CF6),
                  ikon: Icons.score_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dönem Ek Ödeme Katsayısı',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Manuel', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: manuelKatsayiAktif,
                                  onChanged: onManuelKatsayiDegisti,
                                  activeThumbColor: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (manuelKatsayiAktif)
                        SizedBox(
                          height: 32,
                          child: TextField(
                            controller: manuelKatsayiController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF10B981)),
                          ),
                        )
                      else ...[
                        Text(
                          (tavanUygula && excelSonuc.toplamTavanKesintisi > 0)
                              ? '${TurkceFormat.katsayi(excelSonuc.fiiliDonemKatsayisi)} (Fiili)'
                              : TurkceFormat.katsayi(excelSonuc.donemKatsayi),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF047857)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (tavanUygula && excelSonuc.toplamTavanKesintisi > 0)
                              ? 'Ham Gelir K.: ${TurkceFormat.katsayi(excelSonuc.donemKatsayi)} | Sağlama: ${TurkceFormat.para(excelSonuc.saglama)}'
                              : 'Sağlama: ${TurkceFormat.para(excelSonuc.saglama)}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Yasal Tavan & Mevzuat Bilgi Notu / Analiz Kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: !tavanUygula
                  ? const Color(0xFFF8FAFC)
                  : (excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !tavanUygula
                    ? const Color(0xFFCBD5E1)
                    : (excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC)),
                width: 1.3,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      !tavanUygula
                          ? Icons.info_outline
                          : (excelSonuc.herhangiBirTavanAsildi ? Icons.warning_amber_rounded : Icons.verified_outlined),
                      size: 20,
                      color: !tavanUygula
                          ? const Color(0xFF64748B)
                          : (excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFD97706) : const Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !tavanUygula
                            ? 'YASAL TAVAN ANALİZİ: KAPALI (SINIRSIZ TAM ÖDEME)'
                            : (excelSonuc.herhangiBirTavanAsildi
                                ? 'YASAL TAVAN BİLGİ NOTU & ANALİZİ (2547 s.k. m.58 & 2914 s.k.)'
                                : 'YASAL TAVAN UYGUNLUK ANALİZİ: TÜM HOCALAR MEVZUATA UYGUNDUR'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: !tavanUygula
                              ? const Color(0xFF334155)
                              : (excelSonuc.herhangiBirTavanAsildi ? const Color(0xFF92400E) : const Color(0xFF166534)),
                        ),
                      ),
                    ),
                    // Aç/Kapat Butonu
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onTavanUygulaDegisti?.call(!tavanUygula),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: tavanUygula ? const Color(0xFFDCFCE7) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: tavanUygula ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tavanUygula ? Icons.check_circle : Icons.power_settings_new,
                                size: 14,
                                color: tavanUygula ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tavanUygula
                                    ? 'Bilgi Notu: AÇIK (${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}/Saat)'
                                    : 'Bilgi Notu: KAPALI (Açmak için tıklayın)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: tavanUygula ? const Color(0xFF15803D) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _ekDersAyarlariDialogGoster(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 13, color: Color(0xFF0F766E)),
                              SizedBox(width: 4),
                              Text(
                                '⚙️ Ayarlar',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  !tavanUygula
                      ? 'Yasal ek ders tavanı dağıtımı şu anda kapalıdır. Personellere hesaplanan brüt hakediş sınırlama olmaksızın tam tahakkuk ettirilmektedir. Tavan sınırını uygulamak için "⚖️ Tavana Göre Dağıt" butonunu açabilirsiniz.'
                      : (excelSonuc.herhangiBirTavanAsildi
                          ? 'Yönetim Kurulu Kararındaki ders saatleri korunarak yasal tavan kuralı uygulandı. Saatlik ücreti tavanı aşan personele yasal tavan ödendi (${TurkceFormat.para(excelSonuc.netOdemeToplam)}). Aşan ${TurkceFormat.para(excelSonuc.toplamTavanKesintisi)} tutar birim döner sermaye havuzuna aktarıldı.'
                          : 'Hesaplanan tüm saatlik ücretler, yasal sınır olan ek ders tavanının (${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}/Saat) altındadır. Kesinti olmaksızın tam ödeme yapılabilir ve mevzuata tam uygundur.'),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: !tavanUygula
                        ? const Color(0xFF475569)
                        : (excelSonuc.herhangiBirTavanAsildi ? const Color(0xFF15803D) : const Color(0xFF14532D)),
                  ),
                ),
                if (tavanUygula && excelSonuc.herhangiBirTavanAsildi) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, size: 20, color: Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '⚖️ Yasal Tavan Koruması Aktif (Müdür / Mutemetlik Kuralı):',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'YK kararındaki ders saatleri sabit tutulmuş, saatlik ücreti tavanı aşan personellere yasal tavan (${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}/Saat) kilitlenmiştir. Tavandan dolayı artan ${TurkceFormat.para(excelSonuc.toplamTavanKesintisi)} döner sermaye birim havuzuna bırakılmıştır.',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF166534), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Personel Tablosu Üst Başlığı ve Kişi Ekle Butonu
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_outlined, color: Color(0xFF107C41), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Akademik Personel Katkı Payı Dağıtım Listesi',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Toplam para kişilerin puanlarına oranla otomatik dağıtılır. Birden fazla kişi ekleyebilirsiniz.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (tavanUygula && excelSonuc.herhangiBirTavanAsildi && onTumSaatleriTavanaDengele != null) ...[
                    ElevatedButton.icon(
                      onPressed: onTumSaatleriTavanaDengele,
                      icon: const Icon(Icons.balance, size: 16),
                      label: const Text('⚖️ Saatleri Dengele'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: onCokluPersonelEkle,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('+ Kişi / Hoca Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41), // Excel Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _ekDersAyarlariDialogGoster(context),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('⚙️ Ek Ders & Katsayı Ayarları'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Teal
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Personel Tablosu (Excel Birebir Karşılığı)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Tablo Başlığı
                Container(
                  color: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('PERSONEL / UNVAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 70, child: Text('PUAN', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 70, child: Text('UNVAN K.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 60, child: Text('SAAT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 80, child: Text('MESAİ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 90, child: Text('NET KATKI', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 90, child: Text('SAATLİK ÜCR.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 90, child: Text('EK DERS TAVAN', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                      SizedBox(width: 6),
                      SizedBox(width: 110, child: Text('ALACAĞI TUTAR', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF047857)))),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Personel Listesi
                if (excelSonuc.personelSatirlari.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Henüz personel eklenmedi. "Personel Ekle" butonunu kullanarak ekleyebilirsiniz.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: excelSonuc.personelSatirlari.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final s = excelSonuc.personelSatirlari[index];
                      final p = s.girdi;
                      final tavanAsildi = s.kursSaatlikUcreti > s.tavanSaatlikUcreti && s.tavanSaatlikUcreti > 0;

                      return Container(
                        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Ad Soyad & Unvan
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  DropdownButton<String>(
                                    value: unvanListesi.contains(p.unvan) ? p.unvan : unvanNormalize(p.unvan),
                                    underline: const SizedBox(),
                                    isDense: true,
                                    items: unvanListesi
                                        .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final newKatsayi = DanismanlikExcelHesaplama.unvanKatsayisi(val);
                                        final newEkGosterge = DanismanlikExcelHesaplama.ekGosterge(val);
                                        onPersonelGuncelle(
                                          index,
                                          p.copyWith(unvan: val, unvanKatsayisi: newKatsayi, ekGosterge: newEkGosterge),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextFormField(
                                      key: ValueKey('adSoyad_${p.personelId}_$index'),
                                      initialValue: p.adSoyad,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        hintText: 'Adı Soyadı',
                                        border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      ),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      onChanged: (val) => onPersonelGuncelle(index, p.copyWith(adSoyad: val)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Taban Puan
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                key: ValueKey('puan_${p.personelId}_$index'),
                                initialValue: p.puan.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                ),
                                style: const TextStyle(fontSize: 11),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.trim()) ?? 0.0;
                                  onPersonelGuncelle(index, p.copyWith(puan: numVal));
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Unvan Katsayısı
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                key: ValueKey('unvanK_${p.personelId}_${index}_${p.unvan}_${p.unvanKatsayisi}'),
                                initialValue: (p.unvanKatsayisi > 1.0 ? p.unvanKatsayisi : DanismanlikExcelHesaplama.unvanKatsayisi(p.unvan, p.unvanKatsayisi)).toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                ),
                                style: const TextStyle(fontSize: 11),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.replaceAll(',', '.').trim()) ?? 1.0;
                                  onPersonelGuncelle(index, p.copyWith(unvanKatsayisi: numVal));
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Ders Saati
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                key: ValueKey('dersSaati_${p.personelId}_$index'),
                                initialValue: p.dersSaati.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                ),
                                style: const TextStyle(fontSize: 11),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.trim()) ?? 1.0;
                                  onPersonelGuncelle(index, p.copyWith(dersSaati: numVal));
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Mesai İçi / Dışı Toggle
                            SizedBox(
                              width: 80,
                              child: InkWell(
                                onTap: () => onPersonelGuncelle(index, p.copyWith(mesaiIci: !p.mesaiIci)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.mesaiIci ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: p.mesaiIci ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p.mesaiIci ? 'Mesai İçi' : 'Mesai Dışı',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: p.mesaiIci ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Bireysel Net Katkı Puanı (Puan * Katsayı * Saat)
                            SizedBox(
                              width: 90,
                              child: Text(
                                s.bireyselNetKatkiPuani.toStringAsFixed(0),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Kurs 1 Saatlik Ücreti
                            SizedBox(
                              width: 90,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    TurkceFormat.para(s.kursSaatlikUcreti),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: (tavanUygula && tavanAsildi) ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (tavanAsildi) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tavanUygula ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: tavanUygula ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
                                      ),
                                      child: Text(
                                        tavanUygula
                                            ? '⚖️ Tavan Kilitli (-${TurkceFormat.para(s.havuzTutari)})'
                                            : '⚠️ Tavan Aşıldı',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: tavanUygula ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Ek Ders Tavanı
                            SizedBox(
                              width: 90,
                              child: Text(
                                TurkceFormat.para(s.tavanSaatlikUcreti),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Alacağı Tutar (Ödenebilir Hakediş)
                            SizedBox(
                              width: 110,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  TurkceFormat.para(s.odenebilirHakedis),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF047857)),
                                ),
                              ),
                            ),

                            // Sil Butonu
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                onPressed: () => onPersonelSil(index),
                                tooltip: 'Personeli Kaldır',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Tablo Altı Yeni Kişi Ekle Butonları
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onCokluPersonelEkle,
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text(
                          '+ Kişi / Hoca Ekle',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF107C41),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: onPersonelEkle,
                        icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF64748B)),
                        label: const Text(
                          '+ Tabloya Boş Satır Aç',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1.5),

                // Toplam Satırı
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Text(
                        'TOPLAM SAĞLAMA VE HAKEDİŞ',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                      ),
                      const Spacer(),
                      Text(
                        'Puan: ${excelSonuc.toplamPuan.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Sağlama: ${TurkceFormat.para(excelSonuc.saglama)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4338CA)),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Ödenen: ${TurkceFormat.para(excelSonuc.netOdemeToplam)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF107C41)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Her hocanın ne kadar alacağını kuruşu kuruşuna gösteren özet kartı
          HocaHakedisOzetKarti(excelSonuc: excelSonuc),
          const SizedBox(height: 16),
          ExcelHesaplamaTablolari(
            excelSonuc: excelSonuc,
            maksAkademikPay: maksAkademikPay,
            memurMaasKatsayisi: memurMaasKatsayisi,
          ),
        ],
      ),
    );
  }

  Widget _kartKutusu({
    required String baslik,
    required String deger,
    required String altMetin,
    required Color renk,
    required IconData ikon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ikon, color: renk, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(deger, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: renk)),
                Text(altMetin, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _oranlariElleDuzenleDialog(BuildContext context) {
    final hazineCtrl = TextEditingController(text: hazineOrani.toString());
    final bapCtrl = TextEditingController(text: bapOrani.toString());
    final kurumYuzde = (aracGerecOrani * 100);
    final kurumCtrl = TextEditingController(
      text: (kurumYuzde % 1 == 0) ? kurumYuzde.toInt().toString() : kurumYuzde.toStringAsFixed(1),
    );
    final digerYuzde = (digerOrani * 100);
    final digerCtrl = TextEditingController(
      text: (digerYuzde % 1 == 0) ? digerYuzde.toInt().toString() : digerYuzde.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final hVal = int.tryParse(hazineCtrl.text.replaceAll(',', '.').trim()) ?? hazineOrani;
            final bVal = int.tryParse(bapCtrl.text.replaceAll(',', '.').trim()) ?? bapOrani;
            final kVal = double.tryParse(kurumCtrl.text.replaceAll(',', '.').trim()) ?? kurumYuzde;
            final dVal = double.tryParse(digerCtrl.text.replaceAll(',', '.').trim()) ?? digerYuzde;
            final topKes = hVal + bVal + kVal + dVal;
            final kalPay = 100 - topKes;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(Icons.tune, color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E), size: 22),
                  const SizedBox(width: 8),
                  const Text('Kesinti Oranlarını Elle Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Kesintileri dilediğiniz oranda elle belirleyebilirsiniz (örn: Kurum Payı %18, Diğer %2). Yapılan değişiklikler hesaplama tablosuna anında yansır.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: hazineCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Hazine Payı Oranı (%)',
                        hintText: '0, 1, 2 vb.',
                        prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bapCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'BAP Payı Oranı (%)',
                        hintText: '0, 5, 10 vb.',
                        prefixIcon: Icon(Icons.biotech_outlined, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kurumCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: is58e ? 'Birim / Kurum Payı Oranı (%)' : 'Kurum / Araç-Gereç Payı Oranı (%)',
                        hintText: '15, 18, 20 vb.',
                        prefixIcon: const Icon(Icons.business_outlined, size: 18),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: digerCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Diğer Kesinti Oranı (%)',
                        hintText: '0, 1, 2, 5 vb.',
                        prefixIcon: Icon(Icons.more_horiz, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Toplam Kesinti: %${topKes % 1 == 0 ? topKes.toInt() : topKes.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626)),
                          ),
                          Text(
                            'Dağıtılabilir Pay: %${kalPay % 1 == 0 ? kalPay.toInt() : kalPay.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final h = int.tryParse(hazineCtrl.text.replaceAll(',', '.').trim()) ?? hazineOrani;
                    final b = int.tryParse(bapCtrl.text.replaceAll(',', '.').trim()) ?? bapOrani;
                    final k = double.tryParse(kurumCtrl.text.replaceAll(',', '.').trim()) ?? kurumYuzde;
                    final d = double.tryParse(digerCtrl.text.replaceAll(',', '.').trim()) ?? digerYuzde;
                    onKesintiOranlariDegisti?.call(h, b, k / 100.0, d / 100.0);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tüm şablonlarda (USEM, DTS, TÖMER, DÖSİM, 58/k, 58/e) kesinti oranlarını dinamik
  /// olarak gösteren ve hem elle yazmaya hem de hazır seçeneklerden seçmeye izin veren kart.
  Widget _buildKesintilerAyarKarti(BuildContext context) {
    final hazineTutari = kesinti?.hazinePayi ?? 0.0;
    final bapTutari = kesinti?.bapPayi ?? 0.0;
    final aracGerecTutari = kesinti?.aracGerecPayi ?? 0.0;
    final digerTutari = kesinti?.digerPayi ?? 0.0;
    final toplamKesintiTutari = hazineTutari + bapTutari + aracGerecTutari + digerTutari;
    final katkiPayi = kesinti?.katkiPayi ?? maksAkademikPay;

    final kurumOraniYuzde = aracGerecOrani * 100;
    final digerOraniYuzde = digerOrani * 100;
    final toplamKesintiOrani = hazineOrani + bapOrani + kurumOraniYuzde + digerOraniYuzde;
    final toplamKesintiOraniStr = (toplamKesintiOrani % 1 == 0)
        ? toplamKesintiOrani.toInt().toString()
        : toplamKesintiOrani.toStringAsFixed(1);
    final kalanPayOrani = 100 - toplamKesintiOrani;
    final kalanPayOraniStr = (kalanPayOrani % 1 == 0)
        ? kalanPayOrani.toInt().toString()
        : kalanPayOrani.toStringAsFixed(1);

    final temaRengi = is58e
        ? const Color(0xFF4F46E5)
        : (is58k ? const Color(0xFF0F766E) : const Color(0xFF6366F1));

    final ucuncuEtiket = is58e
        ? 'Birim/Kurum'
        : (is58k ? 'Kurum Payı' : 'Birim/Araç Payı');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: temaRengi.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, size: 20, color: temaRengi),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yasal & Kurumsal Kesintiler:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Oranları elle kutucuklara yazabilir veya listeden seçebilirsiniz',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Hazine Payı
              _KesintiOranKutusu(
                etiket: 'Hazine',
                deger: hazineOrani,
                hazirSecenekler: const [0, 1, 2, 3, 5],
                onDegisti: (val) {
                  onKesintiOranlariDegisti?.call(val.toInt(), bapOrani, aracGerecOrani, digerOrani);
                },
              ),
              const SizedBox(width: 8),

              // 2. BAP Payı
              _KesintiOranKutusu(
                etiket: 'BAP',
                deger: bapOrani,
                hazirSecenekler: const [0, 1, 2, 5, 10],
                onDegisti: (val) {
                  onKesintiOranlariDegisti?.call(hazineOrani, val.toInt(), aracGerecOrani, digerOrani);
                },
              ),
              const SizedBox(width: 8),

              // 3. Birim / Kurum / Araç-Gereç Payı
              _KesintiOranKutusu(
                etiket: ucuncuEtiket,
                deger: (kurumOraniYuzde % 1 == 0) ? kurumOraniYuzde.toInt() : kurumOraniYuzde,
                hazirSecenekler: const [0, 5, 10, 15, 18, 20, 25, 30, 35, 40, 44, 45, 50],
                onDegisti: (val) {
                  onKesintiOranlariDegisti?.call(hazineOrani, bapOrani, val.toDouble() / 100.0, digerOrani);
                },
              ),
              const SizedBox(width: 8),

              // 4. Diğer Kesinti Payı
              _KesintiOranKutusu(
                etiket: 'Diğer',
                deger: (digerOraniYuzde % 1 == 0) ? digerOraniYuzde.toInt() : digerOraniYuzde,
                hazirSecenekler: const [0, 1, 2, 3, 5, 10, 15],
                onDegisti: (val) {
                  onKesintiOranlariDegisti?.call(hazineOrani, bapOrani, aracGerecOrani, val.toDouble() / 100.0);
                },
              ),
              const SizedBox(width: 8),

              // Elle Düzenle Butonu
              TextButton.icon(
                onPressed: () => _oranlariElleDuzenleDialog(context),
                icon: const Icon(Icons.edit, size: 15),
                label: const Text('Elle Düzenle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: temaRengi,
                  backgroundColor: temaRengi.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),

          // Özet Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Toplam Kesinti: %$toplamKesintiOraniStr (${TurkceFormat.para(toplamKesintiTutari)})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dağıtılabilir Pay: %$kalanPayOraniStr (${TurkceFormat.para(katkiPayi)})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build58kView(BuildContext context) {
    final kdvHaric = kesinti?.kdvHaricGelir ?? 0.0;
    final hazineTutari = kesinti?.hazinePayi ?? 0.0;
    final bapTutari = kesinti?.bapPayi ?? 0.0;
    final aracGerecTutari = kesinti?.aracGerecPayi ?? 0.0;
    final toplamKesintiTutari = hazineTutari + bapTutari + aracGerecTutari;
    final katkiPayi = kesinti?.katkiPayi ?? maksAkademikPay;
    final kurumOraniYuzde = (aracGerecOrani * 100);
    final kurumOraniYuzdeStr = (kurumOraniYuzde % 1 == 0) ? kurumOraniYuzde.toInt().toString() : kurumOraniYuzde.toStringAsFixed(1);
    final toplamKesintiOrani = hazineOrani + bapOrani + kurumOraniYuzde;
    final toplamKesintiOraniStr = (toplamKesintiOrani % 1 == 0) ? toplamKesintiOrani.toInt().toString() : toplamKesintiOrani.toStringAsFixed(1);
    final kalanPayOrani = 100 - toplamKesintiOrani;
    final kalanPayOraniStr = (kalanPayOrani % 1 == 0) ? kalanPayOrani.toInt().toString() : kalanPayOrani.toStringAsFixed(1);
    final buAykiPay = excelSonuc.netOdemeToplam;
    final kalanBakiye = excelSonuc.artikBakiye;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. ÜST BİLGİ VE STATÜ KARTI
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: is58e ? Colors.indigo.shade200 : Colors.teal.shade200),
            ),
            color: is58e ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDFA),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      is58e ? Icons.gavel_rounded : Icons.handshake_rounded,
                      color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              is58e
                                  ? '2547 Sayılı Kanun Madde 58/e — Danışmanlık ve Hizmet Geliri'
                                  : '2547 Sayılı Kanun Madde 58/k — Sözleşmeli Danışmanlık',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: is58e ? const Color(0xFF312E81) : const Color(0xFF134E4A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Kalan %$kalanPayOraniStr Dağıtılır',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          is58e
                              ? 'KDV hariç matrahtan %$hazineOrani Hazine, %$bapOrani BAP ve %$kurumOraniYuzdeStr Birim/Kurum payı kesildikten sonra kalan tutar personele dağıtılır. Gelir Vergisi ve Damga Vergisi kesintisine tabidir.'
                              : 'KDV hariç matrahtan %$hazineOrani Hazine, %$bapOrani BAP ve %$kurumOraniYuzdeStr Kurum kesintisi yapıldıktan sonra kalan %$kalanPayOraniStr sözleşme esaslarına göre personele ödenir (Puan/ek gösterge/saat tavanı uygulanmaz).',
                          style: TextStyle(
                            fontSize: 12,
                            color: is58e ? Colors.indigo.shade900 : Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onCokluPersonelEkle,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('+ Kişi / Hoca Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. DİNAMİK YASAL VE KURUMSAL KESİNTİLER AYAR KARTI
          _buildKesintilerAyarKarti(context),
          const SizedBox(height: 16),

          // 3. 3'LÜ KPI ÖZET KARTLARI
          Row(
            children: [
              // Kart 1: Gelir & Kesintiler
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('KDV Hariç Matrah:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                Text(TurkceFormat.para(kdvHaric), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Toplam Kesinti (%$toplamKesintiOraniStr):',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                                Text(
                                  TurkceFormat.para(toplamKesintiTutari),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Kart 2: Dağıtılacak Toplam Pay
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.savings_outlined, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              is58e
                                  ? 'Toplam Dağıtılabilir Pay (%$kalanPayOraniStr):'
                                  : 'Sözleşme Dağıtılabilir Pay (%$kalanPayOraniStr):',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(TurkceFormat.para(katkiPayi), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                            Text(odemeTekSeferde ? 'Tek seferde ödenecek' : '$toplamTaksitSayisi aya bölünecek', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Kart 3: Bu Ay Ödenecek & Kalan Bakiye
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check_circle_outline_rounded, color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  is58e ? 'Net Ele Geçecek Tutar:' : 'Bu Ayki Taksit Payı:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                                  ),
                                ),
                                Text(
                                  TurkceFormat.para(buAykiPay),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Devreden Kalan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                Text(
                                  TurkceFormat.para(kalanBakiye),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kalanBakiye > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. SÖZLEŞME VE TAKSİT KONTROL KARTI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCCFBF1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment_rounded, color: Color(0xFF0F766E), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Sözleşme Ödeme Yöntemi:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('1 Defada (Tek Seferde) Öde'),
                          icon: Icon(Icons.flash_on_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Sözleşmeye Göre Taksitlendir'),
                          icon: Icon(Icons.calendar_month_rounded, size: 16),
                        ),
                      ],
                      selected: {odemeTekSeferde},
                      onSelectionChanged: (set) {
                        onOdemeTekSeferdeDegisti?.call(set.first);
                      },
                    ),
                  ],
                ),
                if (!odemeTekSeferde) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sözleşme Süresi (Ay / Taksit):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: toplamTaksitSayisi,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              items: [2, 3, 4, 5, 6, 8, 10, 12, 18, 24].map((ay) {
                                return DropdownMenuItem(value: ay, child: Text('$ay Ay ($ay Taksit)'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) onToplamTaksitSayisiDegisti?.call(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ödenen Taksit Sırası:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: aktifTaksitNo > toplamTaksitSayisi ? 1 : aktifTaksitNo,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              items: List.generate(toplamTaksitSayisi, (i) => i + 1).map((no) {
                                return DropdownMenuItem(value: no, child: Text('$no. Taksit'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) onAktifTaksitNoDegisti?.call(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Bu Ay Ödenecek Taksit Tutarı:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                if (ozelTaksitTutari != null)
                                  InkWell(
                                    onTap: () {
                                      ozelTaksitController?.clear();
                                      onOzelTaksitTutariDegisti?.call(null);
                                    },
                                    child: const Text('Eşit Bölmeye Sıfırla', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: ozelTaksitController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: TurkceFormat.para(katkiPayi / toplamTaksitSayisi),
                                suffixText: 'TL',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                final d = double.tryParse(val.replaceAll('.', '').replaceAll(',', '.').trim());
                                onOzelTaksitTutariDegisti?.call(d);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _buildTarihVeDonemAlani(context),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. AKADEMİK PERSONEL LİSTESİ (58/k İÇİN SADELEŞTİRİLMİŞ)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined, color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        is58e ? '58/e Danışman ve Araştırmacı Personel Listesi' : 'Danışman Öğretim Elemanı / Araştırmacı Listesi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      const Spacer(),
                      Text(
                        'Toplam ${personeller.length} personel',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (is58e) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 8),
                          const Text(
                            'Gelir Vergisi (Stopaj) Dilimi:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: gelirVergisiOrani,
                            underline: const SizedBox(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 13),
                            items: [15, 20, 27, 35, 40].map((o) => DropdownMenuItem(value: o, child: Text('%$o'))).toList(),
                            onChanged: (val) {
                              if (val != null) onGelirVergisiOraniDegisti?.call(val);
                            },
                          ),
                          const Spacer(),
                          const Text(
                            'Damga Vergisi: %0,759 (Yasal Sabit)',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (personeller.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('Henüz personel eklenmedi.', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: onPersonelEkle,
                              icon: const Icon(Icons.add),
                              label: const Text('Personel Ekle'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: personeller.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final p = personeller[index];
                        final sonuc = excelSonuc.personelSatirlari.length > index
                            ? excelSonuc.personelSatirlari[index]
                            : null;
                        final brutPay = sonuc?.brutHakedis ?? 0.0;
                        final gelirVergisi = brutPay * (gelirVergisiOrani / 100);
                        final damgaVergisi = brutPay * 0.00759;
                        final netPay = is58k ? brutPay : (brutPay - gelirVergisi - damgaVergisi);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: (is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E)).withValues(alpha: 0.1),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Unvan Seçici
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<String>(
                                initialValue: unvanListesi.contains(p.unvan) ? p.unvan : unvanNormalize(p.unvan),
                                decoration: const InputDecoration(isDense: true, labelText: 'Unvan', border: OutlineInputBorder()),
                                items: unvanListesi.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    onPersonelGuncelle(
                                      index,
                                      p.copyWith(
                                        unvan: val,
                                        unvanKatsayisi: DanismanlikExcelHesaplama.unvanKatsayisi(val),
                                        ekGosterge: DanismanlikExcelHesaplama.ekGosterge(val),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Ad Soyad
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: p.adSoyad,
                                decoration: const InputDecoration(isDense: true, labelText: 'Adı Soyadı', border: OutlineInputBorder()),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                onChanged: (val) => onPersonelGuncelle(index, p.copyWith(adSoyad: val)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Sözleşme Pay Oranı (%)
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                initialValue: p.puan > 0 ? p.puan.toStringAsFixed(0) : '100',
                                decoration: const InputDecoration(isDense: true, labelText: 'Sözleşme Payı %', suffixText: '%', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (val) {
                                  final d = double.tryParse(val) ?? 100.0;
                                  onPersonelGuncelle(index, p.copyWith(puan: d));
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Brüt ve Net Hak Ediş Kutusu
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: is58e ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: is58e ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (is58e) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Brüt Hak Ediş: ', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                                        Text(TurkceFormat.para(brutPay), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Stopaj (%$gelirVergisiOrani) + DV: ', style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
                                        Text('-${TurkceFormat.para(gelirVergisi + damgaVergisi)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Net Ele Geçecek: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                        Text(TurkceFormat.para(netPay), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Ödenecek Net Tutar: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                        Text(TurkceFormat.para(netPay), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('2547 s.k. 58/k Vergiden Muaf (Kesintisiz)', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => onPersonelSil(index),
                              tooltip: 'Personeli Sil',
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 5. TOPLAM DAĞITIM VE BAKİYE İCMALİ (58/k ve 58/e İçin Özel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: is58e ? const Color(0xFFC7D2FE) : const Color(0xFF99F6E4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.payments_rounded, color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Toplam ${personeller.length} Kişiye Dağıtılan Hakediş: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155)),
                ),
                Text(
                  TurkceFormat.para(excelSonuc.netOdemeToplam),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: is58e ? const Color(0xFF4F46E5) : const Color(0xFF0F766E),
                  ),
                ),
                const Spacer(),
                if (kalanBakiye > 0) ...[
                  const Text('Gelecek Aylara Kalan Bakiye: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  Text(
                    TurkceFormat.para(kalanBakiye),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFD97706)),
                  ),
                ] else ...[
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF107C41), size: 18),
                  const SizedBox(width: 4),
                  const Text('Tüm Pay Eksiksiz Dağıtıldı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarihVeDonemAlani(BuildContext context) {
    final baslangic = sozlesmeBaslangicTarihi ?? DateTime(2026, 7, 24);
    final effectiveTaksitNo = odemeTekSeferde ? 1 : (aktifTaksitNo > toplamTaksitSayisi ? 1 : aktifTaksitNo);
    final donemStart = ManuelHesaplamaVerisi.addMonths(baslangic, effectiveTaksitNo - 1);
    final donemEnd = ManuelHesaplamaVerisi.addMonths(baslangic, effectiveTaksitNo);
    final sozlesmeEnd = ManuelHesaplamaVerisi.addMonths(baslangic, odemeTekSeferde ? 1 : toplamTaksitSayisi);
    final otomatikDonemStr = '${TurkceFormat.tarih(donemStart)} - ${TurkceFormat.tarih(donemEnd)}';
    final aktifDonemStr = (danismanlikDonemi != null && danismanlikDonemi!.trim().isNotEmpty)
        ? danismanlikDonemi!.trim()
        : otomatikDonemStr;
    final aylarStr = '${ManuelHesaplamaVerisi.ayAdiYil(donemStart)} - ${ManuelHesaplamaVerisi.ayAdiYil(donemEnd)}';
    final sozlesmeAylarStr = '${ManuelHesaplamaVerisi.ayAdiYil(baslangic)} - ${ManuelHesaplamaVerisi.ayAdiYil(sozlesmeEnd)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              const Text(
                'Danışmanlık Hizmet Dönemi & Takvimi (58/k):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sözleşme Kapsamı: ${TurkceFormat.tarih(baslangic)} - ${TurkceFormat.tarih(sozlesmeEnd)} ($sozlesmeAylarStr)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Sözleşme Başlangıç Tarihi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sözleşme Başlangıç Tarihi:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: baslangic,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          onSozlesmeBaslangicDegisti?.call(picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              TurkceFormat.tarih(baslangic),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_calendar_outlined, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Aktif Taksit Hizmet Dönemi (Örn: 24.07.2026 - 24.08.2026)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          odemeTekSeferde
                              ? 'Danışmanlık Hizmet Dönemi (Tarih Aralığı):'
                              : '$effectiveTaksitNo. Taksit Hizmet Dönemi (Tarih Aralığı):',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '($aylarStr)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: ValueKey('donem_${effectiveTaksitNo}_${baslangic.toIso8601String()}'),
                      initialValue: aktifDonemStr,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        hintText: 'Örn: 24.07.2026 - 24.08.2026',
                        prefixIcon: const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF0F766E)),
                        suffixIcon: (danismanlikDonemi != null && danismanlikDonemi!.isNotEmpty && danismanlikDonemi != otomatikDonemStr)
                            ? IconButton(
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: 'Otomatik Tarihe Dön ($otomatikDonemStr)',
                                onPressed: () => onDanismanlikDonemiDegisti?.call(''),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      onChanged: (val) => onDanismanlikDonemiDegisti?.call(val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!odemeTekSeferde) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(toplamTaksitSayisi, (i) {
                  final no = i + 1;
                  final isSecili = no == aktifTaksitNo;
                  final tStart = ManuelHesaplamaVerisi.addMonths(baslangic, i);
                  final tEnd = ManuelHesaplamaVerisi.addMonths(baslangic, no);
                  return InkWell(
                    onTap: () {
                      onAktifTaksitNoDegisti?.call(no);
                      onDanismanlikDonemiDegisti?.call('${TurkceFormat.tarih(tStart)} - ${TurkceFormat.tarih(tEnd)}');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSecili ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSecili ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        '$no. Taksit: ${TurkceFormat.tarih(tStart)} - ${TurkceFormat.tarih(tEnd)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSecili ? FontWeight.bold : FontWeight.w500,
                          color: isSecili ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _ekDersAyarlariDialogGoster(BuildContext context) {
    bool localTavan = tavanUygula;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final unvanOrnekleri = [
              {'unvan': 'Profesör', 'gosterge': 300},
              {'unvan': 'Doçent', 'gosterge': 250},
              {'unvan': 'Dr. Öğr. Üyesi', 'gosterge': 200},
              {'unvan': 'Öğr. Gör. Dr. / Öğretim Görevlisi', 'gosterge': 160},
              {'unvan': 'Arş. Gör. / Araştırma Görevlisi', 'gosterge': 160},
            ];

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ek Ders Saat Fiyatı & Katsayı Ayarları',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '2547 ve 2914 Sayılı Kanunlara göre saatlik ek ders ve tavan hesaplama parametreleri',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KART 1: Yasal Tavan Uygulama Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: localTavan ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: localTavan ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              localTavan ? Icons.verified_user_outlined : Icons.gpp_bad_outlined,
                              color: localTavan ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localTavan
                                        ? 'Yasal Tavan Bilgi Notu & Analizi: AKTİF'
                                        : 'Yasal Tavan Bilgi Notu: KAPALI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: localTavan ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    localTavan
                                        ? '2547 s.k. Madde 58 uyarınca hakediş tam ödenir; 2914 s.k. ek ders saatlik tavanı mevzuat ve denetim incelemesi amacıyla analiz edilir.'
                                        : 'Saatlik tavan sınırlaması analiz edilmez; personelin hak ettiği brüt tutar tam olarak personele ödenir.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: localTavan ? const Color(0xFF166534) : const Color(0xFF7F1D1D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: localTavan,
                              activeThumbColor: const Color(0xFF16A34A),
                              onChanged: (val) {
                                setDialogState(() {
                                  localTavan = val;
                                });
                                onTavanUygulaDegisti?.call(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // KART 2: Memur Maaş Katsayısı
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Memur Maaş Katsayısı',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                                Spacer(),
                                Text(
                                  'Varsayılan: 1.387871',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hazine ve Maliye Bakanlığı Genelgesi ile belirlenen katsayıdır. Değiştirildiğinde tüm saatlik tavan ücretleri anında güncellenir.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 36,
                                  child: TextFormField(
                                    controller: memurMaasKatsayisiController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    onChanged: (val) {
                                      final d = double.tryParse(val.replaceAll(',', '.').trim());
                                      if (d != null && d > 0) {
                                        onMemurMaasKatsayisiDegisti(d);
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (onMemurMaasKatsayisiKaydet != null)
                                  ElevatedButton.icon(
                                    onPressed: onMemurMaasKatsayisiKaydet,
                                    icon: const Icon(Icons.save_outlined, size: 15),
                                    label: const Text('Sisteme Kaydet', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    memurMaasKatsayisiController.text = memurMaasKatsayisi.toString();
                                    onMemurMaasKatsayisiDegisti(memurMaasKatsayisi);
                                    setDialogState(() {});
                                  },
                                  child: const Text('Kayıtlıya Dön', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // KART 3: Unvan Bazlı Saatlik Ücretler Canlı Tablosu
                      const Text(
                        'Unvan Bazlı Ek Göstergeler ve Hesaplanan Saatlik Tavan Ücretleri (Canlı)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.2),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(2.0),
                            3: FlexColumnWidth(2.0),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: [
                                _tabloHucre('Unvan', isHeader: true),
                                _tabloHucre('Ek Gösterge', isHeader: true, align: TextAlign.center),
                                _tabloHucre('Mesai İçi (2.0x)\nSaat Ücreti', isHeader: true, align: TextAlign.right),
                                _tabloHucre('Mesai Dışı (3.2x)\nSaat Ücreti', isHeader: true, align: TextAlign.right),
                              ],
                            ),
                            for (final item in unvanOrnekleri) ...[
                              TableRow(
                                decoration: BoxDecoration(
                                  color: unvanOrnekleri.indexOf(item) % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                ),
                                children: [
                                  _tabloHucre(item['unvan'] as String),
                                  _tabloHucre('${item['gosterge']}', align: TextAlign.center),
                                  _tabloHucre(
                                    TurkceFormat.para((item['gosterge'] as int) * memurMaasKatsayisi * 2),
                                    align: TextAlign.right,
                                    color: const Color(0xFF1D4ED8),
                                    isBold: true,
                                  ),
                                  _tabloHucre(
                                    TurkceFormat.para((item['gosterge'] as int) * memurMaasKatsayisi * 3.2),
                                    align: TextAlign.right,
                                    color: const Color(0xFFB45309),
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Formül: Ek Gösterge × Memur Maaş Katsayısı × [Mesai İçi: 2.0 / Mesai Dışı: 3.2].\n'
                                'Öğr. Gör. Dr. ve Öğretim Görevlileri 160 ek gösterge ve 2.0 unvan katsayısına tabidir.\n'
                                'Hocanın alacağı tutar tavanı aşıyorsa tablodaki "Ders Saati" artırılarak alabileceği tutar yükseltilebilir.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Tamam / Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _tabloHucre(
    String text, {
    bool isHeader = false,
    TextAlign align = TextAlign.left,
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? (isHeader ? const Color(0xFF475569) : const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}

/// Kesinti oranını hem elle yazmaya hem de açılır listeden hızlı seçmeye izin veren girdi bileşeni.
class _KesintiOranKutusu extends StatefulWidget {
  final String etiket;
  final num deger;
  final List<num> hazirSecenekler;
  final ValueChanged<num> onDegisti;

  const _KesintiOranKutusu({
    required this.etiket,
    required this.deger,
    required this.hazirSecenekler,
    required this.onDegisti,
  });

  @override
  State<_KesintiOranKutusu> createState() => _KesintiOranKutusuState();
}

class _KesintiOranKutusuState extends State<_KesintiOranKutusu> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatDeger(widget.deger));
    _focusNode.addListener(_onFocusChange);
  }

  String _formatDeger(num v) {
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toString();
  }

  @override
  void didUpdateWidget(covariant _KesintiOranKutusu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deger != widget.deger && !_focusNode.hasFocus) {
      _controller.text = _formatDeger(widget.deger);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _degeriUygula();
    }
  }

  void _degeriUygula() {
    final raw = _controller.text.replaceAll(',', '.').trim();
    final parsed = num.tryParse(raw);
    if (parsed != null && parsed >= 0 && parsed <= 100) {
      widget.onDegisti(parsed);
    } else {
      _controller.text = _formatDeger(widget.deger);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secenekler = widget.hazirSecenekler.contains(widget.deger)
        ? widget.hazirSecenekler
        : ([...widget.hazirSecenekler, widget.deger]..sort());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.etiket}: ',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '%',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 32,
                  height: 24,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _degeriUygula(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<num>(
            tooltip: 'Hazır Oran Seç',
            icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxHeight: 250),
            onSelected: (val) {
              _controller.text = _formatDeger(val);
              widget.onDegisti(val);
            },
            itemBuilder: (ctx) => secenekler.map((val) {
              final isSelected = (val == widget.deger);
              return PopupMenuItem<num>(
                value: val,
                height: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '%$val',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12,
                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check, size: 14, color: Color(0xFF4F46E5)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

