import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_manuel_pdf_servisi.dart';

class TabOzetIcmal extends StatelessWidget {
  const TabOzetIcmal({
    super.key,
    required this.veri,
    required this.onYazdir,
    this.onTavanUygulaDegisti,
    this.onHizmetBasligiDegisti,
  });

  final ManuelHesaplamaVerisi veri;
  final VoidCallback onYazdir;
  final ValueChanged<bool>? onTavanUygulaDegisti;
  final ValueChanged<String>? onHizmetBasligiDegisti;

  @override
  Widget build(BuildContext context) {
    final kesinti = veri.kesintiSonuc;
    final excel = veri.excelSonuc;
    final double akademikOran = (kesinti.kdvHaricGelir > 0)
        ? ((kesinti.dagMaksAkademikPay / kesinti.kdvHaricGelir) * 100)
        : (100.0 - veri.hazineOrani - veri.bapOrani - (veri.aracGerecOrani * 100));
    final akademikOranStr = akademikOran.toStringAsFixed(akademikOran % 1 == 0 ? 0 : 1);

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
                        InkWell(
                          onTap: onHizmetBasligiDegisti == null
                              ? null
                              : () => _hizmetBasligiDegistirDialog(context),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  veri.hizmetBasligi.isEmpty
                                      ? '(Personel ve Hizmet Başlığı Belirtilmemiş - Düzenlemek için tıklayın)'
                                      : veri.hizmetBasligi,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                                if (onHizmetBasligiDegisti != null) ...[
                                  const SizedBox(width: 8),
                                  const Tooltip(
                                    message: 'Başlığı Düzenle',
                                    child: Icon(Icons.edit, size: 13, color: Colors.white70),
                                  ),
                                ],
                              ],
                            ),
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
                          if (kesinti.digerPayi > 0 || veri.digerOrani > 0)
                            _satir('• Diğer Kesintiler (%${(veri.digerOrani * 100).toStringAsFixed(0)})', TurkceFormat.para(kesinti.digerPayi)),
                          const Divider(height: 16),
                          _satir('Dağıtılabilir Katkı Payı', TurkceFormat.para(kesinti.katkiPayi), kalin: true, renk: const Color(0xFF4338CA)),
                          _satir('Maks. Akademik Pay (%$akademikOranStr)', TurkceFormat.para(kesinti.dagMaksAkademikPay), kalin: true, renk: const Color(0xFF3730A3)),
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
                            veri.is58k
                                ? '2. SÖZLEŞME & TAKSİT İCMALİ (58/k)'
                                : (veri.is58e
                                    ? '2. SÖZLEŞME & VERGİ İCMALİ (58/e)'
                                    : '2. KATSAYI VE HAKEDİŞ DAĞITIMI'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E293B)),
                          ),
                          const Divider(height: 16),
                          if (veri.is58k || veri.is58e) ...[
                            _satir('Ödeme Türü', veri.odemeTekSeferde ? 'Tek Seferde Tam Ödeme' : '${veri.toplamTaksitSayisi} Taksitli Ödeme', kalin: true),
                            if (!veri.odemeTekSeferde) ...[
                              _satir('Aktif Taksit No', '${veri.aktifTaksitNo} / ${veri.toplamTaksitSayisi}. Taksit', kalin: true, renk: const Color(0xFF2563EB)),
                              if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                                _satir('Danışmanlık Hizmet Dönemi', veri.aktifTaksitTarihAraligi, kalin: true, renk: const Color(0xFF0F766E)),
                              if (veri.aylarMetni.isNotEmpty)
                                _satir('Danışmanlık Yapılan Aylar', veri.aylarMetni, kalin: false, renk: const Color(0xFF1E293B)),
                              _satir('Bu Ayki Brüt Taksit Tutarı', TurkceFormat.para(veri.buAykiDagitilacakPay58k), kalin: true, renk: const Color(0xFF107C41)),
                              _satir('Gelecek Aylara Kalan Bakiye', TurkceFormat.para(veri.kalanDevredenBakiye58k), kalin: true, renk: const Color(0xFFD97706)),
                            ] else ...[
                              if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                                _satir('Danışmanlık Hizmet Dönemi', veri.aktifTaksitTarihAraligi, kalin: true, renk: const Color(0xFF0F766E)),
                              _satir('Brüt Dağıtılabilir Pay (%$akademikOranStr)', TurkceFormat.para(kesinti.katkiPayi), kalin: true, renk: const Color(0xFF107C41)),
                            ],
                            if (veri.is58e) ...[
                              _satir('Gelir Vergisi (Stopaj)', '%${veri.gelirVergisiOrani}', kalin: false, renk: const Color(0xFFDC2626)),
                              _satir('Damga Vergisi', '%0,759 (Yasal Sabit)', kalin: false, renk: const Color(0xFFDC2626)),
                              _satir('Net Ele Geçecek Toplam', TurkceFormat.para(excel.netOdemeToplam), kalin: true, renk: const Color(0xFF047857)),
                            ],
                            if (veri.is58k) ...[
                              _satir('Vergi Muafiyeti', 'Gelir & Damga Vergisi %0 (Muaf)', kalin: false, renk: const Color(0xFF0F766E)),
                              _satir('Net Ödenecek Toplam', TurkceFormat.para(excel.netOdemeToplam), kalin: true, renk: const Color(0xFF047857)),
                            ],
                            if (veri.sozlesmeSuresiMetni.isNotEmpty)
                              _satir('Sözleşme Süresi & Kapsamı', veri.sozlesmeSuresiMetni, kalin: false, renk: const Color(0xFF475569)),
                            _satir('Puan & Dönem Katsayısı', 'Mevzuat Gereği Yoktur (Muaf)', kalin: false, renk: const Color(0xFF64748B)),
                            _satir('Saatlik Ek Ders Tavanı', 'Uygulanmaz (2547 m.58 tavan muafiyeti)', kalin: false, renk: const Color(0xFF0F766E)),
                          ] else ...[
                            _satir('Toplam Net Katkı Puanı', excel.toplamPuan.toStringAsFixed(0), kalin: true),
                            if (veri.tavanUygula && excel.toplamTavanKesintisi > 0) ...[
                              _satir('Gelir Dağıtım Katsayısı (Ham)', TurkceFormat.katsayi(excel.donemKatsayi), kalin: false, renk: const Color(0xFF64748B)),
                              _satir('Fiili Tavan Katsayısı (Ödenen)', TurkceFormat.katsayi(excel.fiiliDonemKatsayisi), kalin: true, renk: const Color(0xFF047857)),
                              _satir('Hesaplama Sağlaması (Brüt Havuz)', TurkceFormat.para(excel.saglama)),
                              _satir('Personele Ödenecek Hakediş', TurkceFormat.para(excel.netOdemeToplam), kalin: true, renk: const Color(0xFF107C41)),
                              _satir('Yasal Tavan Kesintisi (Birim Payı)', TurkceFormat.para(excel.toplamTavanKesintisi), kalin: true, renk: const Color(0xFFD97706)),
                              _satir('Birim Havuzuna Kalan Toplam', TurkceFormat.para(excel.havuzToplam), kalin: true, renk: const Color(0xFF0F766E)),
                            ] else ...[
                              _satir('Dönem Ek Ödeme Katsayısı', TurkceFormat.katsayi(excel.donemKatsayi), kalin: true, renk: const Color(0xFF047857)),
                              _satir('Hesaplama Sağlaması (Puan x Katsayı)', TurkceFormat.para(excel.saglama)),
                              _satir('Net Ödenecek Hakediş Toplamı', TurkceFormat.para(excel.netOdemeToplam), kalin: true, renk: const Color(0xFF107C41)),
                              _satir('Artık Bakiye (Birim Havuzu)', TurkceFormat.para(excel.artikBakiye)),
                            ],
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
                                    (veri.tavanUygula && excel.toplamTavanKesintisi > 0)
                                        ? 'Güvenli: Yasal tavan koruması aktif. ${TurkceFormat.para(excel.netOdemeToplam)} personele tahakkuk ettirildi, ${TurkceFormat.para(excel.havuzToplam)} birim havuzunda emanete alındı.'
                                        : (excel.saglama <= kesinti.katkiPayi + 0.01
                                            ? ((veri.is58k || veri.is58e) ? 'Güvenli: %$akademikOranStr hakediş ve taksit tutarı sınır dahilindedir.' : 'Güvenli: Sağlama tutarı dağıtılabilir katkı payı tavanını aşmamaktadır.')
                                            : 'UYARI: Dağıtılan tutar hak edilen payı aşmaktadır!'),
                                    style: TextStyle(
                                      fontSize: 10.5,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    veri.is58k
                        ? '3. PERSONEL SÖZLEŞMELİ HAKEDİŞ DAĞITIMI'
                        : (veri.is58e
                            ? '3. PERSONEL HAKEDİŞ VE VERGİ KESİNTİLERİ (58/e)'
                            : '3. PERSONEL DAĞITIM VE TAVAN İCMALİ'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                  if (!veri.is58k && !veri.is58e && onTavanUygulaDegisti != null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => onTavanUygulaDegisti!(!veri.tavanUygula),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: veri.tavanUygula ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: veri.tavanUygula ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                veri.tavanUygula ? Icons.balance : Icons.balance_outlined,
                                size: 14,
                                color: veri.tavanUygula ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                veri.tavanUygula ? '⚖️ Tavana Göre Dağıt: AÇIK' : '⚖️ Tavana Göre Dağıt: KAPALI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: veri.tavanUygula ? const Color(0xFF15803D) : const Color(0xFF475569),
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
                            const SizedBox(width: 120, child: Text('Ödenecek Tutar (TL)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF047857)))),
                          ] else if (veri.is58e) ...[
                            const SizedBox(width: 90, child: Text('Sözleşme Payı', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 95, child: Text('Brüt Hakediş', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 85, child: Text('Gelir Vergisi', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFDC2626)))),
                            const SizedBox(width: 80, child: Text('Damga Vergisi', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFDC2626)))),
                            const SizedBox(width: 110, child: Text('Net Tutar (TL)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF047857)))),
                          ] else ...[
                            const SizedBox(width: 50, child: Text('Saat', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 80, child: Text('Mesai', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 70, child: Text('Net Puan', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 85, child: Text('Saatlik Ücret', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 85, child: Text('Ek Ders Tavan', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                            const SizedBox(width: 120, child: Text('Ödenecek Tutar (TL)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF047857)))),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    ...excel.personelSatirlari.map((s) {
                      final p = s.girdi;
                      final brut = s.brutHakedis;
                      final gv = _round(brut * (veri.gelirVergisiOrani / 100), 2);
                      final dv = _round(brut * 0.00759, 2);
                      final net = _round(brut - gv - dv, 2);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _tamAdSoyad(p.unvan, p.adSoyad),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                  if (!veri.is58k && !veri.is58e)
                                    Text(
                                      'Ek Ders Gös: ${p.ekGosterge} · Unvan K: ${p.unvanKatsayisi.toStringAsFixed(1)}',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                            ),
                            if (veri.is58k) ...[
                              SizedBox(
                                width: 100,
                                child: Text(
                                  '%${p.puan > 0 ? p.puan.toStringAsFixed(p.puan % 1 == 0 ? 0 : 1) : '100'} (Sözleşmeli)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(
                                width: 120,
                                child: Text('Muaf (Puan Yok)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  TurkceFormat.para(s.odenebilirHakedis),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF107C41)),
                                ),
                              ),
                            ] else if (veri.is58e) ...[
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '%${p.puan > 0 ? p.puan.toStringAsFixed(p.puan % 1 == 0 ? 0 : 1) : '100'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              SizedBox(
                                width: 95,
                                child: Text(TurkceFormat.para(brut), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text(TurkceFormat.para(gv), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(TurkceFormat.para(dv), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  TurkceFormat.para(net),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF107C41)),
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: 50,
                                child: Text('${p.dersSaati.toStringAsFixed(0)} Sa', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: p.mesaiIci ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.mesaiIci ? 'Mesai İçi' : 'Mesai Dışı',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: p.mesaiIci ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(s.bireyselNetKatkiPuani.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text(TurkceFormat.para(s.kursSaatlikUcreti), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text(TurkceFormat.para(s.tavanSaatlikUcreti), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              SizedBox(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      TurkceFormat.para(s.odenebilirHakedis),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF107C41)),
                                    ),
                                    if (veri.tavanUygula && s.havuzTutari > 0)
                                      Text(
                                        'Tavan Kilitli (-${TurkceFormat.para(s.havuzTutari)})',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (veri.tavanUygula && excel.toplamTavanKesintisi > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF16A34A), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yasal Tavan Dağıtım İcmali (Müdür / Mutemetlik Kuralı)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF15803D)),
                            ),
                            Text(
                              'YK kararındaki ders saatleri sabit tutulmuş, saatlik ücreti tavanı aşan personellere yasal tavan ödenmiştir. Aşan ${TurkceFormat.para(excel.toplamTavanKesintisi)} döner sermaye birim havuzuna aktarılmıştır.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Personele Ödenecek: ${TurkceFormat.para(excel.netOdemeToplam)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF15803D)),
                          ),
                          Text(
                            'Birim Havuzuna Kalan: ${TurkceFormat.para(excel.toplamTavanKesintisi)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Yasal Şerh Kutusu (58/k, 58/e veya kurslar)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (veri.is58k || veri.is58e)
                      ? const Color(0xFFEFF6FF)
                      : (!veri.tavanUygula
                          ? const Color(0xFFF8FAFC)
                          : (excel.herhangiBirTavanAsildi ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4))),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (veri.is58k || veri.is58e)
                        ? const Color(0xFFBFDBFE)
                        : (!veri.tavanUygula
                            ? const Color(0xFFCBD5E1)
                            : (excel.herhangiBirTavanAsildi ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC))),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (veri.is58k || veri.is58e)
                              ? Icons.assignment_turned_in_outlined
                              : (!veri.tavanUygula
                                  ? Icons.info_outline
                                  : (excel.herhangiBirTavanAsildi ? Icons.balance : Icons.verified_outlined)),
                          size: 20,
                          color: (veri.is58k || veri.is58e)
                              ? const Color(0xFF1D4ED8)
                              : (!veri.tavanUygula
                                  ? const Color(0xFF64748B)
                                  : (excel.herhangiBirTavanAsildi ? const Color(0xFFB45309) : const Color(0xFF15803D))),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          veri.is58k
                              ? '2547 Sayılı Kanun Madde 58/k Uyarınca Sözleşmeli Danışmanlık Şerhi'
                              : (veri.is58e
                                  ? '2547 Sayılı Kanun Madde 58/e Uyarınca Danışmanlık ve Hizmet Şerhi'
                                  : '2547 ve 2914 Sayılı Kanunlar Uyarınca Ek Ders Yasal Tavan Şerhi'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: (veri.is58k || veri.is58e)
                                ? const Color(0xFF1E40AF)
                                : (!veri.tavanUygula
                                    ? const Color(0xFF334155)
                                    : (excel.herhangiBirTavanAsildi ? const Color(0xFF92400E) : const Color(0xFF166534))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      veri.is58k
                          ? 'İşbu ödeme, 2547 sayılı Kanun Madde 58/k uyarınca yapılan sanayi/bireysel danışmanlık sözleşmesine istinaden tahakkuk ettirilmiştir. Matrah üzerinden %15 kurum/araç-gereç payı kesildikten sonra kalan %85 tutar doğrudan danışmana ${veri.odemeTekSeferde ? "tek seferde" : "sözleşme taksitlerine bölünerek"} ödenmektedir. Puan hesabı ve saatlik ek ders tavanı aranmaz.'
                          : (veri.is58e
                              ? 'İşbu ödeme, 2547 sayılı Kanun Madde 58/e uyarınca üniversite imkânları kullanılmaksızın yürütülen hizmete istinaden tahakkuk ettirilmiştir. KDV hariç matrahtan yasal Hazine (%${veri.hazineOrani}), BAP (%${veri.bapOrani}) ve Birim/Kurum payı (%${(veri.aracGerecOrani * 100).toStringAsFixed(0)}) kesildikten sonra kalan tutar, 2547 sayılı Kanun Madde 58/e fıkrası hükmü uyarınca ek ders saat tavanı uygulanmaksızın, Gelir Vergisi (Stopaj: %${veri.gelirVergisiOrani}) ve Damga Vergisi (%0,759) kesilerek doğrudan personele tahakkuk ettirilmiştir.'
                              : (!veri.tavanUygula
                                  ? 'İşbu hesaplama cetvelinde kullanıcı tercihi doğrultusunda yasal saatlik ek ders tavanı sınırlaması uygulanmamış olup personellere hak edilen brüt katkı payı tutarı tam olarak tahakkuk ettirilmiştir.'
                                  : (excel.herhangiBirTavanAsildi
                                      ? (excel.katiKesintiUygula
                                          ? 'İşbu hesaplamada yer alan ve hesaplanan saatlik ücreti yasal tavanı (Mesai İçi 2.0x, Mesai Dışı 3.2x: ${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) aşan personele yasal tavan uygulanmış; tavanı aşan toplam ${TurkceFormat.para(excel.toplamTavanKesintisi)} tutar döner sermaye birim havuzuna devredilmiştir.'
                                          : 'İşbu hesaplamada 2547 sayılı Kanun Madde 58 uyarınca personelin hak ettiği brüt katkı payı tutarı personelin özlük hakkı olarak tam tahakkuk ettirilmiştir. 2914 sayılı Kanun m.11 ek ders tavan göstergesi (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) mevzuat ve Sayıştay denetim incelemesi amacıyla bilgi notu olarak icmale eklenmiştir.')
                                      : 'İşbu hesaplama icmalinde yer alan tüm öğretim elemanlarının saatlik ücretleri, 2914 sayılı Kanun uyarınca belirlenen ek ders ücreti tavanını (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) GEÇMEMİŞTİR. Dağıtım ve ödemeler mevzuata tam uygundur.'))),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: (veri.is58k || veri.is58e)
                            ? const Color(0xFF1E3A8A)
                            : (!veri.tavanUygula
                                ? const Color(0xFF475569)
                                : (excel.herhangiBirTavanAsildi ? const Color(0xFF78350F) : const Color(0xFF14532D))),
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

  void _hizmetBasligiDegistirDialog(BuildContext context) {
    final controller = TextEditingController(text: veri.hizmetBasligi);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personel ve Hizmet Başlığını Düzenle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Personel ve Hizmet Başlığı',
              hintText: 'Örn: DANIŞMANLIK HİZMET GELİRİ HESAPLAMA TABLOSU',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41), foregroundColor: Colors.white),
            onPressed: () {
              onHizmetBasligiDegisti?.call(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Güncelle'),
          ),
        ],
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

  static double _round(double val, [int decimals = 2]) {
    return double.parse(val.toStringAsFixed(decimals));
  }

  static String _tamAdSoyad(String unvan, String adSoyad) {
    final u = unvan.trim();
    final a = adSoyad.trim();
    if (u.isEmpty) return a;
    if (a.toLowerCase().startsWith(u.toLowerCase())) return a;
    return '$u $a';
  }
}
