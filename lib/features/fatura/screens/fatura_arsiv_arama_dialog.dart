import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/turkce_format.dart';
import '../models/fatura_arsiv_util.dart';
import '../providers/batch_fatura_provider.dart';
import 'visual_entry_screen.dart';

/// Geçici fatura arşivinde tarih ve içeriğe göre arama paneli.
Future<void> showFaturaArsivAramaDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _FaturaArsivAramaDialog(),
  );
}

class _FaturaArsivAramaDialog extends StatefulWidget {
  const _FaturaArsivAramaDialog();

  @override
  State<_FaturaArsivAramaDialog> createState() => _FaturaArsivAramaDialogState();
}

class _FaturaArsivAramaDialogState extends State<_FaturaArsivAramaDialog> {
  final _metinCtrl = TextEditingController();
  final _baslangicCtrl = TextEditingController();
  final _bitisCtrl = TextEditingController();

  int? _seciliYil;
  List<FaturaArsivKayit> _sonuclar = [];
  Map<int, int> _yilSayilari = {};
  bool _yukleniyor = false;
  bool _ozetYuklendi = false;
  bool _aramaYapildi = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ozetYukle());
  }

  Future<void> _ozetYukle() async {
    setState(() => _yukleniyor = true);
    try {
      final provider = context.read<BatchFaturaProvider>();
      await provider.yukleArsivDurumu();
      if (!mounted) return;
      setState(() {
        _yilSayilari = provider.arsivYilSayilari;
        _ozetYuklendi = true;
      });
      // Arşiv açılır açılmaz en son faturaları anında getir
      await _ara();
    } catch (e) {
      if (mounted) setState(() { _hata = '$e'; _yukleniyor = false; });
    }
  }

  Future<void> _ara() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _aramaYapildi = true;
    });

    try {
      final filtre = FaturaArsivAramaFiltre(
        yil: _seciliYil,
        baslangicTarihi: FaturaArsivUtil.tarihParse(_baslangicCtrl.text),
        bitisTarihi: FaturaArsivUtil.tarihParse(_bitisCtrl.text),
        metin: _metinCtrl.text,
      );
      final liste = await context.read<BatchFaturaProvider>().araArsiv(filtre);
      if (!mounted) return;
      setState(() {
        _sonuclar = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (mounted) setState(() { _hata = '$e'; _yukleniyor = false; });
    }
  }

  @override
  void dispose() {
    _metinCtrl.dispose();
    _baslangicCtrl.dispose();
    _bitisCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    final suAn = FaturaArsivUtil.suAnkiYil();
    final yillar = _yilSayilari.keys.toList()..sort((a, b) => b.compareTo(a));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 720,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fatura Arşivi Ara', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          'Onaylanmış geçici kayıtlar — ihtiyaç olunca arayın',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      try {
                        if (v == 'zip') {
                          final adet = await provider.indirEskiArsivZip();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$adet fatura ZIP indirildi.'), backgroundColor: Colors.green),
                            );
                          }
                        } else if (v.startsWith('csv_')) {
                          final yil = int.parse(v.split('_').last);
                          await provider.indirYilArsiviCsv(yil);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$yil CSV indirildi.'), backgroundColor: Colors.green),
                            );
                          }
                        } else if (v.startsWith('json_')) {
                          final yil = int.parse(v.split('_').last);
                          await provider.indirYilArsiviJson(yil);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$yil JSON indirildi.'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      if (_seciliYil != null && _yilSayilari.containsKey(_seciliYil))
                        PopupMenuItem(
                          value: 'csv_$_seciliYil',
                          child: Text('$_seciliYil yılı CSV indir'),
                        ),
                      if (_seciliYil != null && _yilSayilari.containsKey(_seciliYil))
                        PopupMenuItem(
                          value: 'json_$_seciliYil',
                          child: Text('$_seciliYil yılı JSON indir'),
                        ),
                      if ((provider.arsivUyarisi?.toplamEskiKayit ?? 0) > 0)
                        const PopupMenuItem(
                          value: 'zip',
                          child: ListTile(
                            leading: Icon(Icons.download),
                            title: Text('Eski yılları ZIP indir'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _metinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Firma, MELBES, numune, vergi no…',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _ara(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(
                        labelText: 'Yıl',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      initialValue: _seciliYil,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tümü')),
                        ...yillar.map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
                      ],
                      onChanged: (v) => setState(() => _seciliYil = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _baslangicCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Başlangıç (gg.aa.yyyy)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bitisCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bitiş (gg.aa.yyyy)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _yukleniyor ? null : _ara,
                    icon: _yukleniyor
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 18),
                    label: const Text('Ara'),
                  ),
                ],
              ),
            ),
            if (_ozetYuklendi && _yilSayilari.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  '$suAn yılı: ${provider.mevcutYilArsivSayisi} kayıt'
                  '${_yilSayilari.length > 1 ? ' • Toplam ${_yilSayilari.values.fold(0, (a, b) => a + b)} kayıt' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_hata!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSonucListesi(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSonucListesi() {
    if (!_aramaYapildi && !_yukleniyor) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Arama kriterlerini girip Ara\'ya basın',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_yukleniyor && _sonuclar.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sonuclar.isEmpty) {
      return const Center(child: Text('Eşleşen fatura bulunamadı.'));
    }

    final provider = context.read<BatchFaturaProvider>();

    return ListView.separated(
      itemCount: _sonuclar.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final k = _sonuclar[i];
        final f = k.fatura;
        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: const Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
            ),
            title: Text(
              f.firmaAdi.isEmpty ? 'İsimsiz firma' : f.firmaAdi,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${f.tarih.isNotEmpty ? f.tarih : "—"} • ${TurkceFormat.para(f.genelToplam)}'
              '${f.numuneNo.isNotEmpty ? " • Numune: ${f.numuneNo}" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            trailing: Chip(
              label: Text('${k.kayitYili}', style: const TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    _satir('Vergi/TC No', f.vergiNo),
                    _satir('Adres', f.adres),
                    _satir('Vergi Dairesi', f.vergiDairesi),
                    _satir('MELBES No', f.melbesNo),
                    _satir('Numune No', f.numuneNo),
                    _satir('Açıklama', f.numuneAciklamasi),
                    _satir('IBAN', f.iban ?? ''),
                    _satir('Hesap Adı', f.hesapAdi ?? ''),
                    _satir('Matrah', TurkceFormat.para(f.matrah)),
                    _satir('KDV', '${f.kdvOrani.toStringAsFixed(0)}% (${TurkceFormat.para(f.kdvTutari)})'),
                    _satir('Genel Toplam', TurkceFormat.para(f.genelToplam)),
                    if (f.kalemler.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Kalemler (${f.kalemler.length}):',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      ...f.kalemler.map(
                        (km) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 2),
                          child: Text(
                            '• ${km['cinsi'] ?? km['aciklama'] ?? km['hizmetAdi'] ?? 'Kalem'} — ${km['miktar'] ?? 1} Adet x ${TurkceFormat.para((km['fiyat'] as num?)?.toDouble() ?? 0)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Eylem Butonları (Yazdır, Kuyruğa Al & Düzenle, Görsel Mod)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Yazdır (Matbu)'),
                          onPressed: () {
                            Printing.layoutPdf(
                              onLayout: (format) => provider.generatePdf(
                                f,
                                includeBackground: !provider.matbuBaskiModu,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.aspect_ratio, size: 16),
                          label: const Text('Görsel Mod'),
                          onPressed: () {
                            var idx = provider.pendingInvoices.indexWhere((p) => p.id == f.id);
                            if (idx == -1) {
                              provider.pendingInvoices.insert(0, f);
                              provider.notifyListeners();
                              idx = 0;
                            }
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisualEntryScreen(invoiceIndex: idx),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Kuyruğa Al / Düzenle'),
                          onPressed: () {
                            final exists = provider.pendingInvoices.any((p) => p.id == f.id);
                            if (!exists) {
                              provider.pendingInvoices.insert(0, f);
                              provider.notifyListeners();
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${f.firmaAdi.isNotEmpty ? f.firmaAdi : "Fatura"} ana ekrana yüklendi, düzenleyebilir ve tekrar kaydedebilirsiniz.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _satir(String etiket, String deger) {
    if (deger.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(etiket, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
          Expanded(child: Text(deger, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
