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
  int _sayfaNo = 1;
  bool _kalibrasyonModu = false;
  String? _seciliAlan;
  bool _alanSurukleniyor = false;
  bool _arkaPlanGoster = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    if (widget.invoiceIndex < 0 || widget.invoiceIndex >= provider.pendingInvoices.length) {
      return const Scaffold(body: Center(child: Text('Fatura bulunamadı')));
    }

    final invoice = provider.pendingInvoices[widget.invoiceIndex];
    
    final satirLimit = provider.satirLimit;
    final gercekKalemler = FaturaMatbuConfig.matbuKalemleri(invoice.kalemler);
    
    // YENİ NAKLİ YEKÜN MANTIĞI İLE TOPLAM SAYFA HESABI
    int currentItemIndex = 0;
    int computedToplamSayfa = 0;
    
    while (currentItemIndex < gercekKalemler.length || computedToplamSayfa == 0) {
      int spaceLeft = satirLimit;
      if (computedToplamSayfa > 0 && invoice.nakliYekunAktif) {
        spaceLeft--; // Nakli yekün satırı
      }
      
      while (spaceLeft > 0 && currentItemIndex < gercekKalemler.length) {
        currentItemIndex++;
        spaceLeft--;
      }
      computedToplamSayfa++;
    }
    
    final toplamSayfa = computedToplamSayfa;
    
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
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: List.generate(toplamSayfa, (index) {
                          final sNo = index + 1;
                          final onizleme = provider.kalibrasyonBaskiOnizlemesi(sNo);
                          
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
                                
                                // Alanlar
                                ..._buildSabitAlanlar(provider, invoice, onizleme),
                                
                                // Ekstra Notlar
                                ..._buildEkstraNotlar(provider, invoice),

                                // Kalemler
                                ..._buildKalemler(provider, invoice, onizleme, sNo, satirLimit),
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

  List<Widget> _buildSabitAlanlar(BatchFaturaProvider provider, var invoice, KalibrasyonBaskiOnizleme onizleme) {
    final w = <Widget>[];
    
    // Düzenlenebilir alanlar haritası: key -> (value, updateFieldKey, maxWidth, maxLines)
    final editables = {
      'firmaAdi': (invoice.firmaAdi, 'firmaAdi', 270.0, 2),
      'adres': (invoice.adres, 'adres', 270.0, 3),
      'vergiDairesi': (invoice.vergiDairesi, 'vergiDairesi', 150.0, 1),
      'vkn': (invoice.vergiNo, 'vergiNo', 150.0, 1),
      'tarih': (invoice.tarih, 'tarih', 100.0, 1),
      'irsaliyeTarihi': (invoice.irsaliyeTarihi, 'irsaliyeTarihi', 100.0, 1),
      'irsaliyeNo': (invoice.irsaliyeNo, 'irsaliyeNo', 100.0, 1),
      'iban': (invoice.iban ?? '', 'iban', 250.0, 1),
      'hesapAdi': (invoice.hesapAdi ?? '', 'hesapAdi', 250.0, 2),
      'numuneAciklama': (onizleme.alanlar['numuneAciklama'] ?? '', 'numuneAciklamasi', 350.0, 1),
      'melbes': (onizleme.alanlar['melbes'] ?? '', 'melbesTam', 320.0, 1),
      'numuneNo': (onizleme.alanlar['numuneNo'] ?? '', 'numuneNo', 320.0, 1),
    };

    editables.forEach((key, data) {
      if (!provider.coordinates.containsKey(key) || FaturaMatbuKalibrasyon.gizliAlanlar.contains(key)) return;
      
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
          (v) => provider.updateField(widget.invoiceIndex, updateKey, v),
          provider.matbuFontBoyutu,
          maxWidth: maxW,
          maxLines: lines,
        ),
      ));
    });

    // Sadece Okunur Alanlar (Hesaplananlar)
    final readOnly = {
      'matrah': onizleme.alanlar['matrah'],
      'kdv': onizleme.alanlar['kdv'],
      'kdvOrani': onizleme.alanlar['kdvOrani'],
      'genelToplam': onizleme.alanlar['genelToplam'],
      'yaziylaTutar': onizleme.alanlar['yaziylaTutar'],
    };

    readOnly.forEach((key, val) {
      String? finalVal = val;

      if (_kalibrasyonModu) {
        // Kalibrasyon modunda: tüm alanları placeholder ile göster (sürükleyip konumlandırabilsin)
        if (finalVal == null || finalVal.isEmpty) {
          finalVal = FaturaMatbuConfig.ornekMetinler[key] 
              ?? FaturaMatbuConfig.alanEtiketleri[key] 
              ?? key;
        }
      }

      if (finalVal == null || finalVal.isEmpty || !provider.coordinates.containsKey(key)) return;
      final offset = _konum(provider, key);
      Offset adjustedOffset = offset;
      if (key == 'genelToplam' && invoice.nakliYekunAktif) {
        adjustedOffset = Offset(offset.dx, offset.dy + 30);
      }
      final isBold = key.toLowerCase().contains('toplam') || key.toLowerCase().contains('yekun');

      // Alan genişliği ve satır sayısı
      double maxW;
      int maxLines;
      if (key == 'yaziylaTutar') {
        maxW = 420; maxLines = 3;
      } else if (key == 'numuneAciklama') {
        maxW = 350; maxLines = 1;
      } else if (key == 'melbes' || key == 'numuneNo') {
        maxW = 320; maxLines = 1;
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
          maxWidth: 300,
          maxLines: 2,
          hint: 'Özel Not $i',
        ),
      ));
    }
    return w;
  }

  List<Widget> _buildKalemler(BatchFaturaProvider provider, var invoice, KalibrasyonBaskiOnizleme onizleme, int sayfaNo, int satirLimit) {
    final w = <Widget>[];
    final kalemler = invoice.kalemler;
    if (kalemler.isEmpty) return w;

    final cinsiBase = provider.coordinates['cinsi'];
    if (cinsiBase == null) return w;

    // YENİ NAKLİ YEKÜN MANTIĞI İLE SAYFAYI BÖL
    final List<List<int>> pagesOfIndices = [];
    int currentItemIndex = 0;
    
    while (currentItemIndex < kalemler.length || pagesOfIndices.isEmpty) {
      int spaceLeft = satirLimit;
      final List<int> currentPageIndices = [];
      
      if (pagesOfIndices.isNotEmpty && invoice.nakliYekunAktif) {
        currentPageIndices.add(-1); // -1 means Nakli Yekün row
        spaceLeft--;
      }

      while (spaceLeft > 0 && currentItemIndex < kalemler.length) {
        currentPageIndices.add(currentItemIndex);
        currentItemIndex++;
        spaceLeft--;
      }
      pagesOfIndices.add(currentPageIndices);
    }

    final sIndex = (sayfaNo - 1).clamp(0, pagesOfIndices.length - 1);
    final pageIndices = pagesOfIndices[sIndex];

    int renderIndex = 0;
    for (int i in pageIndices) {
      final satirDy = renderIndex * provider.kalemSatirAraligi;
      final satirTop = cinsiBase.dy + provider.globalOffsetDy + satirDy + 200;
      final kalemIndexOnizleme = renderIndex;
      renderIndex++;
      
      if (i == -1) {
        // NAKLİ YEKÜN SATIRI
        Widget buildReadOnly(String key, String text, double maxW, bool bold, TextAlign align) {
          final childWidget = Container(
            width: maxW,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              border: Border(bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1)),
            ),
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              text,
              maxLines: 1,
              textAlign: align,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: provider.matbuFontBoyutu,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          );
          
          return Positioned(
            left: provider.coordinates[key]!.dx + provider.globalOffsetDx + 300,
            top: satirTop,
            child: _kalibrasyonModu
                ? _suruklenebilirAlan(
                    provider: provider,
                    alanKey: key,
                    child: _metinKutusu(
                      metin: text,
                      fontBoyutu: provider.matbuFontBoyutu,
                      secili: _seciliAlan == key,
                      maxWidth: maxW,
                      kalin: bold,
                      textAlign: align,
                    ),
                  )
                : childWidget,
          );
        }

        final satirOnizleme = onizleme.kalemler[kalemIndexOnizleme];

        if (provider.coordinates.containsKey('cinsi')) w.add(buildReadOnly('cinsi', satirOnizleme.cinsi, 255, true, TextAlign.left));
        if (provider.coordinates.containsKey('miktar')) w.add(buildReadOnly('miktar', satirOnizleme.miktar, 50, false, TextAlign.center));
        if (provider.coordinates.containsKey('fiyat')) w.add(buildReadOnly('fiyat', satirOnizleme.fiyat, 80, false, TextAlign.left));
        if (provider.coordinates.containsKey('tutar')) w.add(buildReadOnly('tutar', satirOnizleme.tutar, 80, false, TextAlign.left));
        
        continue;
      }

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
