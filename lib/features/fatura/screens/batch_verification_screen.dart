import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/batch_fatura_provider.dart';
import '../components/batch_invoice_card.dart';
import '../components/batch_toolbar.dart';

import 'fatura_arsiv_arama_dialog.dart';

class BatchVerificationScreen extends StatefulWidget {
  const BatchVerificationScreen({super.key});

  @override
  State<BatchVerificationScreen> createState() =>
      _BatchVerificationScreenState();
}

class _BatchVerificationScreenState extends State<BatchVerificationScreen> {
  final Set<int> _expandedCards = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kontrolYilBasiArsiv();
      _bildirGeriYuklenenKuyruk();
    });
  }

  Future<void> _bildirGeriYuklenenKuyruk() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final adet = context
        .read<BatchFaturaProvider>()
        .consumeGeriYuklemeBildirimi();
    if (adet == null || adet <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Önceki oturumdan $adet fatura taslağı geri yüklendi.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _kontrolYilBasiArsiv() async {
    if (!mounted) return;
    final provider = context.read<BatchFaturaProvider>();
    await provider.yukleArsivDurumu();
    if (!mounted) return;
    if (!await provider.yilBasiTemizlikDialoguGosterilmeli()) return;
    if (!mounted) return;
    _showYilBasiTemizlikDialog(provider);
  }

  Future<void> _showYilBasiTemizlikDialog(BatchFaturaProvider provider) async {
    final uyarisi = provider.arsivUyarisi;
    if (uyarisi == null || !uyarisi.gosterilmeli) return;

    final yilListesi = uyarisi.eskiYillar
        .map((y) => '• ${y.yil}: ${y.adet} fatura')
        .join('\n');

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.archive_outlined,
          color: Colors.orange.shade700,
          size: 36,
        ),
        title: const Text('Geçici arşiv temizliği'),
        content: Text(
          'Yeni yıl başladı. Geçici Firestore arşivinde önceki yıllara ait '
          '${uyarisi.toplamEskiKayit} fatura kaydı var.\n\n'
          'Silmeden önce arşivi bilgisayarınıza indirmeniz önerilir '
          '(ZIP: JSON + Excel CSV).\n\n$yilListesi',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await provider.yilBasiUyarisiErtele();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Daha sonra'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Sadece indir'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final adet = await provider.indirEskiArsivZip();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$adet fatura ZIP olarak indirildi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            icon: const Icon(Icons.download_done, size: 18),
            label: const Text('İndir ve sil'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final onay = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                  title: const Text('Arşivi silmek istediğinize emin misiniz?'),
                  content: const Text(
                    'Önce ZIP indirilecek, ardından eski yıllara ait geçici arşiv '
                    'Firestore\'dan kalıcı olarak silinecek. Bu işlem geri alınamaz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      child: const Text('İndir ve sil'),
                    ),
                  ],
                ),
              );
              if (!ctx.mounted) return;
              if (onay != true) return;
              Navigator.pop(ctx);
              try {
                final sonuc = await provider.indirVeSilEskiArsiv();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${sonuc.indirilen} fatura indirildi, '
                      '${sonuc.silinen} kayıt Firestore\'dan silindi.',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    final gercekKuyruk = provider.pendingInvoices
        .where((f) => !BatchFaturaProvider.yerTutucuMu(f))
        .length;

    final formGoster = provider.pendingInvoices.any(
      (f) => !BatchFaturaProvider.yerTutucuMu(f),
    );

    return Container(
      color: AppTheme.backgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BatchToolbar(
            provider: provider,
            count: gercekKuyruk,
            onAddBlankInvoice: () {
              provider.addBlankInvoice();
              setState(() {
                _expandedCards
                  ..clear()
                  ..add(provider.pendingInvoices.length - 1);
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni manuel fatura kuyruğun sonuna eklendi.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            onUploadDocument: () => _uploadFaturaDocument(context, provider),
            onUploadExcel: () => _uploadExcel(context, provider),
            onBatchPreview: () => _showBatchPreview(context, provider),
            onSearchArchive: () => showFaturaArsivAramaDialog(context),
            onRawText: () => _showRawTextDialog(context, provider),
            onClearQueue: () async {
              final onay = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                  title: const Text('Kuyruk temizlensin mi?'),
                  content: const Text(
                    'Kuyruktaki tüm faturalar silinecek. Bu işlem geri alınamaz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Temizle'),
                    ),
                  ],
                ),
              );
              if (onay != true) return;
              await provider.kuyruguTemizle();
              if (!mounted) return;
              setState(() {
                _expandedCards
                  ..clear()
                  ..add(0);
              });
            },
            onApproveAll: () => _approveAll(context, provider),
          ),
          const SizedBox(height: 12),
          if (!formGoster)
            _buildEmptyState(context, provider)
          else
            ...provider.pendingInvoices
                .asMap()
                .entries
                .where((e) => !BatchFaturaProvider.yerTutucuMu(e.value))
                .map(
                  (e) => BatchInvoiceCard(
                    invoice: e.value,
                    index: e.key,
                    isExpanded: _expandedCards.contains(e.key),
                    onToggle: () {
                      setState(() {
                        if (_expandedCards.contains(e.key)) {
                          _expandedCards.remove(e.key);
                        } else {
                          _expandedCards.add(e.key);
                        }
                      });
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BatchFaturaProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.upload_file, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Başlamak için PDF, Excel, CSV veya TXT dosyası yükleyin\nveya Manuel Fatura kartına tıklayın',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Dosya Seç'),
            onPressed: () => _uploadFaturaDocument(context, provider),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showRawTextDialog(context, provider),
            child: const Text('Metin yapıştırmak istiyorum'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAll(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    final count = provider.pendingInvoices.length;
    if (count == 0) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Tümünü Kaydet ve Onayla'),
          ],
        ),
        content: Text(
          'Kuyruktaki $count faturanın tamamı geçici arşive kaydedilecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            icon: const Icon(Icons.check),
            label: Text('$count Faturayı Kaydet'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;

    // Yükleme göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Faturalar kaydediliyor…')),
          ],
        ),
      ),
    );

    try {
      final sonuc = await provider.approveAll();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Progress dialogu kapat
        final mesaj = '${sonuc.kaydedilen} fatura başarıyla geçici arşive kaydedildi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mesaj),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBatchPreview(BuildContext context, BatchFaturaProvider provider) {
    var arkaPlan = !provider.matbuBaskiModu;
    final gercekFaturalar = provider.pendingInvoices
        .where((f) => !BatchFaturaProvider.yerTutucuMu(f))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.85,
              height: MediaQuery.of(ctx).size.height * 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text(
                          'Toplu PDF Önizleme (${gercekFaturalar.length} Fatura)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        FilterChip(
                          label: const Text('Şablon arka planı'),
                          selected: arkaPlan,
                          onSelected: (v) => setLocal(() => arkaPlan = v),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (format) => provider.generateBatchPdf(
                        gercekFaturalar,
                        includeBackground: arkaPlan,
                      ),
                      allowSharing: true,
                      allowPrinting: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRawTextDialog(BuildContext context, BatchFaturaProvider provider) {
    final controller = TextEditingController();
    var loading = false;

    Future<void> calistir(
      StateSetter setLocal,
      BuildContext ctx,
      bool cevrimdisi,
    ) async {
      if (controller.text.trim().isEmpty) return;
      setLocal(() => loading = true);
      try {
        await provider.loadBatch(controller.text, cevrimdisi: cevrimdisi);
        if (ctx.mounted) Navigator.pop(ctx);
        setState(() => _expandedCards.add(0));
        if (context.mounted && provider.sonAyristirmaBilgisi != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.sonAyristirmaBilgisi!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (ctx.mounted) setLocal(() => loading = false);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Metin yapıştır (isteğe bağlı)'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Dosya seç (PDF, Excel, CSV, TXT)'),
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _uploadFaturaDocument(context, provider);
                        },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'veya metni aşağıya yapıştırın',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        'PDF, e-posta veya Excel metnini buraya yapıştırın…',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'İnternet/AI yoksa "Çevrimdışı" kural tabanlı okur.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.wifi_off, size: 18),
              label: const Text('Çevrimdışı'),
              onPressed: loading ? null : () => calistir(setLocal, ctx, true),
            ),
            FilledButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Sistem Okuma'),
              onPressed: loading ? null : () => calistir(setLocal, ctx, false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadExcel(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    BuildContext? progressDialogContext;
    void closeProgressDialog() {
      final dialogCtx = progressDialogContext;
      if (dialogCtx == null) return;
      if (!dialogCtx.mounted) {
        progressDialogContext = null;
        return;
      }
      Navigator.of(dialogCtx).pop();
      progressDialogContext = null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx', 'csv'],
        withData: true,
      );

      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      
      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null && !kIsWeb && file.path != null) {
        fileBytes = File(file.path!).readAsBytesSync();
      }
      if (fileBytes == null) return;

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          progressDialogContext = dialogCtx;
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Excel analiz ediliyor…')),
              ],
            ),
          );
        },
      );

      await provider.loadExcelFile(fileBytes, file.name);

      if (!context.mounted) return;
      closeProgressDialog();
      setState(() => _expandedCards.add(0));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${provider.pendingInvoices.length} fatura oluşturuldu.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      closeProgressDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadFaturaDocument(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    BuildContext? progressDialogContext;
    void closeProgressDialog() {
      final dialogCtx = progressDialogContext;
      if (dialogCtx == null) return;
      if (!dialogCtx.mounted) {
        progressDialogContext = null;
        return;
      }
      Navigator.of(dialogCtx).pop();
      progressDialogContext = null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'csv', 'xls', 'xlsx'],
        allowMultiple: true,
        withData: true,
      );

      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) return;

      final totalFiles = result.files.length;
      int basariliDosya = 0;
      final baslangicAdet = provider.pendingInvoices
          .where((f) => !BatchFaturaProvider.yerTutucuMu(f))
          .length;
          
      final List<String> errorMessages = [];

      for (var i = 0; i < totalFiles; i++) {
        final file = result.files[i];
        
        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          bytes = File(file.path!).readAsBytesSync();
        }
        if (bytes == null) continue;

        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            progressDialogContext = dialogCtx;
            final isPdf = (file.extension ?? '').toLowerCase() == 'pdf';
            final String progressLabel;
            if (totalFiles > 1) {
              progressLabel = '(${i + 1}/$totalFiles) ${file.name} işleniyor…';
            } else if (isPdf) {
              progressLabel = 'Sistem belgenin tüm sayfalarını inceliyor, lütfen bekleyiniz…';
            } else {
              progressLabel = '${file.name} okunuyor…';
            }
            return AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(child: Text(progressLabel)),
                ],
              ),
            );
          },
        );

        final extension = (file.extension ?? '').toLowerCase();
        final shouldAppend = baslangicAdet > 0 || basariliDosya > 0;

        try {
          if (extension == 'xls' || extension == 'xlsx') {
            await provider.loadExcelFile(bytes, file.name, append: shouldAppend);
          } else {
            final text = await _extractTextFromFile(bytes, extension);
            await provider.loadBatch(
              text,
              pdfBytes: extension == 'pdf' ? bytes : null,
              append: shouldAppend,
            );
          }
          basariliDosya++;
        } catch (e) {
          debugPrint('${file.name} ayrıştırılırken hata: $e');
          errorMessages.add('${file.name}: $e');
        } finally {
          closeProgressDialog();
        }
      }

      if (!context.mounted) return;
      setState(() => _expandedCards.add(0));

      final sonAdet = provider.pendingInvoices
          .where((f) => !BatchFaturaProvider.yerTutucuMu(f))
          .length;
      final yeniEklenen = sonAdet - baslangicAdet;

      if (basariliDosya > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalFiles > 1
                  ? '$basariliDosya dosya başarıyla işlendi (Kuyrukta toplam $sonAdet fatura hazır).'
                  : 'Fatura başarıyla eklendi.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final allErrors = errorMessages.take(3).join('\n'); // En fazla 3 hata göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Geçerli fatura çıkarılamadı.\nHatalar:\n$allErrors',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evrak okunamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _extractTextFromFile(List<int> bytes, String extension) async {
    if (extension == 'pdf') {
      try {
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText().trim();
        document.dispose();
        debugPrint('[_extractTextFromFile] PDF metin katmanı çıkarıldı: ${text.length} karakter');
        return text; // Boş olsa bile dön, taranmışsa boş çıkar ve Vision API devreye girer.
      } catch (e) {
        debugPrint('[_extractTextFromFile] PDF metin çıkarma hatası: $e');
        return ''; // Hata olursa yine boş dön
      }
    }

    if (extension == 'txt' || extension == 'csv') {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) throw Exception('Dosya boş veya metin okunamadı.');
      return text;
    }

    throw Exception('Desteklenmeyen dosya türü: .$extension');
  }
}

/// Kalem fiyat alanı: Türkçe para biçimi + TL soneki; odak kaybı ve "0" takılması olmaz.
