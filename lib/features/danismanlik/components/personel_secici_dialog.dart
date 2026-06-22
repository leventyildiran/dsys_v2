import 'package:flutter/material.dart';

import '../../personel/models/personel_model.dart';
import '../../personel/services/personel_service.dart';
import '../../birim/models/birim_model.dart';
import '../../birim/services/birim_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';

class PersonelSeciciDialog extends StatefulWidget {
  const PersonelSeciciDialog({
    super.key,
    this.varsayilanBirimId = '',
    this.varsayilanBirimAd = '',
  });

  final String varsayilanBirimId;
  final String varsayilanBirimAd;

  @override
  State<PersonelSeciciDialog> createState() => _PersonelSeciciDialogState();
}

class _PersonelSeciciDialogState extends State<PersonelSeciciDialog> {
  final PersonelService _service = PersonelService();
  final _formKey = GlobalKey<FormState>();
  final _aramaController = TextEditingController();
  final _adSoyadController = TextEditingController();
  final _unvanController = TextEditingController();
  final _tcController = TextEditingController();
  final _ibanController = TextEditingController();
  final _katsayiController = TextEditingController(text: '1');
  late final TextEditingController _birimController;

  List<PersonelModel> _personeller = [];
  bool _loading = true;
  bool _saving = false;
  bool _yeniFormAcik = false;

  List<BirimModel>? _birimler;
  Map<String, double> _unvanlar = {};
  String? _seciliUnvan;

  @override
  void initState() {
    super.initState();
    _birimController = TextEditingController(
      text: widget.varsayilanBirimId.isNotEmpty
          ? widget.varsayilanBirimId
          : widget.varsayilanBirimAd,
    );
    _loadPersoneller();
    _loadBirimler();
    _loadUnvanlar();
  }

  Future<void> _loadUnvanlar() async {
    final srv = SistemAyarlariService();
    final ayarlar = await srv.getAyarlar();
    if (!mounted) return;
    setState(() {
      _unvanlar = ayarlar.unvanKatsayilari;
    });
  }

  Future<void> _loadBirimler() async {
    final srv = BirimService();
    final list = await srv.getAll(onlyActive: true);
    if (!mounted) return;
    setState(() {
      _birimler = list;
    });
  }

  @override
  void dispose() {
    _aramaController.dispose();
    _adSoyadController.dispose();
    _unvanController.dispose();
    _tcController.dispose();
    _ibanController.dispose();
    _katsayiController.dispose();
    _birimController.dispose();
    super.dispose();
  }

  Future<void> _loadPersoneller() async {
    setState(() => _loading = true);
    final list = await _service.getAll();
    if (!mounted) return;
    setState(() {
      _personeller = list;
      _loading = false;
    });
  }

  List<PersonelModel> get _filteredPersoneller {
    final query = _aramaController.text.trim().toLowerCase();
    if (query.isEmpty) return _personeller;
    return _personeller.where((p) {
      return p.adSoyad.toLowerCase().contains(query) ||
          p.unvan.toLowerCase().contains(query) ||
          p.tcKimlikNo.contains(query);
    }).toList();
  }

  Future<void> _yeniPersonelKaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final katsayi =
          double.tryParse(_katsayiController.text.replaceAll(',', '.')) ?? 1.0;
      final yeni = PersonelModel(
        id: '',
        tcKimlikNo: _tcController.text.trim(),
        adSoyad: _adSoyadController.text.trim(),
        unvan: _unvanController.text.trim(),
        unvanKatsayisi: katsayi,
        birimId: _birimController.text.trim(),
        iban: _ibanController.text.trim(),
      );
      final kayitli = await _service.add(yeni);
      if (!mounted) return;
      Navigator.pop(context, kayitli);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Personel kaydedilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 760,
        height: 640,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Personel Seç veya Yeni Personel Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildPersonelListesi()),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 330, child: _buildYeniPersonelFormu()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonelListesi() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _aramaController,
            decoration: const InputDecoration(
              labelText: 'Personel ara',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPersoneller.isEmpty
                ? const Center(child: Text('Kayıtlı personel bulunamadı.'))
                : ListView.separated(
                    itemCount: _filteredPersoneller.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _filteredPersoneller[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text('${p.unvan} ${p.adSoyad}'),
                        subtitle: Text(
                          [
                            if (p.birimId.isNotEmpty) p.birimId,
                            if (p.tcKimlikNo.isNotEmpty) p.tcKimlikNo,
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildYeniPersonelFormu() {
    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _yeniFormAcik = !_yeniFormAcik),
                icon: Icon(
                  _yeniFormAcik ? Icons.expand_less : Icons.person_add,
                ),
                label: const Text('Yeni Personel Kaydet'),
              ),
              if (_yeniFormAcik) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _adSoyadController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _seciliUnvan,
                  decoration: const InputDecoration(
                    labelText: 'Unvan',
                    border: OutlineInputBorder(),
                  ),
                  items: _unvanlar.keys.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(u),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _seciliUnvan = val;
                        _unvanController.text = val;
                        _katsayiController.text = _unvanlar[val]!.toStringAsFixed(1);
                      });
                    }
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tcController,
                  decoration: const InputDecoration(
                    labelText: 'TC Kimlik No',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ibanController,
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _katsayiController,
                  decoration: const InputDecoration(
                    labelText: 'Unvan Katsayısı',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse(
                      (v ?? '').replaceAll(',', '.'),
                    );
                    if (parsed == null || parsed <= 0) {
                      return 'Geçerli katsayı girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _birimler == null
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _birimler!.any((b) => b.id == _birimController.text)
                            ? _birimController.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(),
                        ),
                        items: _birimler!.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text(b.kisaAd),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _birimController.text = val;
                          }
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Zorunlu' : null,
                      ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _yeniPersonelKaydet,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet ve Ekle'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
