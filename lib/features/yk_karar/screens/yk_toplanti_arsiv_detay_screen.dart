import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../models/toplanti_model.dart';
import '../models/gundem_model.dart' as gundem;
import '../models/yk_karar_model.dart';
import '../services/belge_uretim_servisi.dart';
import '../services/yk_karar_service.dart';
import '../widgets/yk_karar_onizleme_panel.dart';

/// Tek bir YK toplantısının arşiv detayı: birim birim karar önizleme + indirme.
class YkToplantiArsivDetayScreen extends StatefulWidget {
  const YkToplantiArsivDetayScreen({super.key, required this.toplantiId});

  final String toplantiId;

  @override
  State<YkToplantiArsivDetayScreen> createState() =>
      _YkToplantiArsivDetayScreenState();
}

class _YkToplantiArsivDetayScreenState extends State<YkToplantiArsivDetayScreen> {
  final YkKararService _service = YkKararService();
  ToplantiModel? _toplanti;
  List<YkKararModel> _kararlar = [];
  bool _loading = true;
  String? _seciliBirimAd;
  int _seciliKararIdx = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _loading = true);
    try {
      final toplanti = await _service.toplantiGetById(widget.toplantiId);
      final kararlar = await _service.kararGetByToplanti(widget.toplantiId);
      if (mounted) {
        final gruplar = _birimGruplariFrom(kararlar);
        setState(() {
          _toplanti = toplanti;
          _kararlar = kararlar;
          _loading = false;
          if (gruplar.isNotEmpty && _seciliBirimAd == null) {
            _seciliBirimAd = gruplar.keys.first;
            _seciliKararIdx = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<YkKararModel>> _birimGruplariFrom(List<YkKararModel> kararlar) {
    final map = <String, List<YkKararModel>>{};
    for (final k in kararlar) {
      final key = k.birimAd.isNotEmpty ? k.birimAd : 'Diğer';
      map.putIfAbsent(key, () => []).add(k);
    }
    return map;
  }

  Map<String, List<YkKararModel>> get _birimGruplari => _birimGruplariFrom(_kararlar);

  String _dosyaAdiTemizle(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<void> _pdfAc(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF açılamadı.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _birimSec(String birimAd) {
    setState(() {
      _seciliBirimAd = birimAd;
      _seciliKararIdx = 0;
    });
  }

  Future<void> _guvenliCalistir(
    Future<void> Function() islem,
    String hataBaslik,
  ) async {
    try {
      await islem();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$hataBaslik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _kararlarPdfPopup({
    required String baslik,
    required List<YkKararModel> kararlar,
    required String dosyaAdi,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight * 0.95;
            final govdeH = maxH - 56;
            final a4W = govdeH / 1.4142;
            final govdeW = a4W.clamp(560.0, constraints.maxWidth * 0.94);
            return SizedBox(
              width: govdeW,
              height: maxH,
              child: Column(
                children: [
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            baslik,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (_) => BelgeUretimServisi.kararlarPdfUret(
                        kararlar,
                        belgeBasligi: baslik.toUpperCase(),
                      ),
                      allowPrinting: true,
                      allowSharing: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      maxPageWidth: govdeW - 36,
                      pdfFileName: '$dosyaAdi.pdf',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toplantı Arşivi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_toplanti == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toplantı Arşivi')),
        body: const Center(child: Text('Toplantı bulunamadı.')),
      );
    }

    final t = _toplanti!;
    final birimGruplari = _birimGruplari;
    final seciliListe = _seciliBirimAd != null ? birimGruplari[_seciliBirimAd] : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Toplantı ${t.toplantiNo}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_kararlar.isNotEmpty)
            TextButton.icon(
              onPressed: () => _guvenliCalistir(
                () => BelgeUretimServisi.topluKararWordIndir(_kararlar, t.toplantiNo),
                'Ana karar indirme hatası',
              ),
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              label: const Text('Ana Karar Word', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _infoKart(t, _kararlar.length),
          ),
          if (_kararlar.isNotEmpty || t.gundemMaddeleri.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _toplantiDosyasiKart(t, birimGruplari, seciliListe),
            ),
          if (t.pdfUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _gundemPdfSatiri(t),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _kararlar.isEmpty
                  ? const Center(
                      child: Text('Bu toplantıya kayıtlı karar yok.', style: TextStyle(color: Colors.grey)),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final genis = constraints.maxWidth >= 860;
                        if (genis) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 300,
                                child: _birimListesi(birimGruplari),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _onizlemeAlani(seciliListe)),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 140, child: _birimListesiYatay(birimGruplari)),
                            const SizedBox(height: 12),
                            Expanded(child: _onizlemeAlani(seciliListe)),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _birimListesi(Map<String, List<YkKararModel>> gruplar) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Birimler (${gruplar.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: gruplar.length,
              itemBuilder: (context, index) {
                final entry = gruplar.entries.elementAt(index);
                final secili = entry.key == _seciliBirimAd;
                return Material(
                  color: secili ? AppTheme.primaryColor.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    selected: secili,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: secili
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.business,
                        size: 18,
                        color: secili ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${entry.value.length} karar'),
                    trailing: secili ? Icon(Icons.chevron_right, color: AppTheme.primaryColor) : null,
                    onTap: () => _birimSec(entry.key),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _birimListesiYatay(Map<String, List<YkKararModel>> gruplar) {
    return Card(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: gruplar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = gruplar.entries.elementAt(index);
          final secili = entry.key == _seciliBirimAd;
          return ChoiceChip(
            label: Text(
              entry.key.length > 24 ? '${entry.key.substring(0, 24)}…' : entry.key,
              style: TextStyle(fontSize: 11, color: secili ? Colors.white : null),
            ),
            selected: secili,
            onSelected: (_) => _birimSec(entry.key),
            selectedColor: AppTheme.primaryColor,
          );
        },
      ),
    );
  }

  Widget _toplantiDosyasiKart(
    ToplantiModel t,
    Map<String, List<YkKararModel>> birimGruplari,
    List<YkKararModel>? seciliListe,
  ) {
    final seciliBirim = _seciliBirimAd ?? 'Birim';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _dosyaAksiyonGrubu(
                baslik: 'Ana Karar Defteri',
                aciklama: '${_kararlar.length} karar · tüm birimler',
                icon: Icons.menu_book_outlined,
                renk: AppTheme.primaryColor,
                onPdf: _kararlar.isEmpty
                    ? null
                    : () => _kararlarPdfPopup(
                          baslik: 'Döner Sermaye Yürütme Kurulu Kararları',
                          kararlar: _kararlar,
                          dosyaAdi: 'Toplanti_${t.toplantiNo.replaceAll('/', '_')}_Ana_Karar',
                        ),
                onWord: _kararlar.isEmpty
                    ? null
                    : () => _guvenliCalistir(
                          () => BelgeUretimServisi.topluKararWordIndir(
                            _kararlar,
                            t.toplantiNo,
                          ),
                          'Ana karar indirme hatası',
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dosyaAksiyonGrubu(
                baslik: 'Birim Kararı',
                aciklama: '$seciliBirim · ${seciliListe?.length ?? 0} karar',
                icon: Icons.account_balance_outlined,
                renk: Colors.indigo,
                onPdf: seciliListe == null || seciliListe.isEmpty
                    ? null
                    : () => _kararlarPdfPopup(
                          baslik: '$seciliBirim Yürütme Kurulu Kararları',
                          kararlar: seciliListe,
                          dosyaAdi:
                              'Toplanti_${t.toplantiNo.replaceAll('/', '_')}_${_dosyaAdiTemizle(seciliBirim)}',
                        ),
                onWord: seciliListe == null || seciliListe.isEmpty
                    ? null
                    : () => _guvenliCalistir(
                          () => BelgeUretimServisi.birimKararWordIndir(
                            seciliListe,
                            toplantiNo: t.toplantiNo,
                            birimAd: seciliBirim,
                          ),
                          'Birim karar indirme hatası',
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dosyaAksiyonGrubu(
                baslik: 'Gündem',
                aciklama: '${t.gundemMaddeleri.length} madde · ${t.pdfUrls.length} PDF',
                icon: Icons.list_alt_outlined,
                renk: Colors.orange.shade700,
                onPdf: null,
                onWord: t.gundemMaddeleri.isEmpty
                    ? null
                    : () => _guvenliCalistir(
                          () => BelgeUretimServisi.toplantiGundemWordIndir(
                            _gundemToplanti(t),
                          ),
                          'Gündem indirme hatası',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dosyaAksiyonGrubu({
    required String baslik,
    required String aciklama,
    required IconData icon,
    required Color renk,
    required VoidCallback? onPdf,
    required VoidCallback? onWord,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: renk.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: renk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  aciklama,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'A4 PDF önizle / yazdır',
            onPressed: onPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            color: Colors.red.shade700,
          ),
          IconButton(
            tooltip: 'Word indir',
            onPressed: onWord,
            icon: const Icon(Icons.download_outlined, size: 18),
            color: renk,
          ),
        ],
      ),
    );
  }

  Widget _onizlemeAlani(List<YkKararModel>? liste) {
    if (liste == null || liste.isEmpty) {
      return const Card(
        child: Center(child: Text('Önizlemek için bir birim seçin.')),
      );
    }

    final karar = liste[_seciliKararIdx.clamp(0, liste.length - 1)];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.toc, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Birim İçeriği (${liste.length} karar):',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('yk_arsiv_taslak_sec'),
                    initialValue: _seciliKararIdx.clamp(0, liste.length - 1),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: List.generate(liste.length, (i) {
                      final k = liste[i];
                      final label = k.baslik.trim().isNotEmpty ? k.baslik : 'Karar ${i + 1}';
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          '${i + 1}. $label',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _seciliKararIdx = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: YkKararOnizlemePanel(karar: karar)),
        ],
      ),
    );
  }

  Widget _gundemPdfSatiri(ToplantiModel t) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text('Gündem PDF\'leri (${t.pdfUrls.length})'),
        children: t.pdfUrls
            .asMap()
            .entries
            .map(
              (e) => ListTile(
                dense: true,
                title: Text('Gündem PDF ${e.key + 1}'),
                subtitle: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _pdfAc(e.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _infoKart(ToplantiModel t, int kararSayisi) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.groups, color: AppTheme.primaryColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yürütme Kurulu Toplantısı ${t.toplantiNo}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('Tarih: ${t.toplantiTarihi.isNotEmpty ? t.toplantiTarihi : "—"}'),
                  Text('$kararSayisi birim kararı • ${t.pdfUrls.length} gündem PDF'),
                  const SizedBox(height: 4),
                  Text(
                    'Birim seçin → metin, tablo ve PDF önizlemesi',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(t.durum.displayName),
              backgroundColor: t.durum == ToplantiDurum.tamamlandi
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
            ),
          ],
        ),
      ),
    );
  }

  gundem.ToplantiModel _gundemToplanti(ToplantiModel t) {
    return gundem.ToplantiModel(
      id: t.id,
      toplantiTarihi: t.toplantiTarihi,
      toplantiNo: t.toplantiNo,
      gundemMaddeleri: t.gundemMaddeleri
          .map(
            (m) => gundem.GundemMaddesi(
              siraNo: m.siraNo,
              baslik: m.baslik,
              tur: gundem.GundemTuru.fromString(m.tur.value),
              aciklama: m.aciklama,
              birimId: m.birimId,
              birimAd: m.birimAd,
              iliskiliKayitId: m.iliskiliKayitId,
            ),
          )
          .toList(),
      durum: gundem.ToplantiDurum.fromString(t.durum.value),
      olusturmaTarihi: t.olusturmaTarihi,
      pdfUrls: t.pdfUrls,
    );
  }
}
