import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../providers/danismanlik_detay_provider.dart';
import '../services/danismanlik_excel_hesaplama.dart';
import '../widgets/danismanlik_layout.dart';
import '../widgets/danismanlik_onizleme_dialog.dart';
import '../widgets/taksit_pipeline.dart';

class DanismanlikDagitimScreen extends StatefulWidget {
  const DanismanlikDagitimScreen({
    super.key,
    required this.danismanlik,
    this.taksit,
  });

  final DanismanlikModel danismanlik;
  final TaksitModel? taksit;

  @override
  State<DanismanlikDagitimScreen> createState() =>
      _DanismanlikDagitimScreenState();
}

class _DanismanlikDagitimScreenState extends State<DanismanlikDagitimScreen> {
  DagitimHesapSonuc? _sonuc;
  bool _hesaplaniyor = false;
  TaksitModel? _seciliTaksit;
  List<ExcelPersonelGirdi> _editableGirdiler = [];
  final _katsayiController = TextEditingController();
  bool _katsayiManuel = false;
  double? _otomatikKatsayi;
  int _sanalAySayisi = 1;
  late String _sanalTaksitId;
  final _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _sanalTaksitId = 'sanal_${DateTime.now().millisecondsSinceEpoch}';
    _seciliTaksit = widget.taksit;
    _editableGirdiler =
        DanismanlikExcelHesaplama.personelGirdileriFromDanismanlik(widget.danismanlik);
  }

  @override
  void dispose() {
    _katsayiController.dispose();
    _hScrollController.dispose();
    super.dispose();
  }

  double? _parseSayi(String raw) =>
      double.tryParse(raw.replaceAll(',', '.').trim());

  void _girdileriSenkronizeEt(DagitimHesapSonuc? sonuc) {
    if (sonuc?.excelSonuc == null) return;
    _editableGirdiler = sonuc!.excelSonuc!.personelSatirlari
        .map((s) => s.girdi)
        .toList();
    _otomatikKatsayi = sonuc.katsayi;
    if (!_katsayiManuel) {
      _katsayiController.text = TurkceFormat.katsayi(sonuc.katsayi);
    }
  }

  void _sanalAylikGuncelle(int ay, DanismanlikDetayProvider provider) {
    if (ay < 1 || ay > widget.danismanlik.suresi) return;
    setState(() {
      _sanalAySayisi = ay;
      if (_seciliTaksit?.id == _sanalTaksitId) {
        final aylik = widget.danismanlik.suresi > 0 
            ? widget.danismanlik.toplamTutar / widget.danismanlik.suresi 
            : widget.danismanlik.toplamTutar;
        _seciliTaksit = _seciliTaksit!.copyWith(
          brutTutar: aylik * ay,
          ayNo: ay,
        );
      }
    });
    _yenidenHesapla(provider);
  }

  void _yenidenHesapla(DanismanlikDetayProvider provider) {
    final taksit = _seciliTaksit;
    if (taksit == null || _editableGirdiler.isEmpty) return;

    setState(() => _hesaplaniyor = true);

    final kesinti = DanismanlikExcelHesaplama.kesintilerBrutten(
      brutTutar: taksit.brutTutar,
      kdvOrani: widget.danismanlik.kdvOrani,
      hazineOrani: widget.danismanlik.hazinePayiOrani,
      bapOrani: widget.danismanlik.bapPayiOrani,
      aracGerecOrani: widget.danismanlik.aracGerecPayiOrani / 100,
    );
    _otomatikKatsayi = DanismanlikExcelHesaplama.otomatikDonemKatsayisi(
      kesinti: kesinti,
      personeller: _editableGirdiler,
    );

    final manualKatsayi =
        _katsayiManuel ? _parseSayi(_katsayiController.text) : null;
    final sonuc = provider.hesaplaExcelFromGirdiler(
      taksit: taksit,
      personeller: _editableGirdiler,
      manualDonemKatsayi: manualKatsayi,
    );

    if (mounted) {
      setState(() {
        _sonuc = sonuc;
        _hesaplaniyor = false;
        if (!_katsayiManuel && sonuc != null) {
          _katsayiController.text = TurkceFormat.katsayi(sonuc.katsayi);
        }
      });
    }
  }

  Future<void> _hesapla(DanismanlikDetayProvider provider) async {
    final taksit = _seciliTaksit;
    if (taksit == null) return;
    if (_editableGirdiler.isEmpty) {
      _editableGirdiler =
          DanismanlikExcelHesaplama.personelGirdileriFromDanismanlik(widget.danismanlik);
    }
    setState(() => _hesaplaniyor = true);
    final sonuc = await provider.dagitimHesapla(
      taksit,
      DanismanlikDetayProvider.guncelIslemAyi(),
    );
    if (mounted) {
      setState(() {
        _sonuc = sonuc;
        _hesaplaniyor = false;
        _girdileriSenkronizeEt(sonuc);
      });
    }
  }

  void _girdiGuncelle(int index, ExcelPersonelGirdi girdi, DanismanlikDetayProvider provider) {
    setState(() {
      _editableGirdiler = List.of(_editableGirdiler)..[index] = girdi;
    });
    _yenidenHesapla(provider);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DanismanlikDetayProvider(widget.danismanlik),
      child: Builder(
        builder: (context) {
          final provider = context.watch<DanismanlikDetayProvider>();

          if (_seciliTaksit == null) {
            if (provider.taksitler.isNotEmpty) {
              _seciliTaksit = provider.taksitler.first;
              WidgetsBinding.instance.addPostFrameCallback((_) => _hesapla(provider));
            } else {
              _seciliTaksit = TaksitModel(
                id: _sanalTaksitId,
                ayNo: _sanalAySayisi,
                brutTutar: widget.danismanlik.suresi > 0 
                    ? (widget.danismanlik.toplamTutar / widget.danismanlik.suresi) * _sanalAySayisi
                    : widget.danismanlik.toplamTutar,
                durum: TaksitDurum.taslak,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) => _hesapla(provider));
            }
          } else if (_sonuc == null && !_hesaplaniyor) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _hesapla(provider));
          }

          final ddlValue = provider.taksitler.where((t) => t.id == _seciliTaksit?.id).firstOrNull;

          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: Column(
              children: [
                DanismanlikLayout.kompaktBaslik(
                  baslik: 'Excel Hesaplama',
                  altBaslik:
                      '${widget.danismanlik.firmaUnvan ?? widget.danismanlik.konusu} · Ek ödeme katsayısı',
                  aksiyon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (provider.taksitler.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DropdownButton<TaksitModel>(
                            value: ddlValue,
                            hint: const Text('Genel Önizleme'),
                            items: provider.taksitler
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text('Ay ${t.ayNo} · ${TurkceFormat.para(t.brutTutar)}'),
                                    ))
                                .toList(),
                            onChanged: (t) {
                              if (t == null) return;
                              setState(() {
                                _seciliTaksit = t;
                                _sonuc = null;
                                _katsayiManuel = false;
                              });
                              _hesapla(provider);
                            },
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
                if (_seciliTaksit != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
                    ),
                    child: Center(
                      child: TaksitPipeline(
                        durum: _seciliTaksit!.durum,
                        tur: widget.danismanlik.tur,
                        compact: false,
                      ),
                    ),
                  ),
                Expanded(
                  child: _seciliTaksit == null
                      ? Center(
                          child: Text(
                            'Dağıtım için önce detay ekranından taksit ekleyin.',
                            style: TextStyle(color: Colors.blueGrey.shade600),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return DanismanlikLayout.ikiKolon(
                              genislik: constraints.maxWidth,
                              ana: _buildAnaPanel(provider),
                              yan: _buildMaliOzet(),
                            );
                          },
                        ),
                ),
                _buildAltBar(context, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnaPanel(DanismanlikDetayProvider provider) {
    if (_hesaplaniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sonuc == null) {
      return const Center(child: Text('Hesaplama yapılamadı.'));
    }

    final excel = _sonuc!.excelSonuc;
    final d = widget.danismanlik;
    final profil = DanismanlikExcelHesaplama.profilFromDanismanlik(d);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildKatsayiCubugu(excel, provider, profil),
          TabBar(
            labelColor: Colors.indigo.shade700,
            unselectedLabelColor: Colors.blueGrey,
            indicatorWeight: 2,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Personel Dağılımı'),
              Tab(text: 'Gelir ve Kesintiler'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildKatkiPayiTab(excel, provider),
                _buildDagMaksPayTab(excel, d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKatsayiCubugu(
    DanismanlikExcelSonuc? excel,
    DanismanlikDetayProvider provider,
    DanismanlikExcelProfili profil,
  ) {
    final katkiPayi = excel?.kesinti.katkiPayi ?? 0.0;
    final saglama = excel?.saglama ?? 0.0;
    final asim = saglama > katkiPayi + 0.01;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: Colors.indigo.shade700),
              const SizedBox(width: 6),
              Text(
                'Dönem Ek Ödeme Katsayısı',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.indigo.shade800,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  profil == DanismanlikExcelProfili.usemSurekliEgitim
                      ? 'USEM Excel'
                      : 'DTS Danışmanlık',
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              if (_seciliTaksit?.id == _sanalTaksitId && widget.danismanlik.suresi > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Dağıtılan Süre: ', style: TextStyle(fontSize: 10)),
                      InkWell(
                        onTap: _sanalAySayisi > 1 ? () => _sanalAylikGuncelle(_sanalAySayisi - 1, provider) : null,
                        child: Icon(Icons.remove_circle, size: 14, color: _sanalAySayisi > 1 ? Colors.blue.shade700 : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text('$_sanalAySayisi Ay', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _sanalAySayisi < widget.danismanlik.suresi ? () => _sanalAylikGuncelle(_sanalAySayisi + 1, provider) : null,
                        child: Icon(Icons.add_circle, size: 14, color: _sanalAySayisi < widget.danismanlik.suresi ? Colors.blue.shade700 : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              if (_otomatikKatsayi != null)
                Text(
                  'Otomatik: ${TurkceFormat.katsayi(_otomatikKatsayi!)}',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                ),
            ],
          ),
          if (profil == DanismanlikExcelProfili.usemSurekliEgitim) ...[
            const SizedBox(height: 4),
            Text(
              'USEM şablonu: ek ders tavanı 0,907796 katsayısı · Liste sayfası kursiyer gelirlerini toplar.',
              style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Otomatik')),
                  ButtonSegment(value: true, label: Text('Manuel')),
                ],
                selected: {_katsayiManuel},
                onSelectionChanged: (s) {
                  setState(() {
                    _katsayiManuel = s.first;
                    if (!_katsayiManuel && _otomatikKatsayi != null) {
                      _katsayiController.text =
                          TurkceFormat.katsayi(_otomatikKatsayi!);
                    }
                  });
                },
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _katsayiController,
                  enabled: _katsayiManuel,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '19,60',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _yenidenHesapla(provider),
                ),
              ),
              FilledButton.icon(
                onPressed: _hesaplaniyor ? null : () => _yenidenHesapla(provider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Yeniden Hesapla'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (asim) ...[
            const SizedBox(height: 6),
            Text(
              'Uyarı: Sağlama (${TurkceFormat.para(saglama)}) katkı payını (${TurkceFormat.para(katkiPayi)}) aşıyor.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDagMaksPayTab(DanismanlikExcelSonuc? excel, DanismanlikModel d) {
    if (excel == null) return const SizedBox.shrink();
    final k = excel.kesinti;
    final kdv = DanismanlikExcelHesaplama.kdvTutari(k.kdvHaricGelir, d.kdvOrani);
    final genel = DanismanlikExcelHesaplama.genelToplam(k.kdvHaricGelir, d.kdvOrani);

    return ListView(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      children: [
        Text(
          '${d.birimKisaAd ?? 'Birim'} — Danışmanlık Gelir Dağıtımı',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text('HESAPLAMA TABLOSU', style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        _satir('GELİR (KDV Hariç)', TurkceFormat.para(k.kdvHaricGelir), kalin: true),
        _satir('%${d.kdvOrani} KDV', TurkceFormat.para(kdv)),
        _satir('TOPLAM TUTAR', TurkceFormat.para(genel), kalin: true),
        const SizedBox(height: 16),
        const Text('GELİRDEN AKTARILACAK PAYLAR', style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        _satir('HAZİNE PAYI (%${d.hazinePayiOrani})', TurkceFormat.para(k.hazinePayi)),
        _satir('BAP PAYI (%${d.bapPayiOrani})', TurkceFormat.para(k.bapPayi)),
        _satir('ARAÇ GEREÇ PAYI (%${d.aracGerecPayiOrani})', TurkceFormat.para(k.aracGerecPayi)),
        _satir('KATKI PAYI', TurkceFormat.para(k.katkiPayi), kalin: true, renk: Colors.green.shade700),
        _satir('TOPLAM', TurkceFormat.para(k.toplam), kalin: true),
        const Divider(),
        _satir('DAĞ. MAKS. AKADEMİK PAY (%49)', TurkceFormat.para(k.dagMaksAkademikPay)),
      ],
    );
  }

  Widget _buildKatkiPayiTab(
    DanismanlikExcelSonuc? excel,
    DanismanlikDetayProvider provider,
  ) {
    if (excel == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            'Puan, unvan katsayısı ve ders saatini düzenleyin; ardından «Yeniden Hesapla» ile katsayıyı güncelleyin.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
          ),
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
            ),
            child: Scrollbar(
              controller: _hScrollController,
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.blueGrey.shade50,
                      dataTableTheme: DataTableThemeData(
                        headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700, letterSpacing: 0.3),
                        dataTextStyle: TextStyle(fontSize: 12, color: Colors.blueGrey.shade900),
                        horizontalMargin: 16,
                        columnSpacing: 16,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey.shade100, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                  columns: [
                    const DataColumn(label: Text('Adı Soyadı')),
                    const DataColumn(label: Text('Puanı')),
                    const DataColumn(label: Text('Unvan Kats.')),
                    const DataColumn(label: Text('Ders Saati')),
                    const DataColumn(label: Text('Bireysel Net\nKatkı Puanı')),
                    const DataColumn(label: Text('Dönem Katsayı')),
                    if (DanismanlikExcelHesaplama.profilFromDanismanlik(widget.danismanlik) == DanismanlikExcelProfili.usemSurekliEgitim) ...[
                      const DataColumn(label: Text('Kurs 1 Saatlik')),
                      const DataColumn(label: Text('Tavan Saatlik')),
                    ],
                    const DataColumn(label: Text('Brüt Hakediş')),
                    const DataColumn(label: Text('Net Ödenen')),
                  ],
                rows: [
                  ...List.generate(_editableGirdiler.length, (i) {
                    final p = _editableGirdiler[i];
                    ExcelPersonelSonuc? s;
                    for (final x in excel.personelSatirlari) {
                      if (x.girdi.personelId == p.personelId) {
                        s = x;
                        break;
                      }
                    }
                    return DataRow(cells: [
                      DataCell(Text(
                        '${p.unvan} ${p.adSoyad}',
                        style: const TextStyle(fontSize: 12),
                      )),
                      DataCell(_EditableSayiHucre(
                        key: ValueKey('puan-${p.personelId}'),
                        deger: p.puan.toStringAsFixed(0),
                        onChanged: (v) => _girdiGuncelle(i, p.copyWith(puan: v), provider),
                        onDone: () => _yenidenHesapla(provider),
                      )),
                      DataCell(_EditableSayiHucre(
                        key: ValueKey('uk-${p.personelId}'),
                        deger: p.unvanKatsayisi.toStringAsFixed(1),
                        onChanged: (v) =>
                            _girdiGuncelle(i, p.copyWith(unvanKatsayisi: v), provider),
                        onDone: () => _yenidenHesapla(provider),
                        width: 56,
                      )),
                      DataCell(_EditableSayiHucre(
                        key: ValueKey('ds-${p.personelId}'),
                        deger: p.dersSaati.toStringAsFixed(0),
                        onChanged: (v) =>
                            _girdiGuncelle(i, p.copyWith(dersSaati: v), provider),
                        onDone: () => _yenidenHesapla(provider),
                      )),
                      DataCell(Text(
                        (s?.bireyselNetKatkiPuani ?? 0).toStringAsFixed(0),
                      )),
                      DataCell(Text(TurkceFormat.katsayi(s?.donemKatsayi ?? 0))),
                      if (DanismanlikExcelHesaplama.profilFromDanismanlik(widget.danismanlik) == DanismanlikExcelProfili.usemSurekliEgitim) ...[
                        DataCell(Text(TurkceFormat.para(s?.kursSaatlikUcreti ?? 0))),
                        DataCell(Text(TurkceFormat.para(s?.tavanSaatlikUcreti ?? 0))),
                      ],
                      DataCell(Text(TurkceFormat.para(s?.brutHakedis ?? 0), style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(TurkceFormat.para(s?.odenebilirHakedis ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800))),
                    ]);
                  }),
                  DataRow(cells: [
                    const DataCell(Text(
                      'TOPLAM PUAN',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    DataCell(Text(
                      excel.toplamPuan.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(TurkceFormat.katsayi(excel.donemKatsayi))),
                    if (DanismanlikExcelHesaplama.profilFromDanismanlik(widget.danismanlik) == DanismanlikExcelProfili.usemSurekliEgitim) ...[
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                    ],
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
],
    );
  }

  Widget _buildMaliOzet() {
    if (_sonuc == null) return const SizedBox.shrink();

    final excel = _sonuc!.excelSonuc;
    final k = _sonuc!.kesinti;
    
    final double totalBrut = widget.taksit?.brutTutar ?? k.kdvHaricMatrah;
    final double kdv = k.kdvHaricMatrah > 0 ? (totalBrut - k.kdvHaricMatrah) : 0;
    final double kesintiler = k.hazinePayi + k.bapPayi + k.aracGerecPayi;
    final double dagitilabilir = k.dagitilabilirTutar;

    return Container(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: DanismanlikLayout.kart(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DanismanlikLayout.kartBaslik('Dönem Özeti', icon: Icons.pie_chart_outline),
          const SizedBox(height: 16),
          
          // Görsel Bütçe Dağılımı (Altın Oran ve İnce Çizgiler)
          if (totalBrut > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(flex: (dagitilabilir * 100).toInt(), child: Container(height: 6, color: Colors.green.shade500)),
                  Expanded(flex: (kesintiler * 100).toInt(), child: Container(height: 6, color: Colors.orange.shade400)),
                  Expanded(flex: (kdv * 100).toInt(), child: Container(height: 6, color: Colors.red.shade400)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendItem('Dağıtılabilir', Colors.green.shade500),
                _LegendItem('Kurum Payı', Colors.orange.shade400),
                _LegendItem('KDV', Colors.red.shade400),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],

          if (excel != null) ...[
            _ozetSatir('Toplam Puan', excel.toplamPuan.toStringAsFixed(0)),
            _ozetSatir('Ek Ödeme Katsayısı', TurkceFormat.katsayi(excel.donemKatsayi), kalin: true),
            _ozetSatir('Sağlama', TurkceFormat.para(excel.saglama)),
            _ozetSatir('Artık Bakiye', TurkceFormat.para(excel.artikBakiye)),
          ] else ...[
            _ozetSatir('Matrah', TurkceFormat.para(k.kdvHaricMatrah)),
            _ozetSatir('Dağıtılabilir', TurkceFormat.para(k.dagitilabilirTutar), kalin: true),
          ],
          const Divider(height: 16),
          _ozetSatir('Net Ödenen', TurkceFormat.para(
            excel?.netOdemeToplam ??
                _sonuc!.dagitimlar.fold<double>(
                  0,
                  (s, p) => s + (p.odenebilirHakedis ?? p.brutHakedis),
                ),
          ), renk: Colors.green.shade700),
          const Spacer(),
          if (_sonuc!.kararMetni.isNotEmpty) ...[
            DanismanlikLayout.kartBaslik('Karar Metni'),
            const SizedBox(height: 6),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Text(
                    _sonuc!.kararMetni,
                    style: TextStyle(fontSize: 11, height: 1.4, color: Colors.blueGrey.shade700),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _LegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
      ],
    );
  }

  Widget _buildAltBar(BuildContext context, DanismanlikDetayProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.blueGrey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(onPressed: () => context.pop(), child: const Text('Kapat')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _sonuc == null
                ? null
                : () => showDanismanlikOnizlemeDialog(
                      context,
                      danismanlik: widget.danismanlik,
                      sonuc: _sonuc!,
                      taksit: _seciliTaksit,
                    ),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Önizleme'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _seciliTaksit == null || provider.isLoading || _sonuc == null
                ? null
                : () async {
                    await provider.dagitimiKaydetSonuc(
                      _seciliTaksit!,
                      DanismanlikDetayProvider.guncelIslemAyi(),
                      _sonuc!,
                      false,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Taslak kaydedildi')),
                      );
                    }
                  },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Taslak Kaydet'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _seciliTaksit == null ||
                    provider.isLoading ||
                    _sonuc == null ||
                    _seciliTaksit!.durum == TaksitDurum.ykOnaylandi
                ? null
                : () async {
                    await provider.dagitimiKaydetSonuc(
                      _seciliTaksit!,
                      DanismanlikDetayProvider.guncelIslemAyi(),
                      _sonuc!,
                      true,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Onaylandı ve YK arşivine gönderildi')),
                      );
                      context.pop();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Onayla & YK Arşivi'),
          ),
        ],
      ),
    );
  }

  Widget _satir(String etiket, String deger, {bool kalin = false, Color? renk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600)),
          Text(
            deger,
            style: TextStyle(
              fontSize: kalin ? 14 : 13,
              fontWeight: kalin ? FontWeight.w700 : FontWeight.w500,
              color: renk ?? Colors.blueGrey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ozetSatir(String etiket, String deger, {bool kalin = false, Color? renk}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiket, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500)),
          Text(
            deger,
            style: TextStyle(
              fontSize: kalin ? 15 : 13,
              fontWeight: kalin ? FontWeight.w700 : FontWeight.w600,
              color: renk ?? Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableSayiHucre extends StatefulWidget {
  const _EditableSayiHucre({
    super.key,
    required this.deger,
    required this.onChanged,
    this.onDone,
    this.width = 48,
  });

  final String deger;
  final ValueChanged<double> onChanged;
  final VoidCallback? onDone;
  final double width;

  @override
  State<_EditableSayiHucre> createState() => _EditableSayiHucreState();
}

class _EditableSayiHucreState extends State<_EditableSayiHucre> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.deger);
  }

  @override
  void didUpdateWidget(covariant _EditableSayiHucre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deger != widget.deger && _ctrl.text != widget.deger) {
      _ctrl.text = widget.deger;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 12),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (raw) {
          final v = double.tryParse(raw.replaceAll(',', '.').trim());
          if (v != null) widget.onChanged(v);
          widget.onDone?.call();
        },
      ),
    );
  }
}
