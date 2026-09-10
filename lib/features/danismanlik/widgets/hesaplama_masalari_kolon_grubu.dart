import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HesaplamaMasalariKolonGrubu extends StatelessWidget {
  const HesaplamaMasalariKolonGrubu({
    super.key,
    this.onSablonSecildi,
  });

  final ValueChanged<String>? onSablonSecildi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Üst Başlık
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF107C41).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_chart_outlined, color: Color(0xFF107C41), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gelir Dağıtım ve Hesaplama Masaları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Birimlere ve yasal mevzuata göre özelleştirilmiş resmi Excel dağıtım cetvelleri',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4 Kolonlu Responsive Kart Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1050;
            final isMedium = constraints.maxWidth > 650;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDtsCard(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _build58kCard(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildUsemCard(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTomerCard(context)),
                ],
              );
            } else if (isMedium) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDtsCard(context)),
                      const SizedBox(width: 12),
                      Expanded(child: _build58kCard(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUsemCard(context)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTomerCard(context)),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildDtsCard(context),
                  const SizedBox(height: 10),
                  _build58kCard(context),
                  const SizedBox(height: 10),
                  _buildUsemCard(context),
                  const SizedBox(height: 10),
                  _buildTomerCard(context),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // 1. DTS Kartı
  Widget _buildDtsCard(BuildContext context) {
    return _kolonKarti(
      context: context,
      sablonTuru: 'dts',
      baslik: 'DTS Danışmanlık',
      altBaslik: 'Tasarım & Ar-Ge Merkezi',
      ikon: Icons.palette_outlined,
      renk: const Color(0xFF0F766E), // Teal
      oranlar: [
        'KDV: %20',
        '%45 Araç-Gereç',
        '%1 Hazine · %5 BAP',
        '%49 Katkı Payı',
        'Dinamik Puan Bölüşümü',
      ],
      etiket: 'MERKEZ',
      butonMetni: 'DTS Cetveli',
    );
  }

  // 2. 2547 Madde 58/k Kartı (DONGSAN & Sanayi / DÖSİM Danışmanlığı)
  Widget _build58kCard(BuildContext context) {
    return _kolonKarti(
      context: context,
      sablonTuru: '58k',
      baslik: '2547 Madde 58/k',
      altBaslik: 'Sanayi & Sözleşmeli Danışmanlık',
      ikon: Icons.gavel_outlined,
      renk: const Color(0xFF2563EB), // Blue
      oranlar: [
        'KDV: %20',
        '%15 Kurum Payı (A.G.P.)',
        '%85 NET KATKI PAYI',
        'Hazine & BAP Kesintisi %0',
        'Sözleşme & Taksit Dönemi',
      ],
      etiket: 'GENEL KANUN',
      butonMetni: '58/k Cetveli',
    );
  }

  // 3. USEM Kursları Kartı
  Widget _buildUsemCard(BuildContext context) {
    return _kolonKarti(
      context: context,
      sablonTuru: 'usem',
      baslik: 'USEM Kurs & Eğitim',
      altBaslik: 'Sürekli Eğitim Merkezi',
      ikon: Icons.school_outlined,
      renk: const Color(0xFF7C3AED), // Violet
      oranlar: [
        'KDV: %10 (Eğitim)',
        'Kursiyer Listesi',
        'Ders Saati Katsayısı',
        'Eğitmen Pay Dağıtımı',
        '3,2 Tavan Kontrolü',
      ],
      etiket: 'KURS / EĞİTİM',
      butonMetni: 'USEM Cetveli',
    );
  }

  // 4. TÖMER Kartı
  Widget _buildTomerCard(BuildContext context) {
    return _kolonKarti(
      context: context,
      sablonTuru: 'tomer',
      baslik: 'TÖMER Dil Eğitimi',
      altBaslik: 'Türkçe Öğretim Merkezi',
      ikon: Icons.language_outlined,
      renk: const Color(0xFFD97706), // Amber
      oranlar: [
        'KDV: %10 (Eğitim)',
        'Kursiyer Katılım Listesi',
        'Doçent / Öğr. Gör. Saati',
        'Öğretim Elemanı Payı',
        'Resmi İcmal Çıktısı',
      ],
      etiket: 'DİL EĞİTİMİ',
      butonMetni: 'TÖMER Cetveli',
    );
  }

  Widget _kolonKarti({
    required BuildContext context,
    required String sablonTuru,
    required String baslik,
    required String altBaslik,
    required IconData ikon,
    required Color renk,
    required List<String> oranlar,
    required String etiket,
    required String butonMetni,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Bant
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: renk.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: renk.withValues(alpha: 0.3)),
                  ),
                  child: Icon(ikon, size: 16, color: renk),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: renk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        altBaslik,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: renk.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    etiket,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: renk,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // İçerik: Maddeler / Oranlar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final oran in oranlar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 11, color: renk),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            oran,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Buton Alanı
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (onSablonSecildi != null) {
                        onSablonSecildi!(sablonTuru);
                      } else {
                        context.push('/danismanlik/manuel-hesapla?sablon=$sablonTuru');
                      }
                    },
                    icon: const Icon(Icons.launch, size: 14),
                    label: Text(
                      butonMetni,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: renk,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
