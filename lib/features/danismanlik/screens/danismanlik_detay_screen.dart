import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../providers/danismanlik_detay_provider.dart';

class DanismanlikDetayScreen extends StatelessWidget {
  const DanismanlikDetayScreen({super.key, required this.danismanlik});

  final DanismanlikModel danismanlik;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DanismanlikDetayProvider(danismanlik),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('${danismanlik.firmaUnvan ?? 'Firma'} - Detay'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueGrey.shade800,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: Colors.blueGrey.shade200, height: 1),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const _DanismanlikDetayBody(),
      ),
    );
  }
}

class _DanismanlikDetayBody extends StatelessWidget {
  const _DanismanlikDetayBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DanismanlikDetayProvider>();
    final d = provider.danismanlik;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Özet Kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sözleşme Bilgileri', style: TextStyle(color: Colors.blueGrey.shade500, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(d.konusu, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Tür: ${d.danismanlikTuru.displayName}', style: TextStyle(color: Colors.blueGrey.shade700)),
                    ],
                  ),
                ),
                Container(width: 1, height: 80, color: Colors.blueGrey.shade200),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mali Özet', style: TextStyle(color: Colors.blueGrey.shade500, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(TurkceFormat.para(d.toplamTutar), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo.shade600)),
                        const SizedBox(height: 4),
                        Text('KDV: %${d.kdvOrani} | Süre: ${d.suresi} Ay', style: TextStyle(color: Colors.blueGrey.shade700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Karar ve Kurul Bilgileri Kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kurul ve Karar Bilgileri', style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildKararSutunu(
                        baslik: 'Birim Yönetim Kurulu (BYK)',
                        tarih: d.birimKararTarihi,
                        no: d.birimKararNo,
                        toplanti: d.birimToplantiSayisi,
                        renk: Colors.orange,
                        icon: Icons.account_balance,
                      ),
                    ),
                    Container(width: 1, height: 80, color: Colors.blueGrey.shade100),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: _buildKararSutunu(
                          baslik: 'Sözleşme Onayı (YKK)',
                          tarih: d.ykKararTarihi,
                          no: d.ykKararNo,
                          toplanti: d.ykToplantiSayisi,
                          renk: Colors.indigo,
                          icon: Icons.gavel,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 80, color: Colors.blueGrey.shade100),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: _buildKararSutunu(
                          baslik: 'Dağıtım Onayı (YKK)',
                          tarih: d.dagitimYkKararTarihi,
                          no: d.dagitimYkKararNo,
                          toplanti: d.dagitimYkToplantiSayisi,
                          renk: Colors.green,
                          icon: Icons.price_check,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // EBYS Görünümlü Dağıtım Tablosu Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/danismanlik/dagitim', extra: d);
              },
              icon: const Icon(Icons.table_view, size: 24),
              label: const Text('EBYS Görünümlü Detaylı Dağıtım Paneli (Excel)', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Taksitler ve Dağıtım Bölümü
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taksitler & Dağıtım Panosu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _yeniTaksitDialog(context, provider);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Taksit Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (provider.taksitler.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Henüz taksit eklenmedi.', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.taksitler.length,
              separatorBuilder: (c, i) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final taksit = provider.taksitler[index];
                return _buildTaksitCard(context, taksit, provider);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaksitCard(BuildContext context, TaksitModel taksit, DanismanlikDetayProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo.shade100,
                child: Text('${taksit.ayNo}', style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text('Ay Taksiti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: taksit.durum == TaksitDurum.onaylandi ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  taksit.durum.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: taksit.durum == TaksitDurum.onaylandi ? Colors.green.shade700 : Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => provider.taksitSil(taksit.id),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Brüt Tutar', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                    const SizedBox(height: 4),
                    Text(TurkceFormat.para(taksit.brutTutar), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dağıtılabilir Tutar', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                    const SizedBox(height: 4),
                    Text(taksit.dagitilabilirTutar != null ? TurkceFormat.para(taksit.dagitilabilirTutar!) : '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hesaplanan Katsayı', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                    const SizedBox(height: 4),
                    Text(taksit.ekOdemeKatsayisi?.toStringAsFixed(4) ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  provider.dagitimiHesaplaVeKaydet(taksit, '2026-06', false); // Dummy islemAyi
                },
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Sadece Hesapla (Taslak)'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: taksit.durum == TaksitDurum.onaylandi ? null : () {
                  // YK Arşivine Gönder
                  provider.dagitimiHesaplaVeKaydet(taksit, '2026-06', true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Taksit hesaplandı ve YK Karar Merkezine arşive gönderildi!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Hesapla & Kararı YK Arşivine Gönder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _yeniTaksitDialog(BuildContext context, DanismanlikDetayProvider provider) {
    final ayCtrl = TextEditingController(text: '${provider.taksitler.length + 1}');
    final tutarCtrl = TextEditingController(text: '${provider.danismanlik.toplamTutar}');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Taksit Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ayCtrl,
              decoration: const InputDecoration(labelText: 'Taksit Sırası (Ay No)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tutarCtrl,
              decoration: const InputDecoration(labelText: 'Taksit Brüt Tutar (TL)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              provider.yeniTaksitEkle(
                int.tryParse(ayCtrl.text) ?? 1,
                double.tryParse(tutarCtrl.text) ?? 0.0,
              );
              Navigator.pop(c);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildKararSutunu({
    required String baslik,
    String? tarih,
    String? no,
    String? toplanti,
    required Color renk,
    required IconData icon,
  }) {
    final bool isEmpty = (tarih == null || tarih.isEmpty) && (no == null || no.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: renk),
            const SizedBox(width: 6),
            Text(baslik, style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        if (isEmpty)
          Text('Henüz karar bilgisi girilmedi.', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 13))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tarih: ${tarih ?? "-"}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Karar No: ${no ?? "-"}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (toplanti != null && toplanti.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Toplantı: $toplanti', style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13)),
              ],
            ],
          ),
      ],
    );
  }
}
