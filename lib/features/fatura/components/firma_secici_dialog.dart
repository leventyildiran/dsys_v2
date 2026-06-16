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

  Future<void> _loadFirmalar({bool forceRefresh = false}) async {
    try {
      final firmalar = await _firmaService.getAllFirmalar(
        forceRefresh: forceRefresh,
      );
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
    _showFirmaFormDialog();
  }

  void _showFirmaDuzenleDialog(FirmaModel firma) {
    _showFirmaFormDialog(firma: firma);
  }

  void _showFirmaFormDialog({FirmaModel? firma}) {
    final duzenleme = firma != null;
    final formKey = GlobalKey<FormState>();
    final adController = TextEditingController(
      text: firma?.firmaAdi ?? _searchQuery,
    );
    final adresController = TextEditingController(text: firma?.adres ?? '');
    final vdController = TextEditingController(text: firma?.vergiDairesi ?? '');
    final vknController = TextEditingController(text: firma?.vergiNo ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(duzenleme ? 'Firmayı Düzenle' : 'Yeni Firma Kaydet'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: adController,
                    decoration: const InputDecoration(labelText: 'Firma Adı'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Boş bırakılamaz' : null,
                  ),
                  TextFormField(
                    controller: adresController,
                    decoration: const InputDecoration(labelText: 'Adres'),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Boş bırakılamaz' : null,
                  ),
                  TextFormField(
                    controller: vdController,
                    decoration: const InputDecoration(
                      labelText: 'Vergi Dairesi',
                    ),
                  ),
                  TextFormField(
                    controller: vknController,
                    decoration: const InputDecoration(labelText: 'VKN / TCKN'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final kayit = FirmaModel(
                  id: firma?.id ?? '',
                  firmaAdi: adController.text.trim(),
                  adres: adresController.text.trim(),
                  vergiDairesi: vdController.text.trim(),
                  vergiNo: vknController.text.trim(),
                );

                if (duzenleme) {
                  await _firmaService.updateFirma(kayit);
                } else {
                  await _firmaService.addFirma(kayit);
                }

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (!mounted) return;
                _loadFirmalar(forceRefresh: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      duzenleme
                          ? 'Firma bilgileri güncellendi.'
                          : 'Yeni firma kaydedildi.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text(duzenleme ? 'Güncelle' : 'Kaydet'),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => Navigator.pop(context, firma),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.business,
                                        color: Colors.indigo,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              firma.firmaAdi,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              firma.adres,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'VD: ${firma.vergiDairesi} - VKN: ${firma.vergiNo}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Düzenle'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Colors.indigo,
                                  ),
                                  onPressed: () =>
                                      _showFirmaDuzenleDialog(firma),
                                ),
                              ),
                            ],
                          ),
                        ),
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
