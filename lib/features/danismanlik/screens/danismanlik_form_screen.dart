import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/turkce_format.dart';
import '../../auth/providers/auth_provider.dart';
import '../../personel/models/personel_model.dart';
import '../../personel/services/personel_service.dart';
import '../models/danismanlik_model.dart';
import '../providers/danismanlik_provider.dart';
import '../../yk_karar/models/yk_karar_model.dart';
import '../widgets/danismanlik_layout.dart';
import '../components/personel_secici_dialog.dart';
import '../../birim/models/birim_model.dart';
import '../../birim/services/birim_service.dart';

class DanismanlikFormScreen extends StatefulWidget {
  final YkKararModel? ykKarar;
  final DanismanlikModel? mevcutDanismanlik;
  const DanismanlikFormScreen({super.key, this.ykKarar, this.mevcutDanismanlik});

  @override
  State<DanismanlikFormScreen> createState() => _DanismanlikFormScreenState();
}

class _DanismanlikFormScreenState extends State<DanismanlikFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firmaController = TextEditingController();
  final _konuController = TextEditingController();
  final _brutController = TextEditingController();
  final _suresiController = TextEditingController(text: '1');
  final _birimAdController = TextEditingController();
  final _birimEvrakTarihiController = TextEditingController();
  final _birimEvrakSayisiController = TextEditingController();
  final _birimKararTarihiController = TextEditingController();
  final _birimToplantiSayisiController = TextEditingController();
  final _birimKararNoController = TextEditingController();
  final _ykToplantiSayisiController = TextEditingController();
  final _ykKararTarihiController = TextEditingController();
  final _ykKararNoController = TextEditingController();

  List<BirimModel>? _birimler;

  @override
  void initState() {
    super.initState();
    _loadBirimler();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DanismanlikProvider>();
      provider.temizle();
      final auth = context.read<AuthProvider>();
      final aktifBirimId = auth.currentUserModel?.birimId ?? '';
      if (aktifBirimId.isNotEmpty) {
        provider.setBirimId(aktifBirimId);
      }

      if (widget.mevcutDanismanlik != null) {
        provider.mevcutDanismanlikYukle(widget.mevcutDanismanlik!);
        _firmaController.text = widget.mevcutDanismanlik!.firmaUnvan ?? '';
        _konuController.text = widget.mevcutDanismanlik!.konusu;
        _brutController.text = widget.mevcutDanismanlik!.toplamTutar.toStringAsFixed(2);
        _suresiController.text = widget.mevcutDanismanlik!.suresi.toString();
        _birimAdController.text = widget.mevcutDanismanlik!.birimKisaAd ?? '';
        _birimKararTarihiController.text = widget.mevcutDanismanlik!.birimKararTarihi ?? '';
        _birimToplantiSayisiController.text = widget.mevcutDanismanlik!.birimToplantiSayisi ?? '';
        _birimKararNoController.text = widget.mevcutDanismanlik!.birimKararNo ?? '';
        _ykToplantiSayisiController.text = widget.mevcutDanismanlik!.ykToplantiSayisi ?? '';
        _ykKararTarihiController.text = widget.mevcutDanismanlik!.ykKararTarihi ?? '';
        _ykKararNoController.text = widget.mevcutDanismanlik!.ykKararNo ?? '';
      } else if (widget.ykKarar != null) {
        await _ykKararBilgileriniDoldur(provider, widget.ykKarar!);
      }
      _syncControllers(provider);
    });
  }

  Future<void> _loadBirimler() async {
    final srv = BirimService();
    final liste = await srv.getAll(onlyActive: true);
    if (mounted) {
      setState(() {
        _birimler = liste;
      });
    }
  }

  @override
  void dispose() {
    _firmaController.dispose();
    _konuController.dispose();
    _brutController.dispose();
    _suresiController.dispose();
    _birimAdController.dispose();
    _birimEvrakTarihiController.dispose();
    _birimEvrakSayisiController.dispose();
    _birimKararTarihiController.dispose();
    _birimToplantiSayisiController.dispose();
    _birimKararNoController.dispose();
    _ykToplantiSayisiController.dispose();
    _ykKararTarihiController.dispose();
    _ykKararNoController.dispose();
    super.dispose();
  }

  Future<void> _ykKararBilgileriniDoldur(
    DanismanlikProvider provider,
    YkKararModel karar,
  ) async {
    provider
      ..setKaynakYkKararId(karar.id)
      ..setBirimId(karar.birimId)
      ..setBirimAd(karar.birimAd)
      ..setBirimKararNo(karar.birimKararNo)
      ..setBirimKurulTarihi(karar.birimKurulTarihi)
      ..setBirimToplantiSayisi(karar.birimToplantiSayi)
      ..setYkToplantiSayisi(karar.toplantiNo)
      ..setYkKararTarihi(karar.kararTarihi)
      ..setYkKararNo(karar.kararNo)
      ..setFirmaUnvan(karar.baslik.replaceAll(' Danışmanlık', '').trim())
      ..setIsinKonusu(karar.baslik);

    await _ykTablosundanPersonelEkle(provider, karar);
  }

  Future<void> _ykTablosundanPersonelEkle(
    DanismanlikProvider provider,
    YkKararModel karar,
  ) async {
    if (karar.tabloVerileri.isEmpty) return;

    final service = PersonelService();
    final mevcutPersoneller = await service.getAll();
    for (final row in karar.tabloVerileri) {
      final adSoyad = _personelAdiniBul(row);
      if (adSoyad.isEmpty) continue;

      PersonelModel? mevcut;
      for (final personel in mevcutPersoneller) {
        if (personel.adSoyad.toLowerCase() == adSoyad.toLowerCase()) {
          mevcut = personel;
          break;
        }
      }

      if (mevcut != null) {
        provider.personelEkle(mevcut);
        continue;
      }

      final yeni = await service.add(
        PersonelModel(
          id: '',
          adSoyad: adSoyad,
          unvan: _unvanAyikla(adSoyad),
          tcKimlikNo: '',
          iban: '',
          unvanKatsayisi: _varsayilanUnvanKatsayisi(_unvanAyikla(adSoyad)),
          birimId: karar.birimId,
        ),
      );
      provider.personelEkle(yeni);
      mevcutPersoneller.add(yeni);
    }
  }

  String _personelAdiniBul(Map<String, dynamic> row) {
    final keys = [
      'Personel',
      'personel',
      'adiSoyadi',
      'adıSoyadı',
      'Adı Soyadı',
      'Ad Soyad',
      'adSoyad',
    ];
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  String _unvanAyikla(String adSoyad) {
    final lower = adSoyad.toLowerCase();
    if (lower.contains('prof')) return 'Prof. Dr.';
    if (lower.contains('doç') || lower.contains('doc')) return 'Doç. Dr.';
    if (lower.contains('dr. öğr') || lower.contains('dr. ogr')) {
      return 'Dr. Öğr. Üyesi';
    }
    if (lower.contains('arş') || lower.contains('ars')) return 'Arş. Gör.';
    return 'Öğr. Görevlisi';
  }

  double _varsayilanUnvanKatsayisi(String unvan) {
    final lower = unvan.toLowerCase();
    if (lower.contains('prof')) return 3;
    if (lower.contains('doç') || lower.contains('doc')) return 2.5;
    if (lower.contains('dr. öğr') || lower.contains('dr. ogr')) return 2;
    return 1;
  }

  void _syncControllers(DanismanlikProvider provider) {
    _firmaController.text = provider.firmaUnvan;
    _konuController.text = provider.isinKonusu;
    _brutController.text = provider.brutTaksitTutari > 0 ? provider.brutTaksitTutari.toString() : '';
    _suresiController.text = provider.suresi.toString();
    _birimAdController.text = provider.birimAd;
    _birimEvrakTarihiController.text = provider.birimEvrakTarihi;
    _birimEvrakSayisiController.text = provider.birimEvrakSayisi;
    _birimKararTarihiController.text = provider.birimKurulTarihi;
    _birimToplantiSayisiController.text = provider.birimToplantiSayisi;
    _birimKararNoController.text = provider.birimKararNo;
    _ykToplantiSayisiController.text = provider.ykToplantiSayisi;
    _ykKararTarihiController.text = provider.ykKararTarihi;
    _ykKararNoController.text = provider.ykKararNo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          DanismanlikLayout.kompaktBaslik(
            baslik: 'Yeni Danışmanlık',
            altBaslik: widget.ykKarar != null
                ? 'YK kararından oluşturuluyor'
                : null,
            aksiyon: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewW = DanismanlikLayout.sidebarGenislik(
                  constraints.maxWidth,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(
                          DanismanlikLayout.sayfaPadding,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKararBilgileriSection(context),
                              const SizedBox(
                                height: DanismanlikLayout.sectionGap,
                              ),
                              _buildFormSection(context),
                              const SizedBox(
                                height: DanismanlikLayout.sectionGap,
                              ),
                              _buildPersonelSection(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: previewW,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(color: Colors.blueGrey.shade100),
                        ),
                      ),
                      child: _buildPreviewPanel(context),
                    ),
                  ],
                );
              },
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DanismanlikTuru>(
                  initialValue: provider.tur,
                  decoration: const InputDecoration(
                    labelText: 'Danışmanlık Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: DanismanlikTuru.values.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Text(e.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) provider.setTur(val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _firmaController,
                  decoration: const InputDecoration(
                    labelText: 'Firma Ünvanı',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setFirmaUnvan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _konuController,
            decoration: const InputDecoration(
              labelText: 'İşin Konusu',
              border: OutlineInputBorder(),
            ),
            onChanged: provider.setIsinKonusu,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brutController,
                  decoration: const InputDecoration(
                    labelText: 'KDV Hariç Tutar (TL)',
                    border: OutlineInputBorder(),
                    prefixText: '₺ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [TlInputFormatter()],
                  onChanged: (v) {
                    // String içindeki 100.000,50 -> 100000.50 çevirimi
                    String clean = v.replaceAll('.', '').replaceAll(',', '.');
                    provider.setBrutTaksitTutari(double.tryParse(clean) ?? 0);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _suresiController,
                  decoration: const InputDecoration(
                    labelText: 'Süresi (Ay)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setSuresi(int.tryParse(v) ?? 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKararBilgileriSection(BuildContext context) {
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
            'Karar Bilgileri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bağlı birimden gelen yönetim kurulu kararı ve danışmanlığın kabul edildiği YK kararı ayrı tutulur.',
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Bağlı Birim Yönetim Kurulu Kararı',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          _birimler == null
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<BirimModel>(
                  value: _birimler!.where((b) => b.id == provider.birimId).firstOrNull,
                  decoration: const InputDecoration(
                    labelText: 'Bağlı Birim Seçiniz (Sistem Kaydı)',
                    border: OutlineInputBorder(),
                  ),
                  items: _birimler!.map((b) {
                    return DropdownMenuItem(
                      value: b,
                      child: Text('${b.kisaAd} - ${b.ad}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      provider.setBirimId(val.id);
                      provider.setBirimAd(val.kisaAd);
                      _birimAdController.text = val.kisaAd;
                      
                      final blob = '${val.kisaAd} ${val.ad}'.toLowerCase();
                      if (blob.contains('usem') ||
                          blob.contains('tömer') ||
                          blob.contains('tomer') ||
                          blob.contains('sürekli eğitim') ||
                          blob.contains('surekli egitim')) {
                        provider.setTur(DanismanlikTuru.egitimKuru);
                      } else {
                        provider.setTur(DanismanlikTuru.standart);
                      }
                    }
                  },
                ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _birimAdController,
            decoration: const InputDecoration(
              labelText: 'Alt Birim / İşin Detayı (Örn: TÖMER XYZ Eğitimi)',
              border: OutlineInputBorder(),
            ),
            onChanged: provider.setBirimAd,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _birimEvrakTarihiController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Üst Yazı (Evrak) Tarihi',
                    hintText: 'gg.aa.yyyy',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setBirimEvrakTarihi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _birimEvrakSayisiController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Üst Yazı (Evrak) Sayısı',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setBirimEvrakSayisi,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _birimKararTarihiController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Karar Tarihi',
                    hintText: 'gg.aa.yyyy',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setBirimKurulTarihi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _birimToplantiSayisiController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Toplantı No',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setBirimToplantiSayisi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _birimKararNoController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Karar Sayısı',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setBirimKararNo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Yürütme Kurulu Kabul Kararı',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ykToplantiSayisiController,
                  decoration: const InputDecoration(
                    labelText: 'YK Toplantı No',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setYkToplantiSayisi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ykKararTarihiController,
                  decoration: const InputDecoration(
                    labelText: 'YK Karar Tarihi',
                    hintText: 'gg.aa.yyyy',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setYkKararTarihi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ykKararNoController,
                  decoration: const InputDecoration(
                    labelText: 'YK Karar No',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: provider.setYkKararNo,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showPersonelSecici(context, provider),
                icon: const Icon(Icons.add),
                label: const Text('Personel Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.personeller.isEmpty)
            const Text(
              'Henüz personel eklenmedi.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.personeller.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = provider.personeller[index];
                return Card(
                  elevation: 0,
                  color: Colors.blueGrey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.personel.unvan} ${p.personel.adSoyad}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (provider.onizleme != null)
                                Builder(builder: (_) {
                                  final stats = provider.onizleme!.personelDagitimlari.where((dp) => dp.personelId == p.personel.id).firstOrNull;
                                  if (stats == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Kat: ${stats.unvanKatsayisi} • Toplam Puan: ${stats.bireyselPuan.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('puan_${p.personel.id}'),
                            initialValue: p.faaliyetPuani > 0
                                ? p.faaliyetPuani.toString()
                                : '',
                            decoration: const InputDecoration(
                              labelText: 'Puanı',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (v) => context
                                .read<DanismanlikProvider>()
                                .personelPuanGuncelle(
                                  index,
                                  double.tryParse(v.replaceAll(',', '.')) ?? 0,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('ders_${p.personel.id}'),
                            initialValue: p.dersSaati > 0 ? '${p.dersSaati.toInt()}' : '',
                            decoration: const InputDecoration(
                              labelText: 'Ders Saati',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (v) => context
                                .read<DanismanlikProvider>()
                                .personelDersSaatiGuncelle(
                                  index,
                                  double.tryParse(v.replaceAll(',', '.')) ?? 0,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            key: ValueKey('pay_${p.personel.id}'),
                            initialValue: '${p.payOrani}',
                            decoration: const InputDecoration(
                              labelText: 'Pay %',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => context
                                .read<DanismanlikProvider>()
                                .personelPayGuncelle(
                                  index,
                                  int.tryParse(v) ?? 100,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Personeli çıkar',
                          onPressed: () => context
                              .read<DanismanlikProvider>()
                              .personelCikar(index),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showPersonelSecici(
    BuildContext context,
    DanismanlikProvider provider,
  ) async {
    final personel = await showDialog<PersonelModel>(
      context: context,
      builder: (_) => PersonelSeciciDialog(
        varsayilanBirimId: provider.birimId,
        varsayilanBirimAd: provider.birimAd,
      ),
    );
    if (personel == null) return;
    provider.personelEkle(personel);
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
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
                        _buildSummaryRow(
                          'Sözleşme Tutarı (KDV Dahil):',
                          TurkceFormat.para(onizleme.kdvDahilTutar),
                          isBold: true,
                          color: Colors.blueGrey.shade900,
                        ),
                        _buildSummaryRow(
                          'KDV Tutarı (%${provider.kdvOrani}):',
                          TurkceFormat.para(onizleme.kdvTutari),
                          color: Colors.red.shade400,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'KDV Hariç Matrah:',
                          TurkceFormat.para(onizleme.kdvHaricMatrah),
                          isBold: true,
                        ),
                        _buildSummaryRow(
                          'Hazine Payı:',
                          TurkceFormat.para(onizleme.kesinti.hazinePayi),
                        ),
                        _buildSummaryRow(
                          'BAP Payı:',
                          TurkceFormat.para(onizleme.kesinti.bapPayi),
                        ),
                        _buildSummaryRow(
                          'Araç Gereç Payı:',
                          TurkceFormat.para(onizleme.kesinti.aracGerecPayi),
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'Dağıtılabilir Tutar:',
                          TurkceFormat.para(
                            onizleme.kesinti.dagitilabilirTutar,
                          ),
                          isBold: true,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final toplamPuan = onizleme.personelDagitimlari.fold(0.0, (sum, p) => sum + p.bireyselPuan);
                      final saglama = toplamPuan * onizleme.katsayi;
                      final egitimPersoneli = onizleme.personelDagitimlari.where((p) => p.dersSaati > 0).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(
                            title: 'DÖNEM EK KATSAYI HESAPLAMA',
                            content: Column(
                              children: [
                                _buildSummaryRow(
                                  'Dağıtılacak Maks. Akademik Pay:',
                                  TurkceFormat.para(onizleme.kesinti.dagitilabilirTutar),
                                  isBold: true,
                                  color: Colors.green.shade700,
                                ),
                                _buildSummaryRow('Toplam Puan:', toplamPuan.toStringAsFixed(0)),
                                _buildSummaryRow('Dönem Ek Ödeme Katsayısı:', onizleme.katsayi.toStringAsFixed(6)),
                                _buildSummaryRow('Sağlaması (Puan x Katsayı):', TurkceFormat.para(saglama)),
                                _buildSummaryRow('Artık Bakiye:', TurkceFormat.para(onizleme.artikBakiye)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (egitimPersoneli.isNotEmpty)
                            _buildSummaryCard(
                              title: 'KURSUN 1 SAATLİK ÜCRETİ HESAPLAMA',
                              content: Column(
                                children: egitimPersoneli.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Column(
                                    children: [
                                      _buildSummaryRow(
                                        'Personel:',
                                        '${p.unvan} ${p.adSoyad}',
                                        color: Colors.blueGrey.shade700,
                                      ),
                                      _buildSummaryRow('Bireysel Net Katkı Puanı:', p.bireyselPuan.toStringAsFixed(0)),
                                      _buildSummaryRow('Verdiği Ders Saati:', p.dersSaati.toStringAsFixed(0)),
                                      _buildSummaryRow(
                                        'Kursun 1 Saatlik Ücreti:',
                                        TurkceFormat.para(p.saatlikUcret),
                                        isBold: true,
                                      ),
                                      const Divider(),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                          if (egitimPersoneli.isNotEmpty) const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    title: 'Personel Dağılımı (Excel Görünümü)',
                    content: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800,
                          fontSize: 13,
                        ),
                        dataTextStyle: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontSize: 13,
                        ),
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        columns: const [
                          DataColumn(label: Text('Personel')),
                          DataColumn(label: Text('Puan')),
                          DataColumn(label: Text('Kat.')),
                          DataColumn(label: Text('Saat')),
                          DataColumn(label: Text('B.Net')),
                          DataColumn(label: Text('Brüt Hakediş')),
                          DataColumn(label: Text('Havuz')),
                        ],
                        rows: onizleme.personelDagitimlari.map((d) {
                          return DataRow(cells: [
                            DataCell(Text('${d.unvan} ${d.adSoyad}')),
                            DataCell(Text(d.faaliyetPuani.toString())),
                            DataCell(Text(d.unvanKatsayisi.toString())),
                            DataCell(Text(d.dersSaati > 0 ? d.dersSaati.toString() : '-')),
                            DataCell(Text(d.bireyselPuan.toStringAsFixed(0))),
                            DataCell(Text(
                              TurkceFormat.para(d.brutHakedis),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              d.tavanAsimi ? TurkceFormat.para(d.havuzTutari) : '-',
                              style: TextStyle(
                                color: d.tavanAsimi ? Colors.red.shade600 : Colors.blueGrey.shade400,
                              ),
                            )),
                          ]);
                        }).toList(),
                      ),
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
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.amber.shade900,
                      ),
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
                    final aktifBirimId = context
                        .read<AuthProvider>()
                        .currentUserModel
                        ?.birimId;
                    final success = await provider.kaydet(
                      fallbackBirimId: aktifBirimId,
                    );
                    if (!context.mounted) return;
                    if (success) {
                      context.pop();
                    } else if (provider.saveError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(provider.saveError!)),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Danışmanlığı Başlat & Kaydet',
              style: TextStyle(fontSize: 16),
            ),
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.blueGrey.shade900,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TlInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Sadece rakam ve virgül kalacak şekilde temizle (nokta falan varsa sil)
    String text = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    
    // Birden fazla virgül varsa engelle (eski haline dön)
    if (text.split(',').length > 2) {
      return oldValue;
    }

    List<String> parts = text.split(',');
    String tamKisim = parts[0];
    String? ondalikKisim = parts.length > 1 ? parts[1] : null;

    if (tamKisim.isNotEmpty) {
      final int value = int.parse(tamKisim);
      final formatter = NumberFormat("#,###", "tr_TR");
      tamKisim = formatter.format(value);
    }

    String finalString = tamKisim;
    if (ondalikKisim != null) {
      // Sadece 2 ondalık basamağa izin ver
      if (ondalikKisim.length > 2) {
        ondalikKisim = ondalikKisim.substring(0, 2);
      }
      finalString = '$tamKisim,$ondalikKisim';
    } else if (newValue.text.endsWith(',')) {
      finalString = '$tamKisim,';
    }

    // İmleci sona al
    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}
