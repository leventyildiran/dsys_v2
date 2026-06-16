import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../core/models/sablon_model.dart';
import '../../../core/services/sablon_service.dart';
import '../../../core/services/birim_service.dart';
import '../../../core/models/birim_model.dart';
import 'sablon_editor_screen.dart';

class SablonYonetimScreen extends StatefulWidget {
  const SablonYonetimScreen({super.key});

  @override
  State<SablonYonetimScreen> createState() => _SablonYonetimScreenState();
}

class _SablonYonetimScreenState extends State<SablonYonetimScreen> {
  final SablonService _sablonService = SablonService();
  final BirimService _birimService = BirimService();
  List<SablonModel> _sablonlar = [];
  List<BirimModel> _birimler = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSablonlar();
  }

  Future<void> _loadSablonlar() async {
    try {
      final sablonlar = await _sablonService.getAllSablonlar();
      final birimler = await _birimService.getAll();
      if (mounted) {
        setState(() {
          _sablonlar = sablonlar;
          _birimler = birimler;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Şablonlar yüklenirken hata: $e')));
      }
    }
  }

  Future<void> _deleteSablon(SablonModel sablon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: Text('${sablon.sablonAdi} isimli şablonu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _sablonService.deleteSablon(sablon);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şablon başarıyla silindi')));
        _loadSablonlar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinirken hata: $e')));
      }
    }
  }

  Future<void> _uploadNewSablon() async {
    // Platform independent file picker
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'docx', 'doc', 'pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        _showUploadDialog(file.name, file.bytes!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı!')));
        }
      }
    }
  }

  Future<void> _showUploadDialog(String fileName, Uint8List fileBytes) async {
    final nameController = TextEditingController(text: fileName);
    String selectedTur = 'diger';
    BirimModel? selectedBirim;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Şablon Yükle'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Şablon Adı'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTur,
                decoration: const InputDecoration(labelText: 'Şablon Türü'),
                items: const [
                  DropdownMenuItem(value: 'fatura', child: Text('Fatura Şablonu')),
                  DropdownMenuItem(value: 'yk_karar', child: Text('YK Karar Şablonu')),
                  DropdownMenuItem(value: 'gundem', child: Text('Gündem Şablonu')),
                  DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedTur = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BirimModel?>(
                value: selectedBirim,
                decoration: const InputDecoration(labelText: 'Hangi Birim İçin?'),
                items: [
                  const DropdownMenuItem<BirimModel?>(value: null, child: Text('Tüm Birimler (Ortak)')),
                  ..._birimler.map((b) => DropdownMenuItem(value: b, child: Text(b.ad))).toList(),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedBirim = val);
                },
              ),
              const SizedBox(height: 16),
              Text('Seçilen Dosya: $fileName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yükle')),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _sablonService.addSablon(
          nameController.text, 
          selectedTur, 
          fileName, 
          fileBytes,
          birimId: selectedBirim?.id,
          birimAd: selectedBirim?.ad,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şablon başarıyla yüklendi!')));
          _loadSablonlar();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Şablonları & Form Havuzu'),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SablonEditorScreen()),
              );
              if (result == true) {
                _loadSablonlar();
              }
            },
            icon: const Icon(Icons.edit_document),
            label: const Text('Metin Şablonu'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _uploadNewSablon,
            icon: const Icon(Icons.upload_file),
            label: const Text('Dosya Yükle'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sablonlar.isEmpty
              ? const Center(child: Text('Henüz hiç şablon yüklenmemiş.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sablonlar.length,
                  itemBuilder: (context, index) {
                    final sablon = _sablonlar[index];
                    return Card(
                      child: ListTile(
                        leading: _getIconForExtension(sablon.dosyaUzantisi),
                        title: Text(sablon.sablonAdi),
                        subtitle: Text(
                        'Tür: ${sablon.tur} | Birim: ${sablon.birimAd ?? 'Tüm Birimler'} | '
                        '${sablon.dosyaUzantisi == '.docx' ? 'Word Arşivi' : sablon.dosyaUzantisi} | '
                        'Tarih: ${DateFormat('dd.MM.yyyy').format(sablon.eklenmeTarihi)}',
                      ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sablon.dosyaUzantisi == '.txt')
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.green),
                                tooltip: 'Düzenle',
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SablonEditorScreen(
                                      existingSablonId: sablon.id,
                                      existingSablonAdi: sablon.sablonAdi,
                                      existingSablonTur: sablon.tur,
                                      existingDeltaJson: sablon.dosyaUrl,
                                      existingBirimId: sablon.birimId,
                                      existingBirimAd: sablon.birimAd,
                                    )),
                                  );
                                  if (result == true) {
                                    _loadSablonlar();
                                  }
                                },
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.download, color: Colors.blue),
                                tooltip: 'İndir',
                                onPressed: () => launchUrl(Uri.parse(sablon.dosyaUrl)),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Sil',
                              onPressed: () => _deleteSablon(sablon),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _getIconForExtension(String ext) {
    if (ext == '.txt') return const Icon(Icons.text_snippet, color: Colors.orange, size: 32);
    if (ext.contains('xls')) return const Icon(Icons.table_chart, color: Colors.green, size: 32);
    if (ext.contains('doc')) return const Icon(Icons.description, color: Colors.blue, size: 32);
    if (ext.contains('pdf')) return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32);
    return const Icon(Icons.insert_drive_file, color: Colors.grey, size: 32);
  }
}
