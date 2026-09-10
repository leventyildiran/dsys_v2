import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_excel_hesaplama.dart';

/// Excel dosyasındaki sarı başlıklı 3 alt hesaplama tablosunu birebir oluşturan bileşen:
/// 1. DÖNEM EK KATSAYI HESAPLAMA
/// 2. KURSUN 1 SAATLİK ÜCRETİNİ HESAPLAMA
/// 3. 1 SAATLİK EK DERS ÜCRETİ HESAPLAMA (TAVAN)
class ExcelHesaplamaTablolari extends StatelessWidget {
  const ExcelHesaplamaTablolari({
    super.key,
    required this.excelSonuc,
    required this.maksAkademikPay,
    this.memurMaasKatsayisi = DanismanlikExcelHesaplama.memurMaasKatsayisiGuncel,
  });

  final DanismanlikExcelSonuc excelSonuc;
  final double maksAkademikPay;
  final double memurMaasKatsayisi;

  @override
  Widget build(BuildContext context) {
    final personel = excelSonuc.personelSatirlari.isNotEmpty
        ? excelSonuc.personelSatirlari.first
        : null;

    final bireyselPuan = personel?.bireyselNetKatkiPuani ?? excelSonuc.toplamPuan;
    final dersSaati = personel?.girdi.dersSaati ?? 5.0;
    final kursSaatlik = personel?.kursSaatlikUcreti ??
        (dersSaati > 0 ? (bireyselPuan * excelSonuc.donemKatsayi / dersSaati) : 0.0);

    final ekGosterge = personel?.girdi.ekGosterge ?? 160;
    final mesaiIciUcret = ekGosterge * memurMaasKatsayisi * 2;
    final mesaiDisiUcret = ekGosterge * memurMaasKatsayisi * 3.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. DÖNEM EK KATSAYI HESAPLAMA
        _tabloKapsayici(
          baslik: 'DÖNEM EK KATSAYI HESAPLAMA',
          child: Column(
            children: [
              _tabloBaslikSatiri([
                'Dağıtılacak Maksimum\nAkademik Pay',
                'Toplam Puan',
                'Dönem Ek Ödeme\nKatsayı',
                'Sağlaması\n(Toplam Puan X Dönem Ek Katsayı)',
              ]),
              _tabloVeriSatiri([
                TurkceFormat.para(maksAkademikPay),
                excelSonuc.toplamPuan.toStringAsFixed(0),
                TurkceFormat.para(excelSonuc.donemKatsayi),
                TurkceFormat.para(excelSonuc.saglama),
              ], ozelRenkler: [
                null,
                null,
                Colors.red.shade700, // Excel'deki gibi kırmızı katsayı
                const Color(0xFF006100), // Yeşil sağlama
              ]),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: const Color(0xFFFEF9C3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '• Sağlama yaparken sonuç eğer Dağıtılacak Maksimum Akademik Payı aşarsa bir azaltırız.',
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.amber.shade900),
                    ),
                    if (excelSonuc.artikBakiye > 0)
                      Text(
                        'Kalan Artık Pay: ${TurkceFormat.para(excelSonuc.artikBakiye)}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. KURSUN 1 SAATLİK ÜCRETİNİ HESAPLAMA
        _tabloKapsayici(
          baslik: 'KURSUN 1 SAATLİK ÜCRETİNİ HESAPLAMA',
          child: Column(
            children: [
              _tabloBaslikSatiri([
                'Bireysel Net\nKatkı Puanı',
                'Dönem Ek\nÖdeme Katsayı',
                'Verdiği Ders\nSaati',
                'Kursun 1 Saatlik\nÜcreti',
              ]),
              _tabloVeriSatiri([
                bireyselPuan.toStringAsFixed(0),
                excelSonuc.donemKatsayi.toStringAsFixed(2),
                dersSaati.toStringAsFixed(0),
                TurkceFormat.para(kursSaatlik),
              ], ozelRenkler: [
                null,
                null,
                null,
                const Color(0xFF006100),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. 1 SAATLİK EK DERS ÜCRETİ HESAPLAMA (TAVAN)
        _tabloKapsayici(
          baslik: '1 SAATLİK EK DERS ÜCRETİ HESAPLAMA',
          child: Column(
            children: [
              _tabloBaslikSatiri([
                'Ek Gösterge',
                'Aylık Maaş\nKatsayısı',
                'Mesai İçi\nEk Ders 1 Saatlik Ücreti',
                'Mesai Dışı\n%60 Artırımlı Ek Ders 1 Saatlik Ücreti',
              ]),
              _tabloVeriSatiri([
                ekGosterge.toString(),
                memurMaasKatsayisi.toString().replaceAll('.', ','),
                mesaiIciUcret.toStringAsFixed(5).replaceAll('.', ','),
                TurkceFormat.para(mesaiDisiUcret),
              ], ozelRenkler: [
                null,
                null,
                const Color(0xFF1E40AF),
                const Color(0xFF006100),
              ]),
              // Excel'deki mavi kural kutusu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  border: Border(top: BorderSide(color: Color(0xFFBFDBFE))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)),
                          children: [
                            TextSpan(text: 'MESAİ İÇİ: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: 'Eğer Mesai içi ise Ek Ders Ücretinin 2 Katı ücret alabilir.'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)),
                          children: [
                            TextSpan(text: 'MESAİ DIŞI: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: 'Eğer Mesai dışı ise Ek Ders Ücretinin 3,2 Katı (%60 artırımlı) ücret alabilir.'),
                          ],
                        ),
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

  Widget _tabloKapsayici({required String baslik, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sarı Excel başlık şeridi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFFFC000), // Excel altın sarısı
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Text(
              baslik,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.8,
                color: Colors.black,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _tabloBaslikSatiri(List<String> sutunlar) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sutunlar.map((s) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _tabloVeriSatiri(List<String> degerler, {List<Color?>? ozelRenkler}) {
    return Container(
      color: Colors.white,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(degerler.length, (i) {
            final renk = ozelRenkler != null && i < ozelRenkler.length ? ozelRenkler[i] : null;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: renk != null ? renk.withValues(alpha: 0.08) : Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  degerler[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: renk ?? const Color(0xFF111827),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
