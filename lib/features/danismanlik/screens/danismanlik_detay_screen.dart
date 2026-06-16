import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../providers/danismanlik_detay_provider.dart';
import '../services/danismanlik_service.dart';
import '../widgets/danismanlik_layout.dart';
import '../widgets/taksit_pipeline.dart';
import '../services/taksit_onay_akisi.dart';

class DanismanlikDetayScreen extends StatelessWidget {
  const DanismanlikDetayScreen({super.key, required this.danismanlik});

  final DanismanlikModel danismanlik;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DanismanlikDetayProvider(danismanlik),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DanismanlikLayout.kompaktBaslik(
              baslik: danismanlik.firmaUnvan ?? 'Danışmanlık Detay',
              altBaslik: danismanlik.konusu,
              aksiyon: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Geri',
              ),
            ),
            const Expanded(child: _DanismanlikDetayBody()),
          ],
        ),
      ),
    );
  }
}

/// Firestore'dan id ile danışmanlık yükler.
class DanismanlikDetayLoader extends StatelessWidget {
  const DanismanlikDetayLoader({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DanismanlikModel?>(
      future: DanismanlikService().getById(id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Danışmanlık kaydı bulunamadı.'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/danismanlik'),
                    child: const Text('Listeye dön'),
                  ),
                ],
              ),
            ),
          );
        }
        return DanismanlikDetayScreen(danismanlik: snap.data!);
      },
    );
  }
}

class _DanismanlikDetayBody extends StatelessWidget {
  const _DanismanlikDetayBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DanismanlikDetayProvider>();
    final d = provider.danismanlik;

    return LayoutBuilder(
      builder: (context, constraints) {
        return DanismanlikLayout.ikiKolon(
          genislik: constraints.maxWidth,
          ana: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKararKarti(context, d),
                const SizedBox(height: DanismanlikLayout.sectionGap),
                _buildTaksitler(context, provider),
              ],
            ),
          ),
          yan: _buildOzetPanel(d, provider),
        );
      },
    );
  }

  Widget _buildKararKarti(BuildContext context, DanismanlikModel d) {
    return Container(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: DanismanlikLayout.kart(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DanismanlikLayout.kartBaslik('Kurul Onayları', icon: Icons.gavel),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildKararSutunu(
                    baslik: 'Birim YK (BYK)',
                    tarih: d.birimKararTarihi,
                    no: d.birimKararNo,
                    toplanti: d.birimToplantiSayisi,
                    renk: Colors.orange,
                    icon: Icons.account_balance,
                  ),
                ),
                VerticalDivider(color: Colors.blueGrey.shade100),
                Expanded(
                  child: _buildKararSutunu(
                    baslik: 'Sözleşme (YKK)',
                    tarih: d.ykKararTarihi,
                    no: d.ykKararNo,
                    toplanti: d.ykToplantiSayisi,
                    renk: Colors.indigo,
                    icon: Icons.description,
                  ),
                ),
                VerticalDivider(color: Colors.blueGrey.shade100),
                Expanded(
                  child: _buildKararSutunu(
                    baslik: 'Dağıtım (YKK)',
                    tarih: d.dagitimYkKararTarihi,
                    no: d.dagitimYkKararNo,
                    toplanti: d.dagitimYkToplantiSayisi,
                    renk: Colors.green,
                    icon: Icons.price_check,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOzetPanel(DanismanlikModel d, DanismanlikDetayProvider provider) {
    return Container(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: DanismanlikLayout.kart(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DanismanlikLayout.kartBaslik('Sözleşme Özeti', icon: Icons.summarize),
          const SizedBox(height: 12),
          Text(d.konusu, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tür: ${d.danismanlikTuru.displayName}', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
          const Divider(height: 20),
          Text(TurkceFormat.para(d.toplamTutar), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.indigo.shade700)),
          Text('KDV %${d.kdvOrani} · ${d.suresi} ay', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
          const Spacer(),
          if (provider.taksitler.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                // handled in taksit card
              },
              icon: const Icon(Icons.table_view, size: 16),
              label: Text('${provider.taksitler.length} taksit'),
            ),
        ],
      ),
    );
  }

  Widget _buildTaksitler(BuildContext context, DanismanlikDetayProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DanismanlikLayout.kartBaslik('Taksitler & Dağıtım', icon: Icons.payments),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _yeniTaksitDialog(context, provider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Taksit Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (provider.taksitler.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: DanismanlikLayout.kart(),
            child: const Center(child: Text('Henüz taksit eklenmedi.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...provider.taksitler.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: DanismanlikLayout.sectionGap),
                child: _buildTaksitCard(context, t, provider),
              )),
      ],
    );
  }

  Widget _buildTaksitCard(BuildContext context, TaksitModel taksit, DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final islemAyi = DanismanlikDetayProvider.guncelIslemAyi();

    return Container(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: DanismanlikLayout.kart(),
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
          TaksitPipeline(durum: taksit.durum, compact: true),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (TaksitOnayAkisi.oncekiDurum(taksit.durum) != null)
                TextButton.icon(
                  onPressed: provider.isLoading ? null : () => provider.durumGeriAl(taksit),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('Geri Al'),
                ),
              TextButton.icon(
                onPressed: () {
                  context.push(
                    '/danismanlik/dagitim',
                    extra: DanismanlikRouteExtra(model: d, taksit: taksit),
                  );
                },
                icon: const Icon(Icons.table_view, size: 16),
                label: const Text('Dağıtım Paneli'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.dagitimiHesaplaVeKaydet(taksit, islemAyi, false),
                icon: const Icon(Icons.calculate_outlined, size: 16),
                label: const Text('Hesapla'),
              ),
              const SizedBox(width: 8),
              if (TaksitOnayAkisi.sonrakiDurum(taksit.durum) != null)
                ElevatedButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          await provider.durumIlerlet(taksit);
                          if (context.mounted && provider.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    TaksitOnayAkisi.sonrakiDurum(taksit.durum) == TaksitDurum.onaylandi
                        ? Icons.check
                        : Icons.arrow_forward,
                    size: 16,
                  ),
                  label: Text(TaksitOnayAkisi.ilerletEtiketi(taksit.durum)),
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
