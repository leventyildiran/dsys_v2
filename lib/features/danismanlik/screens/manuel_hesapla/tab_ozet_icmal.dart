import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_manuel_pdf_servisi.dart';

class TabOzetIcmal extends StatelessWidget {
  const TabOzetIcmal({
    super.key,
    required this.veri,
    required this.onYazdir,
  });

  final ManuelHesaplamaVerisi veri;
  final VoidCallback onYazdir;

  @override
  Widget build(BuildContext context) {
    final kesinti = veri.kesintiSonuc;
    final excel = veri.excelSonuc;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 880),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Buton & Başlık
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          veri.kurumAdi,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                          textAlign: TextAlign.center,
                        ),
                        if (veri.rektorlukAdi.trim().isNotEmpty)
                          Text(
                            veri.rektorlukAdi,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        if (veri.mudurlukAdi.trim().isNotEmpty &&
                            veri.mudurlukAdi.trim().toLowerCase() != veri.rektorlukAdi.trim().toLowerCase())
                          Text(
                            veri.mudurlukAdi,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            veri.hizmetBasligi,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 1.5),
              const SizedBox(height: 16),

              // 2 Kolon Grid İcmal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol Kart: Gelir & Kesintiler
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '1. GELİR VE KESİNTİ TABLOSU',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E293B)),
                          ),
                          const Divider(height: 16),
                          _satir('Toplam Fatura Tutarı (KDV Dahil)', TurkceFormat.para(veri.toplamTutar), kalin: true),
                          _satir('KDV Oranı & Tutarı', '%${veri.kdvOrani} (${TurkceFormat.para(veri.kdvTutari)})'),
                          _satir('GELİR (KDV Hariç Matrah)', TurkceFormat.para(kesinti.kdvHaricGelir), kalin: true, renk: const Color(0xFF0284C7)),
                          const SizedBox(height: 8),
                          const Text(
                            'Aktarılacak Yasal Paylar:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          _satir('• Hazine Payı (%${veri.hazineOrani})', TurkceFormat.para(kesinti.hazinePayi)),
                          _satir('• BAP Payı (%${veri.bapOrani})', TurkceFormat.para(kesinti.bapPayi)),
                          _satir('• Araç Gereç Payı (%${(veri.aracGerecOrani * 100).toStringAsFixed(0)})', TurkceFormat.para(kesinti.aracGerecPayi)),
                          const Divider(height: 16),
                          _satir('Dağıtılabilir Katkı Payı', TurkceFormat.para(kesinti.katkiPayi), kalin: true, renk: const Color(0xFF4338CA)),
                          _satir('Maks. Akademik Pay (%49)', TurkceFormat.para(kesinti.dagMaksAkademikPay), kalin: true, renk: const Color(0xFF3730A3)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Sağ Kart: Katsayı & Dağıtım (58/k ise Sözleşme & Taksit İcmali)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            veri.is58k ? '2. SÖZLEŞME & TAKSİT İCMALİ (58/k)' : '2. KATSAYI VE HAKEDİŞ DAĞITIMI',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E293B)),
                          ),
                          const Divider(height: 16),
                          if (veri.is58k) ...[
                            _satir('Ödeme Türü', veri.odemeTekSeferde ? 'Tek Seferde Tam Ödeme' : '${veri.toplamTaksitSayisi} Taksitli Ödeme', kalin: true),
                            if (!veri.odemeTekSeferde) ...[
                              _satir('Aktif Taksit No', '${veri.aktifTaksitNo} / ${veri.toplamTaksitSayisi}. Taksit', kalin: true, renk: const Color(0xFF2563EB)),
                              if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                                _satir('Danışmanlık Hizmet Dönemi', veri.aktifTaksitTarihAraligi, kalin: true, renk: const Color(0xFF0F766E)),
                              if (veri.aylarMetni.isNotEmpty)
                                _satir('Danışmanlık Yapılan Aylar', veri.aylarMetni, kalin: false, renk: const Color(0xFF1E293B)),
                              _satir('Bu Ayki Taksit Tutarı', TurkceFormat.para(veri.buAykiDagitilacakPay58k), kalin: true, renk: const Color(0xFF107C41)),
                              _satir('Gelecek Aylara Kalan Bakiye', TurkceFormat.para(veri.kalanDevredenBakiye58k), kalin: true, renk: const Color(0xFFD97706)),
                            ] else ...[
                              if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                                _satir('Danışmanlık Hizmet Dönemi', veri.aktifTaksitTarihAraligi, kalin: true, renk: const Color(0xFF0F766E)),
                              _satir('Net Ödenecek Hakediş Tutarı (%85)', TurkceFormat.para(kesinti.katkiPayi), kalin: true, renk: const Color(0xFF107C41)),
                            ],
                            if (veri.sozlesmeSuresiMetni.isNotEmpty)
                              _satir('Sözleşme Süresi & Kapsamı', veri.sozlesmeSuresiMetni, kalin: false, renk: const Color(0xFF475569)),
                            _satir('Puan & Dönem Katsayısı', 'Mevzuat Gereği Yoktur (Muaf)', kalin: false, renk: const Color(0xFF64748B)),
                            _satir('3,2 Katı Saat Tavanı', 'Uygulanmaz (Doğrudan Hakediş)', kalin: false, renk: const Color(0xFF0F766E)),
                          ] else ...[
                            _satir('Toplam Net Katkı Puanı', excel.toplamPuan.toStringAsFixed(0), kalin: true),
                            _satir('Dönem Ek Ödeme Katsayısı', TurkceFormat.katsayi(excel.donemKatsayi), kalin: true, renk: const Color(0xFF047857)),
                            _satir('Hesaplama Sağlaması (Puan x Katsayı)', TurkceFormat.para(excel.saglama)),
                            _satir('Net Ödenecek Hakediş Toplamı', TurkceFormat.para(excel.netOdemeToplam), kalin: true, renk: const Color(0xFF107C41)),
                            _satir('Artık Bakiye (Birim Havuzu)', TurkceFormat.para(excel.artikBakiye)),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: excel.saglama <= kesinti.katkiPayi + 0.01
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: excel.saglama <= kesinti.katkiPayi + 0.01
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  excel.saglama <= kesinti.katkiPayi + 0.01
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded,
                                  size: 18,
                                  color: excel.saglama <= kesinti.katkiPayi + 0.01
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    excel.saglama <= kesinti.katkiPayi + 0.01
                                        ? (veri.is58k ? 'Güvenli: %85 net hakediş ve taksit tutarı sınır dahilindedir.' : 'Güvenli: Sağlama tutarı dağıtılabilir katkı payı tavanını aşmamaktadır.')
                                        : 'UYARI: Dağıtılan tutar hak edilen payı aşmaktadır!',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: excel.saglama <= kesinti.katkiPayi + 0.01
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFF991B1B),
                                    ),
                                  ),
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
              const SizedBox(height: 20),

              // Personel Dağıtım Özeti Tablosu
              Text(
                veri.is58k ? '3. PERSONEL SÖZLEŞMELİ HAKEDİŞ DAĞITIMI' : '3. PERSONEL DAĞITIM VE TAVAN İCMALİ',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(flex: 3, child: Text('Adı Soyadı / Unvan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          if (veri.is58k) ...[
                            const SizedBox(width: 100, child: Text('Sözleşme Payı', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 120, child: Text('Puan & Katsayı', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B)))),
                          ] else ...[
                            const SizedBox(width: 60, child: Text('Saat', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 80, child: Text('Net Puan', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 90, child: Text('Saatlik Ücret', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 90, child: Text('Ek Ders Tavan', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          ],
                          const SizedBox(width: 120, child: Text('Ödenecek Tutar (TL)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF047857)))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    ...excel.personelSatirlari.map((s) {
                      final p = s.girdi;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${p.unvan} ${p.adSoyad}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                              ),
                            ),
                            if (veri.is58k) ...[
                              const SizedBox(
                                width: 100,
                                child: Text('%100 (Sözleşmeli)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                              ),
                              const SizedBox(
                                width: 120,
                                child: Text('Muaf (Puan Yok)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            ] else ...[
                              SizedBox(
                                width: 60,
                                child: Text('${p.dersSaati.toStringAsFixed(0)} Saat', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(s.bireyselNetKatkiPuani.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(TurkceFormat.para(s.kursSaatlikUcreti), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(TurkceFormat.para(s.tavanSaatlikUcreti), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            ],
                            SizedBox(
                              width: 120,
                              child: Text(
                                TurkceFormat.para(s.odenebilirHakedis),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF107C41)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Yasal Şerh Kutusu (58/k veya 58/c)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: veri.is58k
                      ? const Color(0xFFEFF6FF)
                      : (excel.herhangiBirTavanAsildi ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: veri.is58k
                        ? const Color(0xFFBFDBFE)
                        : (excel.herhangiBirTavanAsildi ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          veri.is58k
                              ? Icons.assignment_turned_in_outlined
                              : (excel.herhangiBirTavanAsildi ? Icons.balance : Icons.verified_outlined),
                          size: 20,
                          color: veri.is58k
                              ? const Color(0xFF1D4ED8)
                              : (excel.herhangiBirTavanAsildi ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          veri.is58k
                              ? '2547 Sayılı Kanun Madde 58/k Uyarınca Sözleşmeli Danışmanlık Şerhi'
                              : '2547 ve 2914 Sayılı Kanunlar Uyarınca 3,2 Katı Yasal Tavan Şerhi',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: veri.is58k
                                ? const Color(0xFF1E40AF)
                                : (excel.herhangiBirTavanAsildi ? const Color(0xFF92400E) : const Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      veri.is58k
                          ? 'İşbu ödeme, 2547 sayılı Kanun Madde 58/k uyarınca yapılan sanayi/bireysel danışmanlık sözleşmesine istinaden tahakkuk ettirilmiştir. Matrah üzerinden %15 kurum/araç-gereç payı kesildikten sonra kalan %85 tutar doğrudan danışmana ${veri.odemeTekSeferde ? "tek seferde" : "sözleşme taksitlerine bölünerek"} ödenmektedir. Puan hesabı ve saatlik ek ders tavanı aranmaz.'
                          : (excel.herhangiBirTavanAsildi
                              ? 'İşbu hesaplamada yer alan ve hesaplanan saatlik ücreti mesai dışı 3,2 katını (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) aşan personele yasal tavan uygulanmış; tavanı aşan toplam ${TurkceFormat.para(excel.toplamTavanKesintisi)} tutar döner sermaye birim havuzuna devredilmiştir. Hiçbir personele yasal tavanın üzerinde ödeme yapılmamıştır.'
                              : 'İşbu hesaplama icmalinde yer alan tüm öğretim elemanlarının saatlik ücretleri, 2914 sayılı Kanun uyarınca belirlenen mesai dışı ek ders ücreti tavanı olan 3,2 katını (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) GEÇMEMİŞTİR. Dağıtım ve ödemeler mevzuata tam uygundur.'),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: veri.is58k
                            ? const Color(0xFF1E3A8A)
                            : (excel.herhangiBirTavanAsildi ? const Color(0xFF78350F) : const Color(0xFF14532D)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Yazdır / PDF İndir Butonu
              Center(
                child: ElevatedButton.icon(
                  onPressed: onYazdir,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Bu Özeti ve Tüm Sayfaları Yazdır / PDF İndir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _satir(String etiket, String deger, {bool kalin = false, Color? renk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiket,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: kalin ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
          Text(
            deger,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: kalin ? FontWeight.w800 : FontWeight.w600,
              color: renk ?? (kalin ? const Color(0xFF0F172A) : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}
