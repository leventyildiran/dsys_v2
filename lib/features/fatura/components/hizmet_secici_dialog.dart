import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/models/hizmet_model.dart';
import '../../../core/services/hizmet_service.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/services/firma_service.dart';

class HizmetSeciciDialog extends StatefulWidget {
  const HizmetSeciciDialog({super.key});

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

  Future<void> _migrateHizmetlerFromJson() async {
    try {
      final String response = await DefaultAssetBundle.of(context).loadString('assets/data/hizmetler.json');
      final List<dynamic> data = json.decode(response);
      int count = 0;
      for (var item in data) {
        final hizmet = HizmetModel(
          id: '',
          birimAdi: item['birimAdi'] ?? '',
          hizmetAdi: item['hizmetAdi'] ?? '',
          fiyat: (item['fiyat'] as num?)?.toDouble() ?? 0.0,
        );
        await _hizmetService.addHizmet(hizmet);
        count++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count adet fiyat başarıyla aktarıldı!')));
        if (_selectedBirim != null) {
          _loadHizmetler(_selectedBirim!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktarım Hatası: $e')));
      }
    }
  }

  Future<void> _showYeniHizmetEkleDialog() async {
    final formKey = GlobalKey<FormState>();
    final birimController = TextEditingController(text: _selectedBirim ?? '');
    final hizmetAdiController = TextEditingController();
    final fiyatController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Hizmet / Kalem Ekle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: birimController,
                  decoration: const InputDecoration(labelText: 'Birim Adı (Örn: DÖSİM, UBATAM)'),
                  validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: hizmetAdiController,
                  decoration: const InputDecoration(labelText: 'Hizmet / Kalem Adı'),
                  validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                ),
                TextFormField(
                  controller: fiyatController,
                  decoration: const InputDecoration(labelText: 'Birim Fiyatı (₺)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final yeni = HizmetModel(
                    id: '',
                    birimAdi: birimController.text.trim(),
                    hizmetAdi: hizmetAdiController.text.trim(),
                    fiyat: double.tryParse(fiyatController.text.replaceAll(',', '.')) ?? 0.0,
                  );
                  await _hizmetService.addHizmet(yeni);
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadBirimler();
                    if (_selectedBirim == yeni.birimAdi) {
                      await _loadHizmetler(yeni.birimAdi);
                    }
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
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
                          : ListView.separated(
                              itemCount: _filteredHizmetler.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final hizmet = _filteredHizmetler[index];
                                return ListTile(
                                  title: Text(hizmet.hizmetAdi),
                                  trailing: Text(
                                    '${hizmet.fiyat.toStringAsFixed(2)} ₺',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, hizmet);
                                  },
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
              child: ElevatedButton.icon(
                onPressed: _showYeniHizmetEkleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Yeni Birim / Hizmet Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
