import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../providers/batch_fatura_provider.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_matbu_baski_onizleme.dart';
import '../models/fatura_matbu_kalibrasyon.dart';
import '../../../core/turkce_format.dart';

class VisualEntryScreen extends StatefulWidget {
  final int invoiceIndex;

  const VisualEntryScreen({Key? key, required this.invoiceIndex}) : super(key: key);

  @override
  State<VisualEntryScreen> createState() => _VisualEntryScreenState();
}

class _VisualEntryScreenState extends State<VisualEntryScreen> {
  bool _kalibrasyonModu = false;
  String? _seciliAlan;
  bool _alanSurukleniyor = false;
  bool _arkaPlanGoster = true;
  
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalScrollController.hasClients) {
        _horizontalScrollController.jumpTo(260.0); // A4 kağıdını sola yaklaştırmak için boşluğu atla
      }
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
    final nakliTutarlar = sayfaHesabi['nakliTutarlar'] as List<double>;
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
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => _arkaPlanGoster = v),
              ),
              const Text('Arka Plan', style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 8),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _kalibrasyonModu,
                activeColor: Colors.amberAccent,
                onChanged: (v) => setState(() {
                  _kalibrasyonModu = v;
                  if (!v) _seciliAlan = null;
                }),
              ),
              const Text('Kalibrasyon', style: TextStyle(color: Colors.white, fontSize: 13)),
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
          if (_kalibrasyonModu)
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
          if (_kalibrasyonModu)
            SizedBox(
              width: 250,
              child: _buildSidePanel(provider),
            ),
          if (_kalibrasyonModu) const VerticalDivider(width: 1),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 40, right: 40, left: 10),
                      child: Column(
                        children: List.generate(toplamSayfa, (sayfaIndex) {
                          final pageIndices = pagesOfIndices[sayfaIndex];
                          final pageOnizleme = provider.kalibrasyonBaskiOnizlemesi(sayfaIndex + 1);
                          // Nakli yekün tutarı: bu sayfanın sonundaki kümülatif
                          // Sayfa 2+ üst nakli yekünü için önceki sayfanın tutarı kullanılır
                          final nakliTutar = sayfaIndex > 0 
                              ? nakliTutarlar[sayfaIndex - 1]  // Önceki sayfadan gelen tutar (üst nakli yekün)
                              : (nakliTutarlar.isNotEmpty ? nakliTutarlar[sayfaIndex] : 0.0); // İlk sayfanın alt nakli yekünü
                          
                          return Container(
                  width: FaturaMatbuConfig.a4Genislik + 600,
                  height: FaturaMatbuConfig.a4Yukseklik + 400,
                  margin: const EdgeInsets.only(bottom: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // A4 Arkaplan
                      Positioned(
                        left: 300,
                        top: 200,
                        child: Container(
                          width: FaturaMatbuConfig.a4Genislik,
                          height: FaturaMatbuConfig.a4Yukseklik,
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
                          child: Visibility(
                            visible: _arkaPlanGoster,
                            child: Image.asset(
                              'assets/images/fatura_sablon.jpeg',
                              fit: BoxFit.fill,
                            ),
                          ),
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
                      ..._buildKalemler(provider, invoice, pageOnizleme, pageIndices, nakliYekunTutari: nakliTutar),
                    ],
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
      final updateKey = data.$2 as String;
      final maxW = data.$3 as double;
      final lines = data.$4 as int;
      
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

      // Alan genişliği ve satır sayısı
      double maxW;
      int maxLines;
      if (key == 'yaziylaTutar') {
        maxW = 420; maxLines = 3;
      } else if (key == 'numuneAciklama') {
        maxW = 220; maxLines = 1;
      } else if (key == 'melbesKurum') {
        maxW = 245; maxLines = 2;
      } else if (key == 'melbes' || key == 'numuneNo') {
        maxW = key == 'melbes' ? 155 : 140; maxLines = 1;
      } else if (key == 'kdvOrani') {
        maxW = 40; maxLines = 1;
      } else if (key == 'matrah' || key == 'kdv' || key == 'genelToplam' || key.contains('Tutar')) {
        maxW = 80; maxLines = 1;
      } else {
        maxW = 150; maxLines = 2;
      }
      
      final childWidget = Container(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Text(
          finalVal,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: provider.matbuFontBoyutu,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      );

      w.add(Positioned(
        left: adjustedOffset.dx,
        top: adjustedOffset.dy,
        child: _kalibrasyonModu
            ? _suruklenebilirAlan(
                provider: provider,
                alanKey: key,
                child: _metinKutusu(
                  metin: finalVal,
                  fontBoyutu: provider.matbuFontBoyutu,
                  secili: _seciliAlan == key,
                  maxWidth: maxW,
                  kalin: isBold,
                ),
              )
            : childWidget,
      ));
    }); // readOnly.forEach sonu

    return w;
  }

  List<Widget> _buildEkstraNotlar(BatchFaturaProvider provider, var invoice) {
    final w = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (!provider.coordinates.containsKey('ekstraNot_$i')) continue;
      final offset = _konum(provider, 'ekstraNot_$i');
      
      // Sadece kalibrasyon modundaysak boşları göster (sürüklemek için)
      // Normal moddaysak sadece var olan notları göster.
      if (!_kalibrasyonModu && i >= invoice.ekstraNotlar.length) continue;
      
      final val = i < invoice.ekstraNotlar.length ? invoice.ekstraNotlar[i] : '';
      
      w.add(Positioned(
        left: offset.dx,
        top: offset.dy,
        child: _editableField(
          provider,
          'ekstraNot_$i',
          val.isEmpty && _kalibrasyonModu ? FaturaMatbuConfig.ornekMetinler['ekstraNot_$i']! : val,
          (v) {
            if (!_kalibrasyonModu) {
              provider.updateEkstraNot(widget.invoiceIndex, i, v);
            }
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
  /// Index -1 = Nakli Yekün satırı (top veya bottom).
  /// Döndürülen Map: 'pages' → List<List<int>>, 'nakliTutarlar' → List<double> (her sayfa sonundaki kümülatif)
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
           final lastPage = pagesOfIndices.last;
           if (lastPage.isNotEmpty && lastPage.last == -1) {
              lastPage.insert(lastPage.length - 1, currentItemIndex);
           } else {
              lastPage.add(currentItemIndex);
           }
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

  List<Widget> _buildKalemler(BatchFaturaProvider provider, var invoice, KalibrasyonBaskiOnizleme onizleme, List<int> pageIndices, {double nakliYekunTutari = 0.0}) {
    final w = <Widget>[];
    final kalemler = invoice.kalemler;
    if (kalemler.isEmpty) return w;

    final cinsiBase = provider.coordinates['cinsi'];
    if (cinsiBase == null) return w;

    int renderIndex = 0;
    
    for (int i in pageIndices) {
      final satirDy = renderIndex * provider.kalemSatirAraligi;
      final satirTop = cinsiBase.dy + provider.globalOffsetDy + satirDy + 200;
      renderIndex++;
      
      final satirMap = kalemler[i];

      // Cinsi
      if (provider.coordinates.containsKey('cinsi')) {
          w.add(Positioned(
            left: provider.coordinates['cinsi']!.dx + provider.globalOffsetDx + 300,
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
            left: provider.coordinates['miktar']!.dx + provider.globalOffsetDx + 300,
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
            left: provider.coordinates['fiyat']!.dx + provider.globalOffsetDx + 300,
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
           left: provider.coordinates['tutar']!.dx + provider.globalOffsetDx + 300,
           top: satirTop,
           child: _kalibrasyonModu
               ? _suruklenebilirAlan(
                   provider: provider,
                   alanKey: 'tutar',
                   child: _metinKutusu(
                     metin: metin.isEmpty ? 'Tutar' : metin,
                     fontBoyutu: provider.matbuFontBoyutu,
                     secili: _seciliAlan == 'tutar',
                     maxWidth: 70,
                     textAlign: TextAlign.right,
                   ),
                 )
               : Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Container(
                       width: 70,
                       alignment: Alignment.centerRight,
                       child: Text(
                         metin,
                         style: TextStyle(fontSize: provider.matbuFontBoyutu, color: Colors.black87),
                       ),
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
         ));
      }
    }
    return w;
  }

  Offset _konum(BatchFaturaProvider provider, String key) {
    final base = provider.coordinates[key] ?? Offset.zero;
    return Offset(base.dx + provider.globalOffsetDx + 300, base.dy + provider.globalOffsetDy + 200);
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
    if (_kalibrasyonModu) {
      return _suruklenebilirAlan(
        provider: provider,
        alanKey: key,
        child: _metinKutusu(
          metin: initialValue.isEmpty ? (FaturaMatbuConfig.alanEtiketleri[key] ?? key) : initialValue,
          fontBoyutu: fontSize,
          secili: _seciliAlan == key,
          maxWidth: maxWidth,
          textAlign: textAlign,
          tekSatir: maxLines == 1,
        ),
      );
    }
    
    return Container(
      width: maxWidth,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        maxLines: maxLines,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.1,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: secili ? Colors.blue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.92),
        border: Border.all(
          color: secili ? Colors.blue : Colors.red,
          width: secili ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(3),
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
          color: Colors.red.shade700,
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
    if (!_kalibrasyonModu) return child;

    final secili = _seciliAlan == alanKey;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _seciliAlan = alanKey),
      onPanStart: (_) => setState(() { _alanSurukleniyor = true; _seciliAlan = alanKey; }),
      onPanUpdate: (details) {
        provider.calibrationDragDelta(alanKey, details.delta, notify: false);
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
        decoration: BoxDecoration(
          border: secili ? Border.all(color: Colors.blue, width: 2) : Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
          color: secili ? Colors.blue.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
        ),
        child: AbsorbPointer(child: child),
      ),
    );
  }
}
