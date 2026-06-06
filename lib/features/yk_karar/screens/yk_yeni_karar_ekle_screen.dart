import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../birim/services/birim_service.dart';
import '../../birim/models/birim_model.dart';
import '../models/yk_karar_model.dart';
import '../models/gundem_model.dart';
import '../services/gundem_parser_service.dart';
import '../services/yk_karar_service.dart';
import '../services/belge_uretim_servisi.dart';
import '../components/online_word_editor.dart';
import '../providers/gundem_provider.dart';
import 'gundem_yonetim_screen.dart';

class YkYeniKararEkleScreen extends StatefulWidget {
  const YkYeniKararEkleScreen({super.key});

  @override
  State<YkYeniKararEkleScreen> createState() => _YkYeniKararEkleScreenState();
}

class _YkYeniKararEkleScreenState extends State<YkYeniKararEkleScreen> {
  final BirimService _birimService = BirimService();
  final GundemParserService _parserService = GundemParserService();

  List<BirimModel> _birimler = [];
  bool _isLoading = true;
  
  // Her birim için durumları takip edeceğimiz haritalar
  final Map<String, Uint8List> _uploadedPdfs = {};
  final Map<String, bool> _isAnalyzingMap = {};
  final Map<String, YkKararModel> _analyzedKararlar = {};
  final Map<String, String> _wordContents = {};

  @override
  void initState() {
    super.initState();
    _loadBirimler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GundemProvider>().toplantilariYukle();
    });
  }

  Future<void> _loadBirimler() async {
    try {
      // aktif=true kısıtlamasını kaldırıp hepsini çekiyoruz ki boş gelmesin
      final stream = _birimService.stream(onlyActive: false);
      final list = await stream.first;
      setState(() {
        _birimler = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Birimler yüklenirken hata: $e');
    }
  }

  Future<void> _pickPdfForBirim(String birimId) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _uploadedPdfs[birimId] = result.files.single.bytes!;
      });
    }
  }

  /// Karar modelinden editör için DÜZ METİN üretir.
  /// HTML kullanmıyoruz çünkü HtmlToDelta kütüphanesi karmaşık içeriklerde
  /// sessizce boş döküman üretiyor ve editör boş açılıyor.
  String _generatePlainTextForEditor(YkKararModel karar) {
    final buffer = StringBuffer();
    buffer.writeln(karar.baslik.toUpperCase());
    buffer.writeln('');
    
    // Karar metnindeki tüm HTML etiketlerini temizle (AI bazen HTML üretebilir)
    String temizMetin = karar.kararMetni;
    temizMetin = temizMetin.replaceAll(RegExp(r'<[^>]*>'), ' ');
    temizMetin = temizMetin.replaceAll(RegExp(r'\s+'), ' ').trim();
    temizMetin = temizMetin.replaceAll('\\n', '\n');
    
    buffer.writeln(temizMetin);
    
    if (karar.tabloVerileri.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('TABLO VERİLERİ:');
      final columns = karar.tabloVerileri.first.keys.toList();
      buffer.writeln(columns.join(' | '));
      buffer.writeln('-' * 50);
      
      for (var row in karar.tabloVerileri) {
        final rowValues = columns.map((col) => row[col]?.toString() ?? '').toList();
        buffer.writeln(rowValues.join(' | '));
      }
    }
    return buffer.toString();
  }

  Future<void> _analizEtBirim(String birimId) async {
    final pdfBytes = _uploadedPdfs[birimId];
    if (pdfBytes == null) return;

    setState(() {
      _isAnalyzingMap[birimId] = true;
    });

    try {
      final birim = _birimler.firstWhere((b) => b.id == birimId);
      final karar = await _parserService.analizEtVeKararUret(
        pdfBytes: pdfBytes,
        birimAd: birim.ad,
      );

      setState(() {
        _analyzedKararlar[birimId] = karar;
        _wordContents[birimId] = _generatePlainTextForEditor(karar);
        _isAnalyzingMap[birimId] = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${birim.ad} analizi tamamlandı, önizleme yapabilirsiniz.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isAnalyzingMap[birimId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showOnizlemeDialog(String birimId) {
    final birim = _birimler.firstWhere((b) => b.id == birimId);
    final initialContent = _wordContents[birimId] ?? '';
    
    // Geçici olarak editörden gelen değişikliği tutmak için:
    String editedContent = initialContent;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          height: 700,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              // HEADER
              Container(
                color: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.preview, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('${birim.ad} - Karar Önizleme', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              
              // EDITOR
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    initialValue: initialContent,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Karar metnini buradan düzenleyebilirsiniz...',
                    ),
                    onChanged: (val) {
                      editedContent = val;
                    },
                  ),
                ),
              ),
              
              // FOOTER BUTTONS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Editördeki son hali kaydet (şu an bellekte)
                        _wordContents[birimId] = editedContent;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Taslak olarak kaydedildi.')));
                      },
                      child: const Text('Taslak Olarak Kaydet (Sonra Ekle)'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _kararaEkle(birimId, ctx),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Ana Yürütme Kurulu Kararına Ekle', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kararaEkle(String birimId, BuildContext dialogContext) async {
    final gundemProvider = context.read<GundemProvider>();
    final toplanti = gundemProvider.seciliToplanti;
    
    if (toplanti == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen üst menüden aktif bir toplantı seçin veya yeni oluşturun.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final karar = _analyzedKararlar[birimId];
    if (karar != null) {
      try {
        final newKarar = karar.copyWith(
          toplantiId: toplanti.id,
          toplantiNo: toplanti.toplantiNo,
          kararTarihi: toplanti.toplantiTarihi,
          durum: YkKararDurum.taslak, // veya onaylandı
        );
        
        await YkKararService().kararCreate(newKarar);
        
        if (mounted) {
          Navigator.pop(dialogContext); // Önizleme penceresini kapat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${karar.birimAd} kararı başarıyla ${toplanti.toplantiNo} nolu toplantıya eklendi!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showYeniToplantiDialog() {
    final toplantiNoController = TextEditingController();
    final tarihController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Yürütme Kurulu Kararı / Toplantısı', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lütfen ana toplantı bilgilerini giriniz. Ana word dosyası bu bilgilerle oluşturulacaktır.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: toplantiNoController,
              decoration: const InputDecoration(labelText: 'Toplantı No (Örn: 2026/05)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tarihController,
              decoration: const InputDecoration(labelText: 'Tarih (gg.aa.yyyy)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (toplantiNoController.text.isEmpty || tarihController.text.isEmpty) return;
              
              final model = ToplantiModel(
                id: '',
                toplantiTarihi: tarihController.text,
                toplantiNo: toplantiNoController.text,
              );
              final provider = context.read<GundemProvider>();
              final id = await provider.toplantiOlustur(model);
              if (id != null) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  await provider.toplantiYukle(id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni Toplantı Gündemi başarıyla oluşturuldu!'), backgroundColor: Colors.green));
                  }
                }
              }
            },
            child: const Text('Oluştur ve Seç'),
          ),
        ],
      ),
    );
  }

  void _showToplantiSecici() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const GundemScreen(embedded: true),
              Positioned(right: 8, top: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _anaKarariOnizle(ToplantiModel toplanti) async {
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (kararlar.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu toplantıya henüz hiçbir birim kararı eklenmemiş. Lütfen önce karar ekleyin.'), backgroundColor: Colors.orange));
        return;
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ana Karar Word dosyası oluşturuluyor... Lütfen bekleyin.'), backgroundColor: Colors.blue));
      await BelgeUretimServisi.topluKararWordIndir(kararlar, toplanti.toplantiNo);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Word dosyası oluşturulurken hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _gundemMaddeleriniOlustur(ToplantiModel toplanti) async {
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (kararlar.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gündem oluşturulacak karar bulunamadı. Lütfen karar ekleyin.'), backgroundColor: Colors.orange));
        return;
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gündem maddeleri oluşturuluyor... Lütfen bekleyin.'), backgroundColor: Colors.blue));
      
      final gundemMaddeleri = kararlar.asMap().entries.map((entry) {
        final karar = entry.value;
        return GundemMaddesi(
          siraNo: entry.key + 1,
          baslik: karar.baslik,
          tur: GundemTuru.fromString(karar.tur.value), // Pass string instead of enum
          birimId: karar.birimId,
          birimAd: karar.birimAd,
          iliskiliKayitId: karar.id,
        );
      }).toList();
      
      // Update the meeting in Firestore via Provider
      if (mounted) {
        await context.read<GundemProvider>().toplantiGundemTopluGuncelle(toplanti.id, gundemMaddeleri);
      }
      
      // Refresh toplanti locally to download immediately
      final guncelToplanti = toplanti.copyWith(gundemMaddeleri: gundemMaddeleri);
      
      // Download Word
      await BelgeUretimServisi.toplantiGundemWordIndir(guncelToplanti);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gündem şablonu (Davet) başarıyla oluşturuldu ve indirildi!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gündem oluşturulurken hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final seciliToplanti = context.watch<GundemProvider>().seciliToplanti;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // AppBar tamamen kaldırıldı, butonlar Aktif Toplantı çubuğuna taşındı.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ÜST BAR: AKTİF TOPLANTI VE SEÇİCİ (İşlevsel Lacivert Panel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            color: AppTheme.primaryColor,
            child: Row(
              children: [
                if (seciliToplanti != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 10),
                        Text('Aktif Toplantı: ${seciliToplanti.toplantiNo} (${seciliToplanti.toplantiTarihi})', 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: () => _anaKarariOnizle(seciliToplanti),
                    icon: const Icon(Icons.description, size: 18),
                    label: const Text('Ana Şablonu İndir / Önizle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _gundemMaddeleriniOlustur(seciliToplanti),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Gündemi Oluştur'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade100,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 2,
                    ),
                  ),
                ] else ...[
                  const Text('Henüz bir toplantı seçilmedi.', style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _showToplantiSecici,
                  icon: const Icon(Icons.list, color: Colors.white),
                  label: const Text('Toplantı Değiştir', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showYeniToplantiDialog,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Yeni Karar Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 2,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/yk-karar/eski'),
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('Eski Kararlar', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                ),
              ],
            ),
          ),
          
          // LİSTE: BİRİMLER
          Expanded(
            child: _birimler.isEmpty 
              ? const Center(child: Text('Sistemde kayıtlı birim bulunamadı.', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _birimler.length,
                  itemBuilder: (context, index) {
                    final birim = _birimler[index];
                    final isUploaded = _uploadedPdfs.containsKey(birim.id);
                    final isAnalyzing = _isAnalyzingMap[birim.id] ?? false;
                    final hasAnalysis = _analyzedKararlar.containsKey(birim.id);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              radius: 24,
                              child: const Icon(Icons.account_balance, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(birim.ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(hasAnalysis ? 'Analiz Tamamlandı' : (isUploaded ? 'PDF Yüklendi, Analiz Bekleniyor' : 'PDF Bekleniyor'), 
                                    style: TextStyle(color: hasAnalysis ? Colors.green : (isUploaded ? Colors.orange : Colors.grey))),
                                ],
                              ),
                            ),
                            
                            // AKSİYON BUTONLARI
                            Row(
                              children: [
                                // 1. PDF Yükle
                                ElevatedButton.icon(
                                  onPressed: () => _pickPdfForBirim(birim.id),
                                  icon: Icon(isUploaded ? Icons.edit : Icons.upload_file, size: 18),
                                  label: Text(isUploaded ? 'Değiştir' : 'PDF Yükle'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUploaded ? Colors.grey.shade100 : Colors.white,
                                    foregroundColor: isUploaded ? Colors.black87 : AppTheme.primaryColor,
                                    elevation: 0,
                                    side: BorderSide(color: isUploaded ? Colors.grey.shade300 : AppTheme.primaryColor),
                                  ),
                                ),
                                
                                // 2. Analiz Et (Sadece PDF yüklüyse ve henüz analiz edilmediyse veya tekrar analiz edilecekse)
                                if (isUploaded) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: isAnalyzing ? null : () => _analizEtBirim(birim.id),
                                    icon: isAnalyzing 
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                        : const Icon(Icons.auto_awesome, size: 18),
                                    label: Text(hasAnalysis ? 'Yeniden Analiz Et' : 'Analiz Et'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasAnalysis ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                                
                                // 3. Önizle (Sadece analiz varsa)
                                if (hasAnalysis) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _showOnizlemeDialog(birim.id),
                                    icon: const Icon(Icons.preview, size: 18, color: Colors.white),
                                    label: const Text('Önizle', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
