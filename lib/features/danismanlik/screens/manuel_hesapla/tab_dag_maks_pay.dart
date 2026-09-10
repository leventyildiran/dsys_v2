import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_excel_hesaplama.dart';

class TabDagMaksPay extends StatelessWidget {
  const TabDagMaksPay({
    super.key,
    required this.kesinti,
    required this.toplamTutar,
    required this.kdvTutari,
    required this.kdvOrani,
    required this.hazineOrani,
    required this.bapOrani,
    required this.aracGerecOrani,
    required this.onOranlariGuncelle,
  });

  final ExcelKesintiSonuc kesinti;
  final double toplamTutar;
  final double kdvTutari;
  final int kdvOrani;
  final int hazineOrani;
  final int bapOrani;
  final double aracGerecOrani;
  final void Function(int hazine, int bap, double aracGerec) onOranlariGuncelle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bilgilendirme
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
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart_outline, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dağıtılacak Maksimum Pay ve Gelir Payları',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          'Excel "DAĞ. MAKS. PAY. HESAPLAMA" sayfasına ait yasal pay kesintileri.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2 Kolon Düzen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol Kolon: Üst Tablo (GELİR, KDV, TOPLAM)
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'DAĞ. MAKS. PAY. HESAPLAMA',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const Divider(thickness: 1, height: 20),
                      _bilgiSatiri('GELİR (KDV Hariç)', TurkceFormat.para(kesinti.kdvHaricGelir), kalin: true),
                      const SizedBox(height: 8),
                      _bilgiSatiri('%$kdvOrani KDV', TurkceFormat.para(kdvTutari)),
                      const SizedBox(height: 8),
                      _bilgiSatiri('TOPLAM TUTAR', TurkceFormat.para(toplamTutar), kalin: true, renk: const Color(0xFF107C41)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Matrah Açıklaması',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gelirden aktarılacak yasal paylar, KDV hariç gelir (${TurkceFormat.para(kesinti.kdvHaricGelir)}) üzerinden hesaplanmaktadır.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Sağ Kolon: Alt Tablo ("GELİRDEN AKTARILACAK PAYLAR")
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'GELİRDEN AKTARILACAK PAYLAR',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const Divider(thickness: 1, height: 20),
                      _paySatiri(
                        etiket: 'HAZİNE PAYI (%$hazineOrani)',
                        tutar: kesinti.hazinePayi,
                        aciklama: 'Gelirin %$hazineOrani Hazine ve Maliye Bakanlığı hesabına aktarılır',
                      ),
                      const SizedBox(height: 10),
                      _paySatiri(
                        etiket: 'BİLİMSEL ARAŞTIRMA PROJELERİ (%$bapOrani)',
                        tutar: kesinti.bapPayi,
                        aciklama: 'Gelirin %$bapOrani BAP birimi hesabına aktarılır',
                      ),
                      const SizedBox(height: 10),
                      _paySatiri(
                        etiket: 'ARAÇ GEREÇ PAYI (%${(aracGerecOrani * 100).toStringAsFixed(0)})',
                        tutar: kesinti.aracGerecPayi,
                        aciklama: 'Birim altyapı ve sarf giderleri payı',
                      ),
                      const SizedBox(height: 10),
                      _paySatiri(
                        etiket: 'KATKI PAYI (KALAN)',
                        tutar: kesinti.katkiPayi,
                        kalin: true,
                        renk: const Color(0xFF4338CA),
                        aciklama: 'Kalan dağıtılabilir pay (Gelir - Hazine - BAP - Araç)',
                      ),
                      const Divider(thickness: 1, height: 20),
                      _bilgiSatiri('TOPLAM KESİNTİ VE PAYLAR', TurkceFormat.para(kesinti.toplam), kalin: true),
                      const Divider(thickness: 1, height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_outlined, color: Color(0xFF4F46E5), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DAĞ. MAKS. AKADEMİK PAY (%49)',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3730A3)),
                                  ),
                                  Text(
                                    'Akademik personele ödenebilecek yasal üst sınır (%49)',
                                    style: TextStyle(fontSize: 11, color: Colors.indigo.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              TurkceFormat.para(kesinti.dagMaksAkademikPay),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF3730A3)),
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
        ],
      ),
    );
  }

  Widget _bilgiSatiri(String etiket, String deger, {bool kalin = false, Color? renk}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiket,
          style: TextStyle(
            fontSize: 13,
            fontWeight: kalin ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF334155),
          ),
        ),
        Text(
          deger,
          style: TextStyle(
            fontSize: 14,
            fontWeight: kalin ? FontWeight.w800 : FontWeight.w600,
            color: renk ?? (kalin ? const Color(0xFF0F172A) : const Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _paySatiri({
    required String etiket,
    required double tutar,
    required String aciklama,
    bool kalin = false,
    Color? renk,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiket,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: kalin ? FontWeight.w700 : FontWeight.w600,
                    color: renk ?? const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  aciklama,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Text(
            TurkceFormat.para(tutar),
            style: TextStyle(
              fontSize: 14,
              fontWeight: kalin ? FontWeight.w800 : FontWeight.w600,
              color: renk ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
