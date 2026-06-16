import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../models/yk_karar_model.dart';
import '../services/belge_uretim_servisi.dart';

/// YK kararını metin + tablo + PDF önizleme ile gösterir.
class YkKararOnizlemePanel extends StatefulWidget {
  const YkKararOnizlemePanel({
    super.key,
    required this.karar,
    this.compact = false,
  });

  final YkKararModel karar;
  final bool compact;

  @override
  State<YkKararOnizlemePanel> createState() => _YkKararOnizlemePanelState();
}

class _YkKararOnizlemePanelState extends State<YkKararOnizlemePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _indiriliyor = false;
  bool _pdfPopupAcik = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_tabDegisimiDinle);
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabDegisimiDinle);
    _tabController.dispose();
    super.dispose();
  }

  void _tabDegisimiDinle() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index != 1 || _pdfPopupAcik) return;
    _pdfPopupAcik = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _pdfPopupAc(widget.karar);
      if (mounted) {
        _tabController.animateTo(0);
      }
      _pdfPopupAcik = false;
    });
  }

  Future<void> _guvenliIndir(
    Future<void> Function() islem,
    String basari,
  ) async {
    setState(() => _indiriliyor = true);
    try {
      await islem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(basari), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _indiriliyor = false);
    }
  }

  Future<void> _pdfPopupAc(YkKararModel karar) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight * 0.95;
            // A4 oranı: 1 : 1.414 (portrait)
            final govdeH = maxH - 60;
            final a4W = govdeH / 1.4142;
            final govdeW = a4W.clamp(560.0, constraints.maxWidth * 0.94);
            return SizedBox(
              width: govdeW,
              height: maxH,
              child: Column(
                children: [
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            karar.baslik.isNotEmpty
                                ? karar.baslik
                                : karar.birimAd,
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
                      build: (_) => BelgeUretimServisi.kararPdfUret(karar),
                      allowSharing: true,
                      allowPrinting: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      maxPageWidth: govdeW - 36,
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

  bool _danismanlikOlusturulabilir(YkKararModel karar) {
    return karar.tur == YkKararTuru.danismanlik ||
        karar.tur == YkKararTuru.danismanlikGorevlendirme ||
        karar.tur == YkKararTuru.sanayiIsbirligi;
  }

  Widget _pdfTab(YkKararModel karar, double height) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_full, size: 40, color: Colors.blueGrey.shade500),
            const SizedBox(height: 12),
            const Text(
              'PDF önizleme A4 popup ekranda açılır.',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sekmeye tıklayınca otomatik açılır. İsterseniz aşağıdaki butondan da açabilirsiniz.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('yk_pdf_popup_ac_tab'),
              onPressed: () => _pdfPopupAc(karar),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('A4 PDF Popup Aç'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final karar = widget.karar;
    final metin = BelgeUretimServisi.kararDuzMetin(karar);
    final tablo = BelgeUretimServisi.kararTabloVerisi(karar);
    final pdfYukseklik = widget.compact ? 420.0 : 560.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                karar.baslik.isNotEmpty ? karar.baslik : karar.birimAd,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (karar.kararNo.isNotEmpty) karar.kararNo,
                  if (karar.kararTarihi.isNotEmpty) karar.kararTarihi,
                  karar.birimAd,
                ].join(' • '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(
                text: 'Metin & Tablo',
                icon: Icon(Icons.article_outlined, size: 18),
              ),
              Tab(
                text: 'PDF Önizleme',
                icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_metinTab(metin, tablo), _pdfTab(karar, pdfYukseklik)],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              if (_indiriliyor)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              const Spacer(),
              if (_danismanlikOlusturulabilir(karar)) ...[
                FilledButton.icon(
                  onPressed: _indiriliyor
                      ? null
                      : () => context.push('/danismanlik/yeni', extra: karar),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Danışmanlık Oluştur'),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: _indiriliyor
                    ? null
                    : () => _guvenliIndir(
                        () => BelgeUretimServisi.kararWordIndir(karar),
                        'Word indirildi',
                      ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Word'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('yk_pdf_popup_ac'),
                onPressed: _indiriliyor ? null : () => _pdfPopupAc(karar),
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('PDF Popup'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _indiriliyor
                    ? null
                    : () => _guvenliIndir(
                        () => BelgeUretimServisi.kararPdfIndir(karar),
                        'PDF indirildi',
                      ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('PDF İndir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metinTab(
    String metin,
    ({List<String> headers, List<List<String>> rows})? tablo,
  ) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                metin.isNotEmpty ? metin : 'Karar metni yok.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  fontFamily: 'Times New Roman',
                ),
              ),
            ),
            if (tablo != null && tablo.rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Cetvel / Tablo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(
                      Colors.blue.shade50,
                    ),
                    columns: tablo.headers
                        .map(
                          (h) => DataColumn(
                            label: Text(
                              h,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    rows: tablo.rows
                        .map(
                          (row) => DataRow(
                            cells: List.generate(
                              tablo.headers.length,
                              (i) => DataCell(
                                Text(
                                  i < row.length ? row[i] : '',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tam ekran karar önizleme diyaloğu.
Future<void> ykKararOnizlemeGoster(BuildContext context, YkKararModel karar) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 900,
        height: 720,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              AppBar(
                title: Text(
                  karar.birimAd,
                  style: const TextStyle(fontSize: 15),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(child: YkKararOnizlemePanel(karar: karar)),
            ],
          ),
        ),
      ),
    ),
  );
}
