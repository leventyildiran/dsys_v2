import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
    final provider = context.watch<DanismanlikProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          DanismanlikLayout.kompaktBaslik(
            baslik: widget.mevcutDanismanlik != null
                ? 'Danışmanlık Düzenle'
                : 'Yeni Danışmanlık Sözleşmesi',
            altBaslik: widget.ykKarar != null
                ? 'YK kararından oluşturuluyor'
                : 'Sözleşme ve bağlı birim karar kayıt formu',
            aksiyon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: provider.isSaving ? null : () => _kaydet(context, provider),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                  tooltip: 'Kapat',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKararBilgileriSection(context),
                        const SizedBox(height: 24),
                        _buildFormSection(context),
                        const SizedBox(height: 24),
                        _buildPersonelSection(context),
                        const SizedBox(height: 32),
                        _buildKaydetSection(context, provider),
                      ],
                    ),
                  ),
                ),
              ),
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
                  initialValue: _birimler!.where((b) => b.id == provider.birimId).firstOrNull,
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
                child: _buildDateField(
                  context: context,
                  label: 'Birim Üst Yazı (Evrak) Tarihi',
                  controller: _birimEvrakTarihiController,
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
                    isDense: true,
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
                child: _buildDateField(
                  context: context,
                  label: 'Birim Karar Tarihi',
                  controller: _birimKararTarihiController,
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
                    isDense: true,
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
                    isDense: true,
                  ),
                  onChanged: provider.setBirimKararNo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Yürütme Kurulu Kabul Kararı',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ykToplantiSayisiController,
                  decoration: const InputDecoration(
                    labelText: 'YK Toplantı No',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: provider.setYkToplantiSayisi,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  context: context,
                  label: 'YK Karar Tarihi',
                  controller: _ykKararTarihiController,
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
                    isDense: true,
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

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'gg.aa.yyyy',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_outlined, size: 20),
          tooltip: 'Takvimden Seç',
          onPressed: () async {
            DateTime initialDate = DateTime.now();
            final raw = controller.text.trim();
            if (raw.isNotEmpty) {
              final parts = raw.split('.');
              if (parts.length == 3) {
                final d = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final y = int.tryParse(parts[2]);
                if (d != null && m != null && y != null && y > 2000 && y < 2100) {
                  initialDate = DateTime(y, m, d);
                }
              }
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
              controller.text = formatted;
              onChanged(formatted);
            }
          },
        ),
      ),
      onChanged: onChanged,
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
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Katsayı: ${p.personel.unvanKatsayisi}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (provider.tur == DanismanlikTuru.egitimKuru) ...[
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
                        ],
                        const SizedBox(width: 8),
                        SizedBox(
                          width: provider.tur == DanismanlikTuru.egitimKuru ? 90 : 130,
                          child: TextFormField(
                            key: ValueKey('pay_${p.personel.id}'),
                            initialValue: '${p.payOrani}',
                            decoration: const InputDecoration(
                              labelText: 'Pay Oranı %',
                              suffixText: '%',
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

  Widget _buildKaydetSection(BuildContext context, DanismanlikProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.saveError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.saveError!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('İptal / Vazgeç'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: provider.isSaving ? null : () => _kaydet(context, provider),
                icon: provider.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  widget.mevcutDanismanlik != null ? 'Değişiklikleri Kaydet' : 'Danışmanlık Sözleşmesini Kaydet',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _kaydet(BuildContext context, DanismanlikProvider provider) async {
    final aktifBirimId = context.read<AuthProvider>().currentUserModel?.birimId;
    final success = await provider.kaydet(fallbackBirimId: aktifBirimId);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Danışmanlık sözleşmesi başarıyla kaydedildi.'),
          backgroundColor: Color(0xFF1E8E5A),
        ),
      );
      context.pop();
    } else if (provider.saveError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.saveError!),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
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
