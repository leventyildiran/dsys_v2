import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/services/sablon_service.dart';
import '../../../core/services/birim_service.dart';
import '../../../core/models/birim_model.dart';

class SablonEditorScreen extends StatefulWidget {
  final String? existingSablonId;
  final String? existingSablonAdi;
  final String? existingSablonTur;
  final String? existingDeltaJson;
  final String? existingBirimId;
  final String? existingBirimAd;

  const SablonEditorScreen({
    super.key,
    this.existingSablonId,
    this.existingSablonAdi,
    this.existingSablonTur,
    this.existingDeltaJson,
    this.existingBirimId,
    this.existingBirimAd,
  });

  @override
  State<SablonEditorScreen> createState() => _SablonEditorScreenState();
}

class _SablonEditorScreenState extends State<SablonEditorScreen> {
  late quill.QuillController _controller;
  final TextEditingController _nameController = TextEditingController();
  String _selectedTur = 'yk_karar';
  final SablonService _sablonService = SablonService();
  final BirimService _birimService = BirimService();
  bool _isLoading = false;
  List<BirimModel> _birimler = [];
  BirimModel? _selectedBirim;

  @override
  void initState() {
    super.initState();
    if (widget.existingSablonAdi != null) {
      _nameController.text = widget.existingSablonAdi!;
    }
    if (widget.existingSablonTur != null) {
      _selectedTur = widget.existingSablonTur!;
    }

    if (widget.existingDeltaJson != null && widget.existingDeltaJson!.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.existingDeltaJson!));
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
    }
    _loadBirimler();
  }

  Future<void> _loadBirimler() async {
    try {
      final birimler = await _birimService.getAll();
      if (mounted) {
        setState(() {
          _birimler = birimler;
          if (widget.existingBirimId != null) {
            _selectedBirim = birimler.firstWhere(
              (b) => b.id == widget.existingBirimId,
              orElse: () => birimler.first,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Birimler yüklenirken hata: $e');
    }
  }

  Future<void> _saveSablon() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen şablon adı giriniz')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
      
      if (widget.existingSablonId != null) {
        // Güncelleme işlemi buraya eklenebilir
        await _sablonService.updateSablonText(
          widget.existingSablonId!, 
          _nameController.text, 
          _selectedTur, 
          deltaJson,
          birimId: _selectedBirim?.id,
          birimAd: _selectedBirim?.ad,
        );
      } else {
        await _sablonService.addTextSablon(
          _nameController.text, 
          _selectedTur, 
          deltaJson,
          birimId: _selectedBirim?.id,
          birimAd: _selectedBirim?.ad,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şablon kaydedildi')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSablonId != null ? 'Şablon Düzenle' : 'Yeni Şablon Oluştur'),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white)))
          else
            ElevatedButton.icon(
              onPressed: _saveSablon,
              icon: const Icon(Icons.save),
              label: const Text('Kaydet'),
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.green),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Şablon Adı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedTur,
                    decoration: const InputDecoration(
                      labelText: 'Şablon Türü',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'yk_karar', child: Text('YK Karar Şablonu')),
                      DropdownMenuItem(value: 'fatura', child: Text('Fatura Şablonu')),
                      DropdownMenuItem(value: 'gundem', child: Text('Gündem Şablonu')),
                      DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTur = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<BirimModel?>(
                    value: _selectedBirim,
                    decoration: const InputDecoration(
                      labelText: 'Hangi Birim İçin?',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<BirimModel?>(
                        value: null,
                        child: Text('Tüm Birimler (Ortak)'),
                      ),
                      ..._birimler.map((birim) {
                        return DropdownMenuItem<BirimModel?>(
                          value: birim,
                          child: Text(birim.ad),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBirim = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          quill.QuillSimpleToolbar(
            controller: _controller,
            config: const quill.QuillSimpleToolbarConfig(
              showFontFamily: true,
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: true,
              showColorButton: true,
              showBackgroundColorButton: true,
              showClearFormat: true,
              showAlignmentButtons: true,
              showSearchButton: false,
            ),
          ),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ]
                ),
                child: quill.QuillEditor.basic(
                  controller: _controller,
                  config: const quill.QuillEditorConfig(
                    padding: EdgeInsets.all(24.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
