import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/turkce_format.dart';
import '../../personel/models/personel_model.dart';
import '../models/danismanlik_model.dart';
import '../providers/danismanlik_provider.dart';
import '../../yk_karar/models/yk_karar_model.dart';
import '../../yk_karar/services/belge_uretim_servisi.dart';

class DanismanlikFormScreen extends StatefulWidget {
  final YkKararModel? ykKarar;
  const DanismanlikFormScreen({super.key, this.ykKarar});

  @override
  State<DanismanlikFormScreen> createState() => _DanismanlikFormScreenState();
}

class _DanismanlikFormScreenState extends State<DanismanlikFormScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DanismanlikProvider>();
      provider.temizle();
      
      if (widget.ykKarar != null) {
        // YK Kararından gelen verilerle formu doldur
        provider.setFirmaUnvan(widget.ykKarar!.baslik.replaceAll(' Danışmanlık', ''));
        if (widget.ykKarar!.tabloVerileri.isNotEmpty) {
          // Tablodan ilk hocayı alıp test amaçlı ekleyelim
          final row = widget.ykKarar!.tabloVerileri.first;
          final adSoyad = row['Personel'] ?? row['adiSoyadi'] ?? 'Prof. Dr. Ahmet Yılmaz';
          provider.personelEkle(
            PersonelModel(
              id: '1',
              adSoyad: adSoyad.toString(),
              unvan: 'Prof. Dr.',
              tcKimlikNo: '12345678901',
              iban: 'TR12 3456 7890',
              unvanKatsayisi: 1000,
              birimId: widget.ykKarar!.birimId,
            ),
          );
        }
      } else {
        // Test amaçlı bir personel ekleyelim
        provider.personelEkle(
          const PersonelModel(
            id: '1',
            adSoyad: 'Prof. Dr. Ahmet Yılmaz',
            unvan: 'Prof. Dr.',
            tcKimlikNo: '12345678901',
            iban: 'TR12 3456 7890',
            unvanKatsayisi: 1000,
            birimId: 'merkez',
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Yeni Danışmanlık Oluştur'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey.shade800,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.blueGrey.shade200, height: 1),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol Panel (Form)
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormSection(context),
                    const SizedBox(height: 32),
                    _buildPersonelSection(context),
                  ],
                ),
              ),
            ),
          ),
          // Sağ Panel (Canlı Önizleme)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.blueGrey.shade200)),
              ),
              child: _buildPreviewPanel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(BuildContext context) {
    final provider = context.watch<DanismanlikProvider>();

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
          Text(
            'Genel Bilgiler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DanismanlikTuru>(
                  value: provider.tur,
                  decoration: const InputDecoration(labelText: 'Danışmanlık Türü', border: OutlineInputBorder()),
                  items: DanismanlikTuru.values.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.displayName));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) provider.setTur(val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Firma Ünvanı', border: OutlineInputBorder()),
                  onChanged: provider.setFirmaUnvan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'İşin Konusu', border: OutlineInputBorder()),
            onChanged: provider.setIsinKonusu,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Brüt Tutar (TL)',
                    border: OutlineInputBorder(),
                    prefixText: '₺ ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setBrutTaksitTutari(double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Süresi (Ay)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  onChanged: (v) => provider.setSuresi(int.tryParse(v) ?? 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonelSection(BuildContext context) {
    final provider = context.watch<DanismanlikProvider>();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Görevli Personeller & Faaliyet Puanları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
              TextButton.icon(
                onPressed: () {
                  // TODO: Personel seçici dialog
                },
                icon: const Icon(Icons.add),
                label: const Text('Personel Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.personeller.isEmpty)
            const Text('Henüz personel eklenmedi.', style: TextStyle(color: Colors.grey))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.personeller.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = provider.personeller[index];
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('${p.personel.unvan} ${p.personel.adSoyad}'),
                    ),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Faaliyet Puanı (Ör. 100)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => context.read<DanismanlikProvider>().personelPuanGuncelle(index, double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    final provider = context.watch<DanismanlikProvider>();
    final onizleme = provider.onizleme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200)),
          ),
          child: Text(
            'Mali Analiz ve Karar Önizlemesi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
          ),
        ),
        if (onizleme == null)
          Expanded(
            child: Center(
              child: Text(
                'Hesaplama için Tutar ve Puan\nbilgilerini girin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(
                    title: 'Kesintiler',
                    content: Column(
                      children: [
                        _buildSummaryRow('KDV Hariç Matrah:', TurkceFormat.para(onizleme.kesinti.kdvHaricMatrah)),
                        _buildSummaryRow('Hazine Payı:', TurkceFormat.para(onizleme.kesinti.hazinePayi)),
                        _buildSummaryRow('BAP Payı:', TurkceFormat.para(onizleme.kesinti.bapPayi)),
                        _buildSummaryRow('Araç Gereç Payı:', TurkceFormat.para(onizleme.kesinti.aracGerecPayi)),
                        const Divider(),
                        _buildSummaryRow('Dağıtılabilir Tutar:', TurkceFormat.para(onizleme.kesinti.dagitilabilirTutar), isBold: true, color: Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: 'Hesaplama Sonuçları',
                    content: Column(
                      children: [
                        _buildSummaryRow('Dönem Katsayısı:', onizleme.katsayi.toStringAsFixed(4)),
                        _buildSummaryRow('Artık Bakiye:', TurkceFormat.para(onizleme.artikBakiye)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: 'Personel Dağılımı',
                    content: Column(
                      children: onizleme.personelDagitimlari.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildSummaryRow('${d.unvan} ${d.adSoyad}', TurkceFormat.para(d.brutHakedis), isBold: true),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      onizleme.kararMetni,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.blueGrey.shade200)),
          ),
          child: ElevatedButton(
            onPressed: provider.isSaving || onizleme == null
                ? null
                : () async {
                    final success = await provider.kaydet();
                    if (success && mounted) {
                      context.pop();
                    } else if (provider.saveError != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.saveError!)));
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Danışmanlığı Başlat & Kaydet', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({required String title, required Widget content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? Colors.blueGrey.shade900, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}
