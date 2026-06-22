import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/turkce_format.dart';
import 'danismanlik_form_screen.dart';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSozlesmeAsamasi(context, d),
              const SizedBox(height: 48),
              _buildUygulamaAsamasi(context, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSozlesmeAsamasi(BuildContext context, DanismanlikModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.handshake_rounded, color: Colors.indigo.shade600),
            ),
            const SizedBox(width: 12),
            const Text('1. Aşama: Danışmanlık Sözleşmesi ve Genel Onaylar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SÖZLEŞME ÖZETİ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1.2)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.indigo),
                              tooltip: 'Sözleşmeyi Düzenle',
                              onPressed: () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => DanismanlikFormScreen(mevcutDanismanlik: d),
                                ));
                                if (context.mounted) {
                                  context.replace('/danismanlik/detay/${d.id}');
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              tooltip: 'Sözleşmeyi Sil',
                              onPressed: () => _showDeleteDialog(context, d),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(d.konusu, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(Icons.category, d.danismanlikTuru.displayName),
                        _buildInfoChip(Icons.timer, '${d.suresi} ay'),
                        _buildInfoChip(Icons.percent, 'KDV %${d.kdvOrani}'),
                      ],
                    ),
                    const Divider(height: 32),
                    Text('Sözleşme Bedeli', style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
                    const SizedBox(height: 4),
                    Text(TurkceFormat.para(d.toplamTutar), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.indigo.shade700)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(width: 1, height: 160, color: Colors.blueGrey.shade100),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SÖZLEŞME KURUL ONAYLARI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Row(
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
                        Expanded(
                          child: _buildKararSutunu(
                            baslik: 'Merkez Sözleşme (YKK)',
                            tarih: d.ykKararTarihi,
                            no: d.ykKararNo,
                            toplanti: d.ykToplantiSayisi,
                            renk: Colors.indigo,
                            icon: Icons.gavel,
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
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUygulamaAsamasi(BuildContext context, DanismanlikDetayProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.account_tree_rounded, color: Colors.green.shade600),
            ),
            const SizedBox(width: 12),
            const Text('2. Aşama: Hizmet Uygulama ve Dağıtım Havuzları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _yeniTaksitDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Havuz Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBakiyeCari(provider),
        const SizedBox(height: 16),
        if (provider.taksitler.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey.shade100, style: BorderStyle.solid),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.blueGrey.shade200),
                  const SizedBox(height: 16),
                  Text('Henüz bir ödeme havuzu başlatılmadı.', style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Hizmet verildikten ve fatura kesildikten sonra dağıtım havuzu ekleyebilirsiniz.', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...provider.taksitler.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildTaksitCard(context, t, provider),
              )),
      ],
    );
  }

  Widget _buildTaksitCard(BuildContext context, TaksitModel taksit, DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final islemAyi = DanismanlikDetayProvider.guncelIslemAyi();
    final akis = IsAkisiMotoru.forTur(d!.tur);

    final bool isDagitimAsamasi = akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.dagitimHesaplandi);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.indigo.shade600,
                  child: Text('${taksit.ayNo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                Text('${taksit.ayNo}. Dağıtım Havuzu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade900)),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Text(
                    taksit.durum.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: taksit.durum == TaksitDurum.ykOnaylandi || taksit.durum == TaksitDurum.odendi ? Colors.green.shade700 : Colors.amber.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text('Brüt Tutar: ', style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 14)),
                Text(TurkceFormat.para(taksit.brutTutar), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.indigo.shade700)),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => provider.taksitSil(taksit.id),
                  tooltip: 'Havuzu Sil',
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: TaksitPipeline(durum: taksit.durum, tur: d.tur, compact: false),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _buildDurumCheckbox(
                  label: 'Fatura Kesildi / Dekont Alındı',
                  value: akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.faturaKesildi),
                  isEnabled: taksit.durum == TaksitDurum.taslak || taksit.durum == TaksitDurum.faturaKesildi,
                  onChanged: (val) {
                    if (val == true) provider.durumIlerlet(taksit);
                    else provider.durumGeriAl(taksit);
                  },
                ),
                const SizedBox(width: 32),
                _buildDurumCheckbox(
                  label: 'Para Döner Sermaye Hesabına Geldi',
                  value: akis.adimIndeksi(taksit.durum) >= akis.adimIndeksi(TaksitDurum.paraGeldi),
                  isEnabled: taksit.durum == TaksitDurum.faturaKesildi || taksit.durum == TaksitDurum.paraGeldi,
                  onChanged: (val) {
                    if (val == true) provider.durumIlerlet(taksit);
                    else provider.durumGeriAl(taksit);
                  },
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          if (isDagitimAsamasi)
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.orange.shade50.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_document, size: 20, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text('Bu Dağıtıma Özel Kurul Kararları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _TaksitKararForm(taksit: taksit, provider: provider),
                ],
              ),
            ),
          
          if (isDagitimAsamasi)
            const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (akis.oncekiDurum(taksit.durum) != null)
                  TextButton.icon(
                    onPressed: provider.isLoading ? null : () => provider.durumGeriAl(taksit),
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('İşlemi Geri Al'),
                  ),
                const Spacer(),
                if (taksit.durum == TaksitDurum.dagitimHesaplandi || taksit.durum == TaksitDurum.ykOnaylandi || taksit.durum == TaksitDurum.odendi)
                  OutlinedButton.icon(
                    onPressed: () {
                      context.push('/danismanlik/dagitim', extra: DanismanlikRouteExtra(model: d, taksit: taksit));
                    },
                    icon: const Icon(Icons.table_view, size: 16),
                    label: const Text('Dağıtım Tablosuna Git'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                  ),
                const SizedBox(width: 12),
                if (taksit.durum == TaksitDurum.dagitimHesaplandi)
                  ElevatedButton.icon(
                    onPressed: provider.isLoading ? null : () => provider.dagitimiHesaplaVeKaydet(taksit, islemAyi, false),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Baştan Hesapla (Sıfırla)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                    ),
                  ),
                const SizedBox(width: 12),
                if (akis.sonrakiDurum(taksit.durum) != null)
                  ElevatedButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            await provider.durumIlerlet(taksit);
                            if (context.mounted && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!), backgroundColor: Colors.red));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                    ),
                    icon: Icon(akis.sonrakiDurum(taksit.durum) == TaksitDurum.odendi ? Icons.check_circle : Icons.arrow_forward, size: 18),
                    label: Text(akis.ilerletEtiketi(taksit.durum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurumCheckbox({
    required String label,
    required bool value,
    required bool isEnabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: isEnabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: isEnabled ? onChanged : null,
                activeColor: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled ? Colors.blueGrey.shade800 : Colors.blueGrey.shade300,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniTaksitDialog(BuildContext context, DanismanlikDetayProvider provider) {
    final ayCtrl = TextEditingController(text: '${provider.taksitler.length + 1}');
    final tutarCtrl = TextEditingController(text: '${provider.danismanlik.toplamTutar}');

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Ödeme Havuzu Başlat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ayCtrl,
              decoration: const InputDecoration(labelText: 'Kaçıncı Ay / Dönem?'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tutarCtrl,
              decoration: const InputDecoration(labelText: 'Gelen Para (KDV Dahil/Hariç Brüt Tutar)'),
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
            Icon(icon, size: 18, color: renk),
            const SizedBox(width: 8),
            Text(baslik, style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 16),
        if (isEmpty)
          Text('Henüz karar bilgisi girilmedi.', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 13))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tarih: ${tarih ?? "-"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              Text('Karar No: ${no ?? "-"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (toplanti != null && toplanti.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Toplantı: $toplanti', style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13)),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildBakiyeCari(DanismanlikDetayProvider provider) {
    final d = provider.danismanlik;
    final toplamTutar = d!.toplamTutar;
    final kullanilanTutar = provider.taksitler.fold<double>(0, (sum, t) => sum + t.brutTutar);
    final kalanTutar = toplamTutar - kullanilanTutar;
    final oran = kullanilanTutar / toplamTutar;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dağıtılan: ${TurkceFormat.para(kullanilanTutar)}', style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600)),
              Text('Kalan Bakiye: ${TurkceFormat.para(kalanTutar)}', style: TextStyle(color: kalanTutar < 0 ? Colors.red : Colors.green.shade700, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: oran.clamp(0.0, 1.0),
            backgroundColor: Colors.blueGrey.shade50,
            color: kalanTutar < 0 ? Colors.red : Colors.green.shade500,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, DanismanlikModel d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sözleşmeyi Sil'),
        content: const Text('Bu sözleşmeyi kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await DanismanlikService().delete(d.id);
      if (context.mounted) context.go('/danismanlik');
    }
  }
}

class _TaksitKararForm extends StatefulWidget {
  final TaksitModel taksit;
  final DanismanlikDetayProvider provider;

  const _TaksitKararForm({required this.taksit, required this.provider});

  @override
  State<_TaksitKararForm> createState() => _TaksitKararFormState();
}

class _TaksitKararFormState extends State<_TaksitKararForm> {
  late TextEditingController bykTarih;
  late TextEditingController bykToplanti;
  late TextEditingController bykKarar;
  late TextEditingController ykkTarih;
  late TextEditingController ykkToplanti;
  late TextEditingController ykkKarar;

  @override
  void initState() {
    super.initState();
    final t = widget.taksit;
    bykTarih = TextEditingController(text: t.birimKurulTarihi ?? '');
    bykToplanti = TextEditingController(text: t.birimToplantiSayisi ?? '');
    bykKarar = TextEditingController(text: t.birimKararNo ?? '');
    ykkTarih = TextEditingController(text: t.ykKararTarihi ?? '');
    ykkToplanti = TextEditingController(text: t.ykToplantiSayisi ?? '');
    ykkKarar = TextEditingController(text: t.ykKararNo ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField('Dağıtım BYK Tarihi', bykTarih)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('BYK Toplantı No', bykToplanti)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('BYK Karar No', bykKarar)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField('Dağıtım YKK Tarihi', ykkTarih)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('YKK Toplantı No', ykkToplanti)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('YKK Karar No', ykkKarar)),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              final guncel = widget.taksit.copyWith(
                birimKurulTarihi: bykTarih.text,
                birimToplantiSayisi: bykToplanti.text,
                birimKararNo: bykKarar.text,
                ykKararTarihi: ykkTarih.text,
                ykToplantiSayisi: ykkToplanti.text,
                ykKararNo: ykkKarar.text,
              );
              await widget.provider.taksitKararGuncelle(widget.taksit.id, guncel);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dağıtım Karar bilgileri kaydedildi.'), backgroundColor: Colors.green)
                );
              }
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Kararları Kaydet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
