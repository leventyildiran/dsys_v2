import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../providers/batch_fatura_provider.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_matbu_baski_onizleme.dart';
import '../models/fatura_matbu_kalibrasyon.dart';
import '../../../core/turkce_format.dart';

class VisualEntryScreen extends StatefulWidget {
  final int invoiceIndex;

  const VisualEntryScreen({super.key, required this.invoiceIndex});

  @override
  State<VisualEntryScreen> createState() => _VisualEntryScreenState();
}

class _VisualEntryScreenState extends State<VisualEntryScreen> {
  String? _seciliAlan;
  bool _arkaPlanGoster = true;

  /// Tutamaç sürüklemesi sırasında sayfa kaydırmasını geçici olarak kapatır.
  bool _surukleAktif = false;
  
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<BatchFaturaProvider>();
      final birimId = provider.seciliBirimFor(widget.invoiceIndex);
      provider.loadMatbuAyarlari(birimId);
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    if (widget.invoiceIndex < 0 || widget.invoiceIndex >= provider.pendingInvoices.length) {
      return const Scaffold(body: Center(child: Text('Fatura bulunamadı')));
    }

    final invoice = provider.pendingInvoices[widget.invoiceIndex];
    
    final sayfaHesabi = _hesaplaSayfalar(provider, invoice);
    final pagesOfIndices = sayfaHesabi['pages'] as List<List<int>>;
    final toplamSayfa = pagesOfIndices.length;
    
    provider.currentIndex = widget.invoiceIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text('Görsel Fatura Modu (A4) - $toplamSayfa Sayfa'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Switch(
                value: _arkaPlanGoster,
                activeThumbColor: Colors.blueAccent,
                onChanged: (v) => setState(() => _arkaPlanGoster = v),
              ),
              const Text('Arka Plan', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 8),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.print, color: Colors.white),
            label: const Text('Yazdır', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Printing.layoutPdf(
                onLayout: (format) => provider.generatePdf(
                  invoice,
                  includeBackground: false, // Arka plan yazıcıya GİTMEZ
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.restore, color: Colors.orangeAccent),
            label: const Text('Sıfırla', style: TextStyle(color: Colors.orangeAccent)),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Standart A4 Şablonuna Sıfırla'),
                  content: const Text(
                    'Tüm alan koordinatları ve hizalamalar orijinal standart A4 matbu şablonuna sıfırlansın mı?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      child: const Text('Sıfırla'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final provider = context.read<BatchFaturaProvider>();
                provider.varsayilanaSifirla();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Koordinatlar standart A4 şablonuna sıfırlandı.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            label: const Text('Kaydet', style: TextStyle(color: Colors.greenAccent)),
            onPressed: () async {
              final provider = context.read<BatchFaturaProvider>();
              await provider.saveMatbuAyarlari();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kalibrasyon kaydedildi.'), backgroundColor: Colors.green),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Yeni Kalem', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final provider = context.read<BatchFaturaProvider>();
              provider.addKalem(widget.invoiceIndex);
            },
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.note_add, color: Colors.white),
            label: const Text('Not Ekle', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final provider = context.read<BatchFaturaProvider>();
              provider.addEkstraNot(widget.invoiceIndex);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      backgroundColor: Colors.grey.shade300,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: _buildSidePanel(provider),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: _surukleAktif ? const NeverScrollableScrollPhysics() : null,
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: _surukleAktif ? const NeverScrollableScrollPhysics() : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                      child: Column(
                        children: List.generate(toplamSayfa, (sayfaIndex) {
                          final pageIndices = pagesOfIndices[sayfaIndex];
                          final pageOnizleme = provider.kalibrasyonBaskiOnizlemesi(sayfaIndex + 1);

                          return _HandleOverflowHitTest(
                            overflowPadding: 150.0,
                            child: Container(
                              width: FaturaMatbuConfig.a4Genislik,
                              height: FaturaMatbuConfig.a4Yukseklik,
                              margin: const EdgeInsets.only(bottom: 40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // A4 Arkaplan
                                if (_arkaPlanGoster)
                                  Positioned.fill(
                                    child: Image.asset(
                                      'assets/images/fatura_sablon.jpeg',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                      
                      // Sabit alanlar ilk sayfadaysa veya genel bilgiler
                      ..._buildSabitAlanlar(
                        provider,
                        invoice,
                        pageOnizleme,
                        sonSayfa: sayfaIndex == toplamSayfa - 1,
                        sayfaIndex: sayfaIndex,
                        toplamSayfa: toplamSayfa,
                      ),
                      
                      // Ekstra notlar yalnızca son sayfada
                      if (sayfaIndex == toplamSayfa - 1)
                        ..._buildEkstraNotlar(provider, invoice),

                      // Kalemler
                      ..._buildKalemler(provider, invoice, pageOnizleme, pageIndices),
                    ],
                  ),
                ),
              );
            }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSabitAlanlar(
    BatchFaturaProvider provider,
    var invoice,
    KalibrasyonBaskiOnizleme onizleme, {
    required bool sonSayfa,
    required int sayfaIndex,
    required int toplamSayfa,
  }) {
    final w = <Widget>[];
    
    // Düzenlenebilir alanlar: key -> (value, updateFieldKey, maxWidth, maxLines)
    final editables = {
      'firmaAdi': (invoice.firmaAdi, 'firmaAdi', 270.0, 2),
      'adres': (invoice.adres, 'adres', 270.0, 3),
      'vergiDairesi': (invoice.vergiDairesi, 'vergiDairesi', 150.0, 1),
      'vkn': (invoice.vergiNo, 'vergiNo', 150.0, 1),
      'tarih': (invoice.tarih, 'tarih', 100.0, 1),
      'irsaliyeTarihi': (invoice.irsaliyeTarihi, 'irsaliyeTarihi', 100.0, 1),
      'irsaliyeNo': (invoice.irsaliyeNo, 'irsaliyeNo', 100.0, 1),
      'iban': (onizleme.alanlar['iban'] ?? invoice.iban ?? '', 'iban', 280.0, 1),
      'hesapAdi': (onizleme.alanlar['hesapAdi'] ?? invoice.hesapAdi ?? '', 'hesapAdi', 280.0, 2),
      'numuneAciklama': (onizleme.alanlar['numuneAciklama'] ?? '', 'numuneAciklamasi', 250.0, 2),
      'melbesKurum': (
        onizleme.alanlar['melbesKurum'] ?? invoice.melbesKurumOnEki,
        'melbesKurumOnEki',
        250.0,
        2,
      ),
      'melbes': (onizleme.alanlar['melbes'] ?? '', 'melbesNo', 200.0, 1),
      'numuneNo': (onizleme.alanlar['numuneNo'] ?? '', 'numuneNo', 160.0, 1),
    };

    if (invoice.nakliYekunAktif) {
      if (sayfaIndex > 0) {
        editables['nakliYekunUstYazi'] = (onizleme.alanlar['nakliYekunUstYazi']?.isNotEmpty == true ? onizleme.alanlar['nakliYekunUstYazi']! : provider.nakliYekunUstMetin, 'GLOBAL_nakliYekunUstMetin', 255.0, 1);
      }
      if (sayfaIndex < toplamSayfa - 1) {
        editables['nakliYekunAltYazi'] = (onizleme.alanlar['nakliYekunAltYazi']?.isNotEmpty == true ? onizleme.alanlar['nakliYekunAltYazi']! : provider.nakliYekunAltMetin, 'GLOBAL_nakliYekunAltMetin', 255.0, 1);
      }
    }

    editables.forEach((key, data) {
      if (!provider.coordinates.containsKey(key) ||
          FaturaMatbuKalibrasyon.gizliAlanlar.contains(key)) {
        return;
      }
      if (FaturaMatbuConfig.altBolgeAlanMi(key) && !sonSayfa) return;
      
      final val = data.$1 as String;
      if ((key == 'melbes' || key == 'numuneNo') && val.trim().isEmpty) {
        return;
      }
      final updateKey = data.$2;
      final maxW = data.$3;
      final lines = data.$4;
      
      final offset = _konum(provider, key);
      
      w.add(Positioned(
        left: offset.dx,
        top: offset.dy,
        child: _editableField(
          provider,
          key,
          val,
          (v) {
            if (updateKey == 'GLOBAL_nakliYekunUstMetin') {
               provider.nakliYekunUstMetin = v;
            } else if (updateKey == 'GLOBAL_nakliYekunAltMetin') {
               provider.nakliYekunAltMetin = v;
            } else {
               provider.updateField(widget.invoiceIndex, updateKey, v);
            }
          },
          provider.matbuFontBoyutu,
          maxWidth: maxW,
          maxLines: lines,
          hint: FaturaMatbuConfig.alanEtiketleri[key] ?? key,
        ),
      ));
    });

    // Sadece Okunur Alanlar (Hesaplananlar)
    final readOnly = <String, dynamic>{
      'matrah': onizleme.alanlar['matrah'],
      'genelToplam': onizleme.alanlar['genelToplam'],
      'yaziylaTutar': onizleme.alanlar['yaziylaTutar'],
    };

    readOnly['kdv'] = onizleme.alanlar['kdv'];
    readOnly['kdvOrani'] = onizleme.alanlar['kdvOrani'];

    if (invoice.nakliYekunAktif) {
      if (sayfaIndex > 0) {
        readOnly['nakliYekunUstTutar'] = onizleme.alanlar['nakliYekunUstTutar'];
      }
      if (sayfaIndex < toplamSayfa - 1) {
        readOnly['nakliYekunAltTutar'] = onizleme.alanlar['nakliYekunAltTutar'];
      }
    }

    readOnly.forEach((key, val) {
      if (FaturaMatbuConfig.altBolgeAlanMi(key) && !sonSayfa) {
        if (key != 'kdv' || !invoice.isKdvMuaf) {
          return;
        }
      }

      String? finalVal = val;

      if (finalVal == null || finalVal.isEmpty || !provider.coordinates.containsKey(key)) return;
      final offset = _konum(provider, key);
      Offset adjustedOffset = offset;
      final isBold = key.toLowerCase().contains('toplam') || key.toLowerCase().contains('yekun');

      // Alan genişliği ve metin hizalaması (PDF baskısıyla birebir aynı)
      double maxW;
      TextAlign textAlignment = TextAlign.left;
      if (key == 'yaziylaTutar') {
        maxW = 420;
      } else if (key == 'numuneAciklama') {
        maxW = 220;
      } else if (key == 'melbesKurum') {
        maxW = 245;
      } else if (key == 'melbes' || key == 'numuneNo') {
        maxW = key == 'melbes' ? 155 : 140;
      } else if (key == 'kdvOrani') {
        maxW = 40;
        textAlignment = TextAlign.right;
      } else if (key == 'matrah' || key == 'kdv' || key == 'genelToplam' || key.contains('Tutar')) {
        maxW = 80;
        textAlignment = TextAlign.right;
      } else {
        maxW = 150;
      }
      
      w.add(Positioned(
        left: adjustedOffset.dx,
        top: adjustedOffset.dy,
        child: _suruklenebilirAlan(
                provider: provider,
                alanKey: key,
                child: _metinKutusu(
                  metin: finalVal,
                  fontBoyutu: provider.matbuFontBoyutu,
                  secili: _seciliAlan == key,
                  maxWidth: maxW,
                  textAlign: textAlignment,
                  kalin: isBold,
                ),
              ),
      ));
    }); // readOnly.forEach sonu

    return w;
  }

  List<Widget> _buildEkstraNotlar(BatchFaturaProvider provider, var invoice) {
    final w = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (!provider.coordinates.containsKey('ekstraNot_$i')) continue;
      final offset = _konum(provider, 'ekstraNot_$i');
      
      if (i >= invoice.ekstraNotlar.length) continue;
      
      final val = i < invoice.ekstraNotlar.length ? invoice.ekstraNotlar[i] : '';
      
      w.add(Positioned(
        left: offset.dx,
        top: offset.dy,
        child: _editableField(
          provider,
          'ekstraNot_$i',
          val.isEmpty ? FaturaMatbuConfig.ornekMetinler['ekstraNot_$i']! : val,
          (v) {
              provider.updateEkstraNot(widget.invoiceIndex, i, v);
          },
          provider.matbuFontBoyutu,
          maxWidth: 200,
          maxLines: 2,
          hint: 'Özel Not $i',
        ),
      ));
    }
    return w;
  }

  /// Her sayfanın kalem index listesi + nakli yekün tutarlarını hesaplar.
  /// Nakli Yekün satırları kalem index listesine girmez; üst/alt tutar metinleri
  /// KalibrasyonBaskiOnizleme'nin 'nakliYekunUstTutar' / 'nakliYekunAltTutar' alanlarından gelir.
  /// Döndürülen Map: 'pages' → `List<List<int>>`, 'nakliTutarlar' → `List<double>` (her sayfa sonundaki kümülatif)
  Map<String, dynamic> _hesaplaSayfalar(BatchFaturaProvider provider, var invoice) {
    final kalemler = invoice.kalemler;
    final satirLimit = 9999;
    final isGercekList = kalemler.map((k) => FaturaMatbuConfig.matbuKalemleri([k]).isNotEmpty).toList();
    final gercekKalemler = FaturaMatbuConfig.matbuKalemleri(kalemler);

    final List<List<int>> pagesOfIndices = [];
    final List<double> nakliTutarlar = []; // Her sayfa sonundaki kümülatif toplam
    int currentItemIndex = 0;
    int currentGercekIndex = 0;
    double runningTotal = 0.0;
    
    while (currentGercekIndex < gercekKalemler.length || pagesOfIndices.isEmpty) {
      int spaceLeft = satirLimit;
      final List<int> currentPageIndices = [];
      
      if (pagesOfIndices.isNotEmpty && invoice.nakliYekunAktif) {
        spaceLeft--;
      }

      int itemsRemaining = gercekKalemler.length - currentGercekIndex;
      bool willHaveNextPage = false;
      if (invoice.nakliYekunAktif && itemsRemaining > spaceLeft) {
          willHaveNextPage = true;
      }
      
      int effectiveSpace = willHaveNextPage ? spaceLeft - 1 : spaceLeft;

      double pageTotal = 0.0;
      while (effectiveSpace > 0 && currentItemIndex < kalemler.length) {
        currentPageIndices.add(currentItemIndex);
        if (isGercekList[currentItemIndex]) {
          final m = TurkceFormat.parseSayi(kalemler[currentItemIndex]['miktar'], fallback: 1.0);
          final f = TurkceFormat.parseSayi(kalemler[currentItemIndex]['fiyat'], fallback: 0.0);
          pageTotal += (m * f);
          currentGercekIndex++;
        }
        
        effectiveSpace--;
        spaceLeft--;

        final bool bolunmeIstendi = kalemler[currentItemIndex]['sayfayiBol'] == true;
        currentItemIndex++;
        
        if (bolunmeIstendi && currentGercekIndex < gercekKalemler.length) {
          willHaveNextPage = true;
          break;
        }
      }
      
      runningTotal += pageTotal;
      
      if (willHaveNextPage) {
        spaceLeft--;
      }
      
      pagesOfIndices.add(currentPageIndices);
      nakliTutarlar.add(runningTotal);
    }
    
    while (currentItemIndex < kalemler.length) {
       if (pagesOfIndices.isNotEmpty) {
           pagesOfIndices.last.add(currentItemIndex);
           // Son sayfadaki ek kalemleri de toplama ekle
           if (isGercekList[currentItemIndex]) {
             final m = TurkceFormat.parseSayi(kalemler[currentItemIndex]['miktar'], fallback: 1.0);
             final f = TurkceFormat.parseSayi(kalemler[currentItemIndex]['fiyat'], fallback: 0.0);
             nakliTutarlar[nakliTutarlar.length - 1] += (m * f);
           }
       }
       currentItemIndex++;
    }

    return {
      'pages': pagesOfIndices,
      'nakliTutarlar': nakliTutarlar,
    };
  }

  List<Widget> _buildKalemler(BatchFaturaProvider provider, var invoice, KalibrasyonBaskiOnizleme onizleme, List<int> pageIndices) {
    final w = <Widget>[];
    final kalemler = invoice.kalemler;
    if (kalemler.isEmpty) return w;

    final cinsiBase = provider.coordinates['cinsi'];
    if (cinsiBase == null) return w;

    int renderIndex = 0;
    
    for (int i in pageIndices) {
      final satirDy = renderIndex * provider.kalemSatirAraligi;
      final satirTop = cinsiBase.dy + provider.globalOffsetDy + satirDy;
      renderIndex++;
      
      final satirMap = kalemler[i];

      // Cinsi
      if (provider.coordinates.containsKey('cinsi')) {
          w.add(Positioned(
            left: provider.coordinates['cinsi']!.dx + provider.globalOffsetDx,
            top: satirTop,
           child: _editableField(
             provider,
             'cinsi',
             satirMap['cinsi']?.toString() ?? '',
             (v) => provider.updateKalem(widget.invoiceIndex, i, 'cinsi', v),
             provider.matbuFontBoyutu,
             maxWidth: 255,
             maxLines: 1,
           ),
         ));
      }

      // Miktar
      if (provider.coordinates.containsKey('miktar')) {
          w.add(Positioned(
            left: provider.coordinates['miktar']!.dx + provider.globalOffsetDx,
            top: satirTop,
           child: _editableField(
             provider,
             'miktar',
             satirMap['miktar']?.toString() ?? '',
             (v) => provider.updateKalem(widget.invoiceIndex, i, 'miktar', TurkceFormat.parseSayi(v, fallback: 0)),
             provider.matbuFontBoyutu,
             maxWidth: 50,
             maxLines: 1,
             textAlign: TextAlign.center,
           ),
         ));
      }

      // Fiyat
      if (provider.coordinates.containsKey('fiyat')) {
          w.add(Positioned(
            left: provider.coordinates['fiyat']!.dx + provider.globalOffsetDx,
            top: satirTop,
           child: _editableField(
             provider,
             'fiyat',
             satirMap['fiyat']?.toString() ?? '',
             (v) => provider.updateKalem(widget.invoiceIndex, i, 'fiyat', v),
             provider.matbuFontBoyutu,
             maxWidth: 70,
             maxLines: 1,
             textAlign: TextAlign.right,
           ),
         ));
      }

       // Tutar (Okunur)
      if (provider.coordinates.containsKey('tutar')) {
         final m = TurkceFormat.parseSayi(satirMap['miktar'], fallback: 1.0);
         final f = TurkceFormat.parseSayi(satirMap['fiyat'], fallback: 0.0);
         final t = m * f;
         
         final metin = t > 0 ? TurkceFormat.paraKalem(t) : '';
         w.add(Positioned(
           left: provider.coordinates['tutar']!.dx + provider.globalOffsetDx,
           top: satirTop,
           child: _suruklenebilirAlan(
                   provider: provider,
                   alanKey: 'tutar',
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       _metinKutusu(
                         metin: metin.isEmpty ? 'Tutar' : metin,
                         fontBoyutu: provider.matbuFontBoyutu,
                         secili: _seciliAlan == 'tutar',
                         maxWidth: 70,
                         textAlign: TextAlign.right,
                       ),
                       const SizedBox(width: 4),
                       InkWell(
                         onTap: () async {
                           final bool? confirm = await showDialog<bool>(
                             context: context,
                             builder: (context) => AlertDialog(
                               title: const Text('Emin misiniz?'),
                               content: const Text('Bu kalemi silmek istediğinize emin misiniz?'),
                               actions: [
                                 TextButton(
                                   onPressed: () => Navigator.pop(context, false),
                                   child: const Text('İptal'),
                                 ),
                                 TextButton(
                                   onPressed: () => Navigator.pop(context, true),
                                   style: TextButton.styleFrom(foregroundColor: Colors.red),
                                   child: const Text('Sil'),
                                 ),
                               ],
                             ),
                           );
                           if (confirm == true) {
                             provider.removeKalem(widget.invoiceIndex, i);
                             setState(() {});
                           }
                         },
                         child: const Icon(Icons.close, color: Colors.red, size: 16),
                       ),
                     ],
                   ),
                 ),
         ));
      }
    }
    return w;
  }

  Offset _konum(BatchFaturaProvider provider, String key) {
    final base = provider.coordinates[key] ?? Offset.zero;
    return Offset(base.dx + provider.globalOffsetDx, base.dy + provider.globalOffsetDy);
  }

  Widget _editableField(
    BatchFaturaProvider provider,
    String key,
    String initialValue,
    Function(String) onChanged,
    double fontSize, {
    required double maxWidth,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
    String? hint,
  }) {
    return _suruklenebilirAlan(
      provider: provider,
      alanKey: key,
      child: _MatbuEditableField(
        initialValue: initialValue,
        onChanged: onChanged,
        fontSize: fontSize,
        maxWidth: maxWidth,
        maxLines: maxLines,
        textAlign: textAlign,
        hint: hint,
        onFocus: () => setState(() => _seciliAlan = key),
      ),
    );
  }

  Widget _metinKutusu({
    required String metin,
    required double fontBoyutu,
    required bool secili,
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
    bool tekSatir = false,
    bool kalin = false,
  }) {
    return Container(
      width: maxWidth,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: secili ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(
          color: secili ? Colors.blue : Colors.red.withValues(alpha: 0.35),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        metin,
        textAlign: textAlign,
        maxLines: tekSatir ? 1 : null,
        overflow: tekSatir ? TextOverflow.clip : null,
        strutStyle: StrutStyle(
          fontSize: fontBoyutu,
          height: 1.0,
          forceStrutHeight: true,
        ),
        style: TextStyle(
          fontSize: fontBoyutu,
          fontWeight: kalin ? FontWeight.bold : FontWeight.normal,
          color: Colors.red.shade900,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildSidePanel(BatchFaturaProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Hizalama Ayarları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        Text('Font boyutu: ${provider.matbuFontBoyutu.toStringAsFixed(0)} pt', style: const TextStyle(fontSize: 12)),
        Slider(
          value: provider.matbuFontBoyutu,
          min: 8, max: 14, divisions: 6,
          onChanged: provider.setMatbuFontBoyutu,
        ),
        Text('Satır aralığı: ${provider.kalemSatirAraligi.toStringAsFixed(0)} pt', style: const TextStyle(fontSize: 12)),
        Slider(
          value: provider.kalemSatirAraligi,
          min: 14, max: 24, divisions: 10,
          onChanged: provider.setKalemSatirAraligi,
        ),
        Text('Tüm alanları kaydır', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text('X: ${provider.globalOffsetDx.toStringAsFixed(0)}  Y: ${provider.globalOffsetDy.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
        Slider(
          value: provider.globalOffsetDx,
          min: -30, max: 30, divisions: 60,
          onChanged: (v) => provider.setGlobalOffset(v, provider.globalOffsetDy),
        ),
        Slider(
          value: provider.globalOffsetDy,
          min: -30, max: 30, divisions: 60,
          onChanged: (v) => provider.setGlobalOffset(provider.globalOffsetDx, v),
        ),
        const Divider(),
        if (_seciliAlan != null) ...[
          Text('Seçili: ${FaturaMatbuConfig.alanEtiketleri[_seciliAlan] ?? _seciliAlan}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
          const SizedBox(height: 8),
          _nudgePad(provider, _seciliAlan!),
        ] else ...[
          const Text('İnce ayar için kağıt üzerinden bir alana tıklayın.', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ],
    );
  }

  Widget _nudgePad(BatchFaturaProvider provider, String key) {
    Widget btn(IconData icon, VoidCallback onTap) => SizedBox(
          width: 36, height: 36,
          child: IconButton(padding: EdgeInsets.zero, iconSize: 20, icon: Icon(icon), onPressed: onTap),
        );
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [btn(Icons.keyboard_arrow_up, () => provider.nudgeCoordinate(key, 0, -1))]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_left, () => provider.nudgeCoordinate(key, -1, 0)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('±1 pt', style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
            btn(Icons.keyboard_arrow_right, () => provider.nudgeCoordinate(key, 1, 0)),
          ],
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [btn(Icons.keyboard_arrow_down, () => provider.nudgeCoordinate(key, 0, 1))]),
      ],
    );
  }

  Widget _suruklenebilirAlan({
    required BatchFaturaProvider provider,
    required String alanKey,
    required Widget child,
  }) {
    final secili = _seciliAlan == alanKey;
    
    final handle = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        setState(() {
          _surukleAktif = true;
          _seciliAlan = alanKey;
        });
      },
      onPanUpdate: (details) {
        provider.calibrationDragDelta(alanKey, details.delta, notify: false);
        setState(() {});
      },
      onPanEnd: (_) {
        _surukleBitir(provider);
      },
      onPanCancel: () {
        _surukleBitir(provider);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: secili ? Colors.blue.shade700 : Colors.blueAccent.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: const Icon(Icons.open_with, size: 12, color: Colors.white),
          ),
        ),
      ),
    );

    // Tüm alanlar (salt-okunur ve düzenlenebilir) gövdeden sürüklenebilir:
    // hızlı dokunuş = düzenle/seç, sürükleme = taşı.
    final fieldBox = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() => _seciliAlan = alanKey);
      },
      onPanStart: (_) {
        setState(() {
          _surukleAktif = true;
          _seciliAlan = alanKey;
        });
      },
      onPanUpdate: (details) {
        provider.calibrationDragDelta(alanKey, details.delta, notify: false);
        setState(() {});
      },
      onPanEnd: (_) {
        _surukleBitir(provider);
      },
      onPanCancel: () {
        _surukleBitir(provider);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          decoration: BoxDecoration(
            border: secili
                ? Border.all(color: Colors.blue.shade700, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: child,
        ),
      ),
    );

    return _HandleOverflowHitTest(
      overflowPadding: 35.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          fieldBox,
          Positioned(
            left: -24,
            top: -2,
            child: handle,
          ),
        ],
      ),
    );
  }

  void _surukleBitir(BatchFaturaProvider provider) {
    setState(() {
      _surukleAktif = false;
    });
    provider.calibrationUiRefresh();
  }
}

class _MatbuEditableField extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;
  final double fontSize;
  final double maxWidth;
  final int maxLines;
  final TextAlign textAlign;
  final String? hint;

  /// Alan düzenlemeye geçtiğinde (seçildiğinde) üst katmanı bilgilendirir.
  final VoidCallback? onFocus;

  const _MatbuEditableField({
    required this.initialValue,
    required this.onChanged,
    required this.fontSize,
    required this.maxWidth,
    this.maxLines = 1,
    this.textAlign = TextAlign.left,
    this.hint,
    this.onFocus,
  });

  @override
  _MatbuEditableFieldState createState() => _MatbuEditableFieldState();
}

class _MatbuEditableFieldState extends State<_MatbuEditableField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _duzenleniyor = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_focusDegisti);
  }

  void _focusDegisti() {
    if (!_focusNode.hasFocus && _duzenleniyor) {
      setState(() => _duzenleniyor = false);
    }
  }

  @override
  void didUpdateWidget(_MatbuEditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusDegisti);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _duzenlemeyeGec() {
    setState(() => _duzenleniyor = true);
    widget.onFocus?.call();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.05),
      border: Border(
        bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1),
      ),
    );

    // Düzenleme modu: gerçek metin girişi.
    if (_duzenleniyor) {
      return Container(
        width: widget.maxWidth,
        decoration: decoration,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          onChanged: widget.onChanged,
          onTapOutside: (_) => _focusNode.unfocus(),
          maxLines: widget.maxLines,
          textAlign: widget.textAlign,
          style: TextStyle(
            fontSize: widget.fontSize,
            height: 1.1,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: widget.fontSize, color: Colors.grey),
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      );
    }

    // Düzenleme dışı: metin sade bir Text olarak gösterilir. Böylece iç
    // gesture tanıyıcıları (metin seçimi sürüklemesi) ile çakışma olmaz ve
    // gövde sürüklemesi üst katmandaki pan tanıyıcısına temiz şekilde geçer.
    // Dokunuş → düzenleme, sürükleme → taşıma.
    final metin = widget.initialValue.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _duzenlemeyeGec,
      child: Container(
        width: widget.maxWidth,
        decoration: decoration,
        child: Text(
          metin.isEmpty ? (widget.hint ?? '') : widget.initialValue,
          maxLines: widget.maxLines,
          textAlign: widget.textAlign,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: widget.fontSize,
            height: 1.1,
            color: metin.isEmpty ? Colors.grey : Colors.black,
          ),
        ),
      ),
    );
  }
}

/// A4 kağıdının kenarındaki veya kutuların solundaki taşan tutamaçların
/// Flutter hit-test mekanizması tarafından yutulmasını önler ve tıklanabilir/sürüklenebilir kılar.
class _HandleOverflowHitTest extends SingleChildRenderObjectWidget {
  final double overflowPadding;
  const _HandleOverflowHitTest({
    super.key,
    required Widget child,
    this.overflowPadding = 40.0,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHandleOverflow(overflowPadding: overflowPadding);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderHandleOverflow renderObject) {
    renderObject.overflowPadding = overflowPadding;
  }
}

class _RenderHandleOverflow extends RenderProxyBox {
  double overflowPadding;
  _RenderHandleOverflow({this.overflowPadding = 40.0});

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hitRect = Rect.fromLTWH(
      -overflowPadding,
      -overflowPadding,
      size.width + (overflowPadding * 2),
      size.height + (overflowPadding * 2),
    );
    if (!hitRect.contains(position)) return false;

    // ÖNEMLİ: `child.hitTest(position)` çocuk Stack'in KENDİ boyut kutusunu
    // (0,0 → size) kontrol eder ve kutunun dışına taşan mavi sürükleme
    // tutamacını (left: -24) yutar. Bu yüzden Stack'in boyut kontrolünü
    // atlayıp doğrudan alt çocuklarını hit-test ediyoruz; böylece tutamaç
    // tam üzerine tıklandığı noktada yakalanır ve tüm alanlar (salt-okunur
    // olmayanlar dahil) sürüklenebilir.
    final RenderBox? child = this.child;
    if (child != null) {
      // ignore: invalid_use_of_protected_member
      if (child.hitTestChildren(result, position: position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    if (hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

