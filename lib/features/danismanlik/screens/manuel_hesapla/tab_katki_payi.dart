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
  });

  final DanismanlikExcelSonuc excelSonuc;
  final List<ExcelPersonelGirdi> personeller;
  final double maksAkademikPay;
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

  static const List<String> unvanListesi = [
    'Profesör',
    'Doçent',
    'Dr. Öğr. Üyesi',
    'Öğr. Gör. Dr.',
    'Öğr. Gör.',
    'Arş. Gör. Dr.',
    'Arş. Gör.',
  ];

  @override
  Widget build(BuildContext context) {
    if (is58k) {
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
                                const Text(
                                  'Kalan Artık Bakiye:',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                                Text(
                                  TurkceFormat.para(excelSonuc.artikBakiye),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: excelSonuc.artikBakiye > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
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
                      else
                        Text(
                          TurkceFormat.katsayi(excelSonuc.donemKatsayi),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF047857)),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Sağlama: ${TurkceFormat.para(excelSonuc.saglama)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3,2 Katı Yasal Tavan Bilgilendirme ve Akıllı Mutemet Önerisi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      excelSonuc.herhangiBirTavanAsildi ? Icons.warning_amber_rounded : Icons.verified_outlined,
                      size: 18,
                      color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFD97706) : const Color(0xFF15803D),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      excelSonuc.herhangiBirTavanAsildi
                          ? '3,2 KAT YASAL TAVAN KONTROLÜ (2547 ve 2914 Sayılı Kanunlar)'
                          : 'YASAL TAVAN KONTROLÜ: TÜM HOCALAR MEVZUATA UYGUNDUR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFF92400E) : const Color(0xFF166534),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Text(
                        'Azami 3.2 Tavanı: ${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}/Saat',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFFB45309) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  excelSonuc.herhangiBirTavanAsildi
                      ? 'Mevzuat gereğince mesai dışı saatlik ücret 3,2 katı tavanını geçemez. Hesaplanan saatlik ücret bu tavanı aştığı için personele en fazla tavan tutarı (${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}) ödenebilir; aşan toplam ${TurkceFormat.para(excelSonuc.toplamTavanKesintisi)} döner sermaye birim havuzuna devredilir.'
                      : 'Hesaplanan tüm saatlik ücretler, yasal sınır olan 3,2 katı tavanının (${TurkceFormat.para(excelSonuc.maksimumTavanSaatlik)}/Saat) altındadır. Kesinti olmaksızın tam ödeme yapılabilir.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: excelSonuc.herhangiBirTavanAsildi ? const Color(0xFF78350F) : const Color(0xFF14532D),
                  ),
                ),
                if (excelSonuc.herhangiBirTavanAsildi) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '💡 Mutemet Çözüm İpucu: Personelin hak ettiği tutarın tamamını (havuza kesinti olmadan) alabilmesi için tablodaki SAAT değerini artırabilirsiniz (Örn: 5 yerine 6 saat).',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
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
                  ElevatedButton.icon(
                    onPressed: onPersonelEkle,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('+ Kişi Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onCokluPersonelEkle,
                    icon: const Icon(Icons.group_add, size: 16),
                    label: const Text('👥 Çoklu Kişi Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41), // Excel Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                    value: unvanListesi.contains(p.unvan) ? p.unvan : 'Öğr. Gör. Dr.',
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
                                initialValue: p.unvanKatsayisi.toStringAsFixed(1),
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
                              child: Text(
                                TurkceFormat.para(s.kursSaatlikUcreti),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: tavanAsildi ? Colors.redAccent : const Color(0xFF0F172A),
                                ),
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
                      TextButton.icon(
                        onPressed: onPersonelEkle,
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF6366F1)),
                        label: const Text(
                          '+ Tek Kişi Ekle',
                          style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: onCokluPersonelEkle,
                        icon: const Icon(Icons.group_add_outlined, size: 18, color: Color(0xFF107C41)),
                        label: const Text(
                          '👥 Çoklu Kişi / Heyet Ekle',
                          style: TextStyle(color: Color(0xFF107C41), fontWeight: FontWeight.bold, fontSize: 12),
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

  Widget _build58kView(BuildContext context) {
    final kdvHaric = kesinti?.kdvHaricGelir ?? 0.0;
    final aracGerec15 = kesinti?.aracGerecPayi ?? 0.0;
    final katkiPayi85 = kesinti?.katkiPayi ?? maksAkademikPay;
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
              side: BorderSide(color: Colors.teal.shade200),
            ),
            color: const Color(0xFFF0FDFA), // Teal 50
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Color(0xFF0F766E), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '2547 Sayılı Kanun Madde 58/k — Sözleşmeli Danışmanlık',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF134E4A)),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Kalan %85 Doğrudan Ödenir',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bu maddede puanlama, ek gösterge ve saat tavanı uygulanmaz. '
                          'Yatan gelirden %15 kurum kesintisi yapıldıktan sonra kalan %85 sözleşme esaslarına göre doğrudan öğretim elemanına ödenir.',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onPersonelEkle,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Personel Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCokluPersonelEkle,
                    icon: const Icon(Icons.group_add_outlined, size: 16),
                    label: const Text('Çoklu Ekle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. 3'LÜ KPI ÖZET KARTLARI
          Row(
            children: [
              // Kart 1: Gelir & %15 Kesinti
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
                                const Text('%15 Yasal Kesinti:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                Text(TurkceFormat.para(aracGerec15), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
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
              // Kart 2: Dağıtılacak Toplam %85 Hak Ediş
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
                            const Text('Sözleşme Toplam %85 Pay:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(TurkceFormat.para(katkiPayi85), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
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
                    border: Border.all(color: const Color(0xFF0F766E), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0F766E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Bu Ayki Taksit Payı:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                Text(TurkceFormat.para(buAykiPay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
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
                                hintText: TurkceFormat.para(katkiPayi85 / toplamTaksitSayisi),
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
                      const Icon(Icons.people_alt_outlined, color: Color(0xFF0F766E), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Danışman Öğretim Elemanı / Araştırmacı Listesi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      const Spacer(),
                      Text(
                        'Toplam ${personeller.length} personel',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                        final gelirVergisi = brutPay * 0.15;
                        final damgaVergisi = brutPay * 0.00759;
                        final netPay = brutPay - gelirVergisi - damgaVergisi;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            // Unvan Seçici
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<String>(
                                initialValue: unvanListesi.contains(p.unvan) ? p.unvan : 'Dr. Öğr. Üyesi',
                                decoration: const InputDecoration(isDense: true, labelText: 'Unvan', border: OutlineInputBorder()),
                                items: unvanListesi.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) onPersonelGuncelle(index, p.copyWith(unvan: val));
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
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Brüt Hak Ediş: ', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                                      Text(TurkceFormat.para(brutPay), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Net Ödenecek: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                      Text(TurkceFormat.para(netPay), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
                                    ],
                                  ),
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
          // Hoca hakediş özeti
          HocaHakedisOzetKarti(excelSonuc: excelSonuc),
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
}
