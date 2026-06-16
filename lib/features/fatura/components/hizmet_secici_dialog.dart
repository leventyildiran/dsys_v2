import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/models/hizmet_model.dart';
import '../../../core/services/hizmet_service.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/services/firma_service.dart';

class HizmetSeciciDialog extends StatefulWidget {
  final String? initialBirimAd;
  const HizmetSeciciDialog({super.key, this.initialBirimAd});

  @override
  State<HizmetSeciciDialog> createState() => _HizmetSeciciDialogState();
}

class _HizmetSeciciDialogState extends State<HizmetSeciciDialog> {
  final HizmetService _hizmetService = HizmetService();
  List<String> _birimler = [];
  String? _selectedBirim;
  List<HizmetModel> _hizmetler = [];
  bool _isLoading = true;
  bool _isLoadingHizmetler = false;
  String _searchQuery = '';

  List<HizmetModel> get _filteredHizmetler {
    if (_searchQuery.isEmpty) return _hizmetler;
    return _hizmetler.where((h) => h.hizmetAdi.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadBirimler();
  }

  Future<void> _loadBirimler() async {
    try {
      final birimler = await _hizmetService.getBirimler();
      if (mounted) {
        setState(() {
          _birimler = birimler;
          _isLoading = false;
          if (widget.initialBirimAd != null && _birimler.contains(widget.initialBirimAd)) {
            _loadHizmetler(widget.initialBirimAd!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _migrateYeniVeriler() async {
    try {
      final String response = await DefaultAssetBundle.of(context).loadString('assets/data/yeni_veriler.json');
      final Map<String, dynamic> data = json.decode(response);
      
      int firmaCount = 0;
      final FirmaService fService = FirmaService();
      final mevcutFirmalar = await fService.getAllFirmalar(forceRefresh: true);
      
      for (var f in data['firmalar']) {
        final fAdi = (f['firmaAdi'] ?? '').toString().trim();
        if (fAdi.isNotEmpty && !mevcutFirmalar.any((existing) => existing.firmaAdi.toLowerCase() == fAdi.toLowerCase())) {
          final firma = FirmaModel(
            id: '',
            firmaAdi: fAdi,
            adres: f['adres'] ?? '',
            vergiDairesi: '',
            vergiNo: ''
          );
          await fService.addFirma(firma);
          firmaCount++;
        }
      }

      int hizmetCount = 0;
      final mevcutHizmetler = await _hizmetService.getAllHizmetler(forceRefresh: true);

      for (var h in data['hizmetler']) {
        final bAdi = (h['birimAdi'] ?? '').toString().trim();
        final hAdi = (h['hizmetAdi'] ?? '').toString().trim();
        if (bAdi.isNotEmpty && hAdi.isNotEmpty && !mevcutHizmetler.any((existing) => 
            existing.birimAdi.toLowerCase() == bAdi.toLowerCase() && 
            existing.hizmetAdi.toLowerCase() == hAdi.toLowerCase())) {
          final hizmet = HizmetModel(
            id: '',
            birimAdi: bAdi,
            hizmetAdi: hAdi,
            fiyat: (h['fiyat'] ?? 0).toDouble()
          );
          await _hizmetService.addHizmet(hizmet);
          hizmetCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktarım Tamamlandı! $firmaCount firma, $hizmetCount hizmet eklendi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _loadHizmetler(String birimAdi) async {
    setState(() {
      _selectedBirim = birimAdi;
      _isLoadingHizmetler = true;
    });
    try {
      final hizmetler = await _hizmetService.getHizmetlerByBirim(birimAdi);
      if (mounted) {
        setState(() {
          _hizmetler = hizmetler;
          _isLoadingHizmetler = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHizmetler = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _showFiyatGuncelleDialog(HizmetModel hizmet) async {
    final formKey = GlobalKey<FormState>();
    final fiyatController = TextEditingController(
      text: hizmet.fiyat.toStringAsFixed(2).replaceAll('.', ','),
    );

    final kaydedildi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fiyat Güncelle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hizmet.hizmetAdi,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                hizmet.birimAdi,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: fiyatController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Birim Fiyatı (₺)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Zorunlu';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed < 0) return 'Geçerli bir fiyat girin';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final yeniFiyat =
                  double.tryParse(fiyatController.text.replaceAll(',', '.')) ?? 0.0;
              final guncel = HizmetModel(
                id: hizmet.id,
                birimAdi: hizmet.birimAdi,
                hizmetAdi: hizmet.hizmetAdi,
                fiyat: yeniFiyat,
              );
              await _hizmetService.updateHizmet(guncel);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    fiyatController.dispose();
    if (kaydedildi == true && mounted && _selectedBirim != null) {
      await _loadHizmetler(_selectedBirim!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiyat güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showYeniHizmetEkleDialog() async {
    if (_selectedBirim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce soldan bir birim seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final hizmetAdiController = TextEditingController();
    final fiyatController = TextEditingController();
    final seciliBirim = _selectedBirim!;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Birime Özel Kalem Ekle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: seciliBirim,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Birim',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hizmetAdiController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Hizmet / Kalem Adı',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fiyatController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Fiyatı (₺)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Zorunlu';
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) return 'Geçerli bir fiyat girin';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final yeni = HizmetModel(
                  id: '',
                  birimAdi: seciliBirim,
                  hizmetAdi: hizmetAdiController.text.trim(),
                  fiyat: double.tryParse(fiyatController.text.replaceAll(',', '.')) ?? 0.0,
                );
                await _hizmetService.addHizmet(yeni);
                if (context.mounted) {
                  Navigator.pop(context);
                  await _loadBirimler();
                  await _loadHizmetler(seciliBirim);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Kalem eklendi.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    hizmetAdiController.dispose();
    fiyatController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Birim Fiyat Listesi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.cloud_download, color: Colors.grey), onPressed: _migrateYeniVeriler),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Kalem Ara...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  // SOL TARAF: BİRİMLER
                  Container(
                    width: 250,
                    color: Colors.grey.shade50,
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _birimler.length,
                          itemBuilder: (context, index) {
                            final birim = _birimler[index];
                            final isSelected = birim == _selectedBirim;
                            return ListTile(
                              title: Text(birim, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedTileColor: Colors.teal.shade50,
                              onTap: () => _loadHizmetler(birim),
                            );
                          },
                        ),
                  ),
                  const VerticalDivider(width: 1),
                  // SAĞ TARAF: HİZMETLER
                  Expanded(
                    child: _selectedBirim == null
                      ? const Center(child: Text('Lütfen soldan bir birim seçiniz', style: TextStyle(color: Colors.grey)))
                      : _isLoadingHizmetler
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredHizmetler.isEmpty
                          ? const Center(child: Text('Hizmet bulunamadı.'))
                          : ListView.builder(
                              itemCount: _filteredHizmetler.length,
                              itemBuilder: (context, index) {
                                final hizmet = _filteredHizmetler[index];
                                return Card(
                                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => Navigator.pop(context, hizmet),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    hizmet.hizmetAdi,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${hizmet.fiyat.toStringAsFixed(2)} ₺',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: FilledButton.tonalIcon(
                                            onPressed: () =>
                                                _showFiyatGuncelleDialog(hizmet),
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('Düzenle'),
                                            style: FilledButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              foregroundColor: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedBirim != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Seçili birim: $_selectedBirim',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _selectedBirim == null ? null : _showYeniHizmetEkleDialog,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _selectedBirim == null
                          ? 'Önce birim seçin'
                          : 'Bu Birime Yeni Kalem Ekle',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
