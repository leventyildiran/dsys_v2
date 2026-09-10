import 'package:flutter/material.dart';
import '../../../../core/turkce_format.dart';
import '../../services/danismanlik_manuel_pdf_servisi.dart';

class TabListe extends StatelessWidget {
  const TabListe({
    super.key,
    required this.satirlar,
    required this.toplamTutar,
    required this.kdvHaricGelir,
    required this.kdvTutari,
    required this.kdvOrani,
    required this.onSatirEkle,
    required this.onSatirSil,
    required this.onSatirGuncelle,
    required this.onKdvOraniDegisti,
  });

  final List<ManuelListeSatiri> satirlar;
  final double toplamTutar;
  final double kdvHaricGelir;
  final double kdvTutari;
  final int kdvOrani;
  final VoidCallback onSatirEkle;
  final ValueChanged<int> onSatirSil;
  final void Function(int index, String tc, String aciklama, double tutar) onSatirGuncelle;
  final ValueChanged<int> onKdvOraniDegisti;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bilgilendirme ve Hızlı Butonlar
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
                      color: const Color(0xFF107C41).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_view_outlined, color: Color(0xFF107C41), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fatura & Gelir Listesi (Excel LİSTE Sayfası)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          'Fatura veya kursiyer ödemelerini ekleyin. Toplam otomatik hesaplanıp pay dağıtımına aktarılır.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<int>(
                    value: kdvOrani,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 20, child: Text('KDV %20')),
                      DropdownMenuItem(value: 10, child: Text('KDV %10')),
                      DropdownMenuItem(value: 0, child: Text('KDV %0 (Muaf)')),
                    ],
                    onChanged: (v) => v != null ? onKdvOraniDegisti(v) : null,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onSatirEkle,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Satır Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Excel Tarzı Grid Tablosu
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Tablo Başlığı
                Container(
                  color: const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: const [
                      SizedBox(width: 44, child: Text('S.N', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      SizedBox(width: 150, child: Text('T.C. KİMLİK NO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      Expanded(child: Text('AÇIKLAMA / FATURA / KURSİYER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      SizedBox(width: 150, child: Text('TUTAR (TL)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      SizedBox(width: 44),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Satırlar
                if (satirlar.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Henüz satır eklenmedi. Yukarıdaki "Satır Ekle" butonuna basarak ekleyebilirsiniz.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: satirlar.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final item = satirlar[index];
                      return Container(
                        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${item.sn}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                initialValue: item.tc,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'T.C. No',
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (val) => onSatirGuncelle(index, val, item.aciklama, item.tutar),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: item.aciklama,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Açıklama...',
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (val) => onSatirGuncelle(index, item.tc, val, item.tutar),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                initialValue: item.tutar > 0 ? item.tutar.toStringAsFixed(2) : '',
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: '0,00',
                                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.replaceAll(',', '.').trim()) ?? 0.0;
                                  onSatirGuncelle(index, item.tc, item.aciklama, numVal);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => onSatirSil(index),
                                tooltip: 'Satırı Sil',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const Divider(height: 1, thickness: 1.5),

                // Tablo Alt Toplam Satırı (T O P L A M)
                Container(
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      const Expanded(
                        child: Text(
                          'T   O   P   L   A   M',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 2),
                        ),
                      ),
                      Container(
                        width: 150,
                        alignment: Alignment.centerRight,
                        child: Text(
                          TurkceFormat.para(toplamTutar),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Alt Özet Kartı (GELİR, %20 KDV, TOPLAM)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            color: const Color(0xFFF8FAFC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _ozetKutusu(
                      baslik: 'GELİR (KDV Hariç)',
                      tutar: TurkceFormat.para(kdvHaricGelir),
                      renk: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ozetKutusu(
                      baslik: '%$kdvOrani KDV',
                      tutar: TurkceFormat.para(kdvTutari),
                      renk: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ozetKutusu(
                      baslik: 'TOPLAM',
                      tutar: TurkceFormat.para(toplamTutar),
                      renk: const Color(0xFF107C41),
                      vurgulu: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ozetKutusu({
    required String baslik,
    required String tutar,
    required Color renk,
    bool vurgulu = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vurgulu ? renk : Colors.grey.shade200, width: vurgulu ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            tutar,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: renk),
          ),
        ],
      ),
    );
  }
}
