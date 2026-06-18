import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fatura_matbu_config.dart';
import '../providers/batch_fatura_provider.dart';

class FaturaCalibrationDialog extends StatefulWidget {
  const FaturaCalibrationDialog({super.key});

  @override
  State<FaturaCalibrationDialog> createState() => _FaturaCalibrationDialogState();
}

class _FaturaCalibrationDialogState extends State<FaturaCalibrationDialog> {
  bool _ornekMetinGoster = true;
  String? _seciliAlan;
  bool _alanSurukleniyor = false;

  Iterable<MapEntry<String, Offset>> _gorunurAlanlar(BatchFaturaProvider p) {
    return p.coordinates.entries.where((e) {
      if (!p.isNakliYekunAktif && e.key.startsWith('nakliYekun')) return false;
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.96,
        height: MediaQuery.of(context).size.height * 0.94,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 280, child: _buildSidePanel()),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: context.read<BatchFaturaProvider>(),
                      builder: (_, __) => _buildCanvas(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = context.read<BatchFaturaProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.print_outlined, color: Color(0xFF2C3E50)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matbu Fatura Kalibrasyonu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Soldan alan seçin veya form üzerinde sürükleyin. Önce «Tüm alanları kaydır» ile hızlı hizalayın.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Switch(
            value: _ornekMetinGoster,
            onChanged: (v) => setState(() => _ornekMetinGoster = v),
          ),
          const Text('Örnek metin', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Test Baskı'),
            onPressed: () async {
              await provider.matbuYazdir(provider.ornekFatura());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Test baskı gönderildi. Matbu kağıdı yazıcıya takın; ölçek %100 olmalı.',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Kaydet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await provider.saveMatbuAyarlari();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kalibrasyon kaydedildi.'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            tooltip: 'Varsayılanlara dön',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              await provider.resetCoordinates();
              if (context.mounted) {
                setState(() => _seciliAlan = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Varsayılan koordinatlar yüklendi.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Selector<BatchFaturaProvider, _SidePanelData>(
      selector: (_, p) => _SidePanelData(
        fontBoyutu: p.matbuFontBoyutu,
        satirAraligi: p.kalemSatirAraligi,
        globalDx: p.globalOffsetDx,
        globalDy: p.globalOffsetDy,
        nakliAktif: p.isNakliYekunAktif,
        coordinates: Map.from(p.coordinates),
      ),
      builder: (context, data, _) {
        final provider = context.read<BatchFaturaProvider>();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'İpucu: Önce alttaki X/Y kaydırıcılarıyla tüm formu hizalayın. '
                'Sonra tek tek alan seçip ok tuşlarıyla ince ayar yapın.',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            Text('Font boyutu: ${data.fontBoyutu.toStringAsFixed(0)} pt'),
            Slider(
              value: data.fontBoyutu,
              min: 8,
              max: 14,
              divisions: 6,
              onChanged: provider.setMatbuFontBoyutu,
            ),
            Text('Kalem satır aralığı: ${data.satirAraligi.toStringAsFixed(0)} pt'),
            Slider(
              value: data.satirAraligi,
              min: 14,
              max: 24,
              divisions: 10,
              onChanged: provider.setKalemSatirAraligi,
            ),
            const Divider(height: 24),
            const Text('Tüm alanları kaydır', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'X: ${data.globalDx.toStringAsFixed(0)}  Y: ${data.globalDy.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12),
            ),
            Slider(
              value: data.globalDx,
              min: -30,
              max: 30,
              divisions: 60,
              onChanged: (v) => provider.setGlobalOffset(v, data.globalDy),
            ),
            Slider(
              value: data.globalDy,
              min: -30,
              max: 30,
              divisions: 60,
              onChanged: (v) => provider.setGlobalOffset(data.globalDx, v),
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nakli yekün alanları', style: TextStyle(fontSize: 13)),
              value: data.nakliAktif,
              onChanged: provider.toggleNakliYekunGlobal,
            ),
            if (_seciliAlan != null) ...[
              const Divider(height: 16),
              Text(
                'Seçili: ${FaturaMatbuConfig.alanEtiketleri[_seciliAlan] ?? _seciliAlan}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _nudgePad(context, _seciliAlan!),
            ],
            const SizedBox(height: 8),
            const Text('Alan listesi (dokunun)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ..._gorunurAlanlar(provider).map((e) {
              final secili = _seciliAlan == e.key;
              return Material(
                color: secili ? Colors.blue.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _seciliAlan = e.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      '${FaturaMatbuConfig.alanEtiketleri[e.key] ?? e.key}: '
                      '${e.value.dx.toStringAsFixed(0)}, ${e.value.dy.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                        color: secili ? Colors.blue.shade900 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _nudgePad(BuildContext context, String key) {
    final provider = context.read<BatchFaturaProvider>();
    Widget btn(IconData icon, VoidCallback onTap) => SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: Icon(icon),
            onPressed: onTap,
          ),
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_up, () => provider.nudgeCoordinate(key, 0, -1)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_left, () => provider.nudgeCoordinate(key, -1, 0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('±1 pt', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ),
            btn(Icons.keyboard_arrow_right, () => provider.nudgeCoordinate(key, 1, 0)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_down, () => provider.nudgeCoordinate(key, 0, 1)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => provider.nudgeCoordinate(key, 0, -5),
              child: const Text('↑5', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => provider.nudgeCoordinate(key, -5, 0),
              child: const Text('←5', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => provider.nudgeCoordinate(key, 5, 0),
              child: const Text('5→', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => provider.nudgeCoordinate(key, 0, 5),
              child: const Text('↓5', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    final provider = context.read<BatchFaturaProvider>();
    final data = _CanvasData(
      coordinates: Map.from(provider.coordinates),
      globalDx: provider.globalOffsetDx,
      globalDy: provider.globalOffsetDy,
      fontBoyutu: provider.matbuFontBoyutu,
      satirAraligi: provider.kalemSatirAraligi,
      nakliAktif: provider.isNakliYekunAktif,
    );

    return Container(
          color: Colors.grey.shade200,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(40),
            minScale: 0.6,
            maxScale: 1.4,
            panEnabled: !_alanSurukleniyor,
            scaleEnabled: !_alanSurukleniyor,
            child: Container(
              width: FaturaMatbuConfig.a4Genislik,
              height: FaturaMatbuConfig.a4Yukseklik,
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RepaintBoundary(
                    child: Image.asset(
                      'assets/images/fatura_sablon.jpeg',
                      fit: BoxFit.fill,
                      width: FaturaMatbuConfig.a4Genislik,
                      height: FaturaMatbuConfig.a4Yukseklik,
                      cacheWidth: FaturaMatbuConfig.a4Genislik.round(),
                    ),
                  ),
                  ...data.coordinates.entries.where((entry) {
                    if (!data.nakliAktif && entry.key.startsWith('nakliYekun')) {
                      return false;
                    }
                    return true;
                  }).map((entry) {
                    final konum = Offset(
                      entry.value.dx + data.globalDx,
                      entry.value.dy + data.globalDy,
                    );
                    final etiket =
                        FaturaMatbuConfig.alanEtiketleri[entry.key] ?? entry.key;
                    final metin = _ornekMetinGoster
                        ? (FaturaMatbuConfig.ornekMetinler[entry.key] ?? etiket)
                        : etiket;
                    final secili = _seciliAlan == entry.key;

                    return Positioned(
                      left: konum.dx,
                      top: konum.dy,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => setState(() => _seciliAlan = entry.key),
                        onPanStart: (_) {
                          setState(() {
                            _alanSurukleniyor = true;
                            _seciliAlan = entry.key;
                          });
                        },
                        onPanUpdate: (details) {
                          provider.updateCoordinateDelta(
                            entry.key,
                            details.delta,
                            notify: false,
                          );
                          setState(() {});
                        },
                        onPanEnd: (_) {
                          setState(() => _alanSurukleniyor = false);
                          provider.calibrationUiRefresh();
                        },
                        onPanCancel: () {
                          setState(() => _alanSurukleniyor = false);
                          provider.calibrationUiRefresh();
                        },
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          decoration: secili || !_ornekMetinGoster
                              ? BoxDecoration(
                                  color: secili
                                      ? Colors.blue.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.92),
                                  border: Border.all(
                                    color: secili ? Colors.blue : Colors.red,
                                    width: secili ? 2 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                )
                              : null,
                          child: Text(
                            metin,
                            style: TextStyle(
                              fontSize: data.fontBoyutu,
                              fontWeight: entry.key == 'firmaAdi' ||
                                      entry.key == 'genelToplam'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _ornekMetinGoster
                                  ? Colors.black
                                  : Colors.red.shade700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_ornekMetinGoster) ..._kalemSatirOnizlemleri(data),
                ],
              ),
            ),
          ),
        );
  }

  /// Kalem sütunlarında 2–4. satırların nereye düşeceğini gösterir.
  List<Widget> _kalemSatirOnizlemleri(_CanvasData data) {
    const kalemAlanlari = {'cinsi', 'miktar', 'fiyat', 'tutar'};
    final widgets = <Widget>[];
    final seciliKalemAlani =
        _seciliAlan != null && kalemAlanlari.contains(_seciliAlan)
        ? _seciliAlan
        : null;
    for (final key in kalemAlanlari) {
      if (seciliKalemAlani != null && key != seciliKalemAlani) continue;
      final base = data.coordinates[key];
      if (base == null) continue;
      final konum = Offset(base.dx + data.globalDx, base.dy + data.globalDy);
      final etiket = FaturaMatbuConfig.alanEtiketleri[key] ?? key;
      for (var satir = 1; satir < 4; satir++) {
        widgets.add(
          Positioned(
            left: konum.dx,
            top: konum.dy + satir * data.satirAraligi,
            child: Text(
              '$etiket — satır ${satir + 1}',
              style: TextStyle(
                fontSize: data.fontBoyutu,
                color: Colors.blueGrey.withValues(alpha: 0.55),
                height: 1.1,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _SidePanelData {
  const _SidePanelData({
    required this.fontBoyutu,
    required this.satirAraligi,
    required this.globalDx,
    required this.globalDy,
    required this.nakliAktif,
    required this.coordinates,
  });

  final double fontBoyutu;
  final double satirAraligi;
  final double globalDx;
  final double globalDy;
  final bool nakliAktif;
  final Map<String, Offset> coordinates;

  @override
  bool operator ==(Object other) =>
      other is _SidePanelData &&
      fontBoyutu == other.fontBoyutu &&
      satirAraligi == other.satirAraligi &&
      globalDx == other.globalDx &&
      globalDy == other.globalDy &&
      nakliAktif == other.nakliAktif &&
      _mapEquals(coordinates, other.coordinates);

  @override
  int get hashCode => Object.hash(
        fontBoyutu,
        satirAraligi,
        globalDx,
        globalDy,
        nakliAktif,
        Object.hashAll(coordinates.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

class _CanvasData {
  const _CanvasData({
    required this.coordinates,
    required this.globalDx,
    required this.globalDy,
    required this.fontBoyutu,
    required this.satirAraligi,
    required this.nakliAktif,
  });

  final Map<String, Offset> coordinates;
  final double globalDx;
  final double globalDy;
  final double fontBoyutu;
  final double satirAraligi;
  final bool nakliAktif;

  @override
  bool operator ==(Object other) =>
      other is _CanvasData &&
      globalDx == other.globalDx &&
      globalDy == other.globalDy &&
      fontBoyutu == other.fontBoyutu &&
      satirAraligi == other.satirAraligi &&
      nakliAktif == other.nakliAktif &&
      _mapEquals(coordinates, other.coordinates);

  @override
  int get hashCode => Object.hash(
        globalDx,
        globalDy,
        fontBoyutu,
        satirAraligi,
        nakliAktif,
        Object.hashAll(coordinates.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

bool _mapEquals(Map<String, Offset> a, Map<String, Offset> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
