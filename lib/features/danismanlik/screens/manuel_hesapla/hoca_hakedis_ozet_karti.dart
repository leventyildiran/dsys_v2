import 'package:flutter/material.dart';
import 'package:dsys_v2/core/turkce_format.dart';
import 'package:dsys_v2/features/danismanlik/services/danismanlik_excel_hesaplama.dart';

/// Her hocanin kurusu kurusuna ne kadar para alacagini
/// gosteren modern hakedis ve dagilim karti.
class HocaHakedisOzetKarti extends StatelessWidget {
  const HocaHakedisOzetKarti({
    super.key,
    required this.excelSonuc,
  });

  final DanismanlikExcelSonuc excelSonuc;

  @override
  Widget build(BuildContext context) {
    final satirlar = excelSonuc.personelSatirlari;
    if (satirlar.isEmpty) return const SizedBox.shrink();

    final toplamPuan = excelSonuc.toplamPuan > 0 ? excelSonuc.toplamPuan : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ust Baslik
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.payments_outlined, color: Color(0xFF047857), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ogretim Elemanlari Hakedis ve Para Dagitim Icmali',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF065F46)),
                      ),
                      Text(
                        'Her hocanin alacagi net tutar = Bireysel Net Katki Puani x Donem Katsayisi formuluyle hesaplanir.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Donem Katsayisi: ',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFD1FAE5)),

          // Hocalarin Kartlari / Izgara Listesi
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: satirlar.map((s) {
                final p = s.girdi;
                final yuzde = (s.bireyselNetKatkiPuani / toplamPuan) * 100;
                final tavanAsildi = s.kursSaatlikUcreti > s.tavanSaatlikUcreti && s.tavanSaatlikUcreti > 0;

                return Container(
                  width: 330,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tavanAsildi ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF107C41).withValues(alpha: 0.12),
                        child: Text(
                          p.adSoyad.isNotEmpty ? p.adSoyad[0].toUpperCase() : 'H',
                          style: const TextStyle(color: Color(0xFF107C41), fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Hoca Bilgisi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.unvan} ${p.adSoyad.isNotEmpty ? p.adSoyad : "İsimsiz"}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${s.bireyselNetKatkiPuani.toStringAsFixed(0)} Puan',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '%${yuzde.toStringAsFixed(1)} pay',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                if (tavanAsildi) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(3.2 Katı Tavanı: ${TurkceFormat.para(s.tavanSaatlikUcreti)}/saat)',
                                    style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Alacagi Net Tutar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ALACAGI PARA',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF047857), letterSpacing: 0.3),
                          ),
                          const SizedBox(height: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              TurkceFormat.para(s.odenebilirHakedis),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Alt Toplam Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Toplam ${satirlar.length} Öğretim Elemanına Dağıtım',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Dagitilan Toplam: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      TurkceFormat.para(excelSonuc.netOdemeToplam),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF107C41)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Artik / Birim Fonu: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      TurkceFormat.para(excelSonuc.artikBakiye),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
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
}
