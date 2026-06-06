import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/services/firma_service.dart';

class FirmaSeciciDialog extends StatefulWidget {
  const FirmaSeciciDialog({super.key});

  @override
  State<FirmaSeciciDialog> createState() => _FirmaSeciciDialogState();
}

class _FirmaSeciciDialogState extends State<FirmaSeciciDialog> {
  final FirmaService _firmaService = FirmaService();
  List<FirmaModel> _firmalar = [];
  List<FirmaModel> _filteredFirmalar = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFirmalar();
  }

  Future<void> _loadFirmalar() async {
    try {
      final firmalar = await _firmaService.getAllFirmalar();
      if (mounted) {
        setState(() {
          _firmalar = firmalar;
          _filteredFirmalar = firmalar;
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

  Future<void> _migrateFirmalarFromJson() async {
    try {
      final String response = await DefaultAssetBundle.of(context).loadString('assets/data/firmalar.json');
      final List<dynamic> data = json.decode(response);
      int count = 0;
      for (var item in data) {
        final firma = FirmaModel(
          id: '',
          firmaAdi: item['firmaAdi'] ?? '',
          adres: item['adres'] ?? '',
          vergiDairesi: item['vergiDairesi'] ?? '',
          vergiNo: item['vergiNo'] ?? '',
        );
        await _firmaService.addFirma(firma);
        count++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count adet firma başarıyla aktarıldı!')));
        _loadFirmalar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktarım Hatası: $e')));
      }
    }
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredFirmalar = _firmalar.where((f) {
        return f.firmaAdi.toLowerCase().contains(query.toLowerCase()) ||
               f.vergiNo.contains(query);
      }).toList();
    });
  }

  void _showYeniFirmaEkleDialog() {
    final _formKey = GlobalKey<FormState>();
    final _adController = TextEditingController(text: _searchQuery);
    final _adresController = TextEditingController();
    final _vdController = TextEditingController();
    final _vknController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Firma Kaydet'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _adController,
                    decoration: const InputDecoration(labelText: 'Firma Adı'),
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  TextFormField(
                    controller: _adresController,
                    decoration: const InputDecoration(labelText: 'Adres'),
                    maxLines: 2,
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  TextFormField(
                    controller: _vdController,
                    decoration: const InputDecoration(labelText: 'Vergi Dairesi'),
                  ),
                  TextFormField(
                    controller: _vknController,
                    decoration: const InputDecoration(labelText: 'VKN / TCKN'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final yeniFirma = FirmaModel(
                    id: '',
                    firmaAdi: _adController.text,
                    adres: _adresController.text,
                    vergiDairesi: _vdController.text,
                    vergiNo: _vknController.text,
                  );
                  await _firmaService.addFirma(yeniFirma);
                  Navigator.pop(context);
                  _loadFirmalar(); // Reload list
                }
              },
              child: const Text('Kaydet'),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kayıtlı Firmalar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Firma Ara (Ad veya VKN)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredFirmalar.length,
                    itemBuilder: (context, index) {
                      final firma = _filteredFirmalar[index];
                      return ListTile(
                        leading: const Icon(Icons.business, color: Colors.indigo),
                        title: Text(firma.firmaAdi, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${firma.adres}\nVD: ${firma.vergiDairesi} - VKN: ${firma.vergiNo}'),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.pop(context, firma);
                        },
                      );
                    },
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showYeniFirmaEkleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Yeni Firma Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
