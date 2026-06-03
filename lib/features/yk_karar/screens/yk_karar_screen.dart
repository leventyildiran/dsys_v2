import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../models/toplanti_model.dart';
import '../models/yk_karar_model.dart';
import '../providers/yk_karar_provider.dart';
import '../services/belge_uretim_servisi.dart';

/// YK Karar Merkezi Ana Ekranı (v2).
///
/// Tam ekran layout (ortadan bölme YOK):
/// - Üstte: Toplantı Seçici + AI Parse Butonu
/// - Ortada: Aktif kararın formu (karar metni + birim bilgileri + tablo düzenleyici)
/// - Altta: Kompakt aksiyon butonları
class YkKararScreen extends StatelessWidget {
  const YkKararScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => YkKararProvider()..loadToplantilar(),
      child: const _YkKararContent(),
    );
  }
}

class _YkKararContent extends StatelessWidget {
  const _YkKararContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YkKararProvider>();

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════
          // ÜST BAR: Toplantı Seçici + Aksiyon Butonları
          // ═══════════════════════════════════════════════════
          _buildTopBar(context, provider),

          // ═══════════════════════════════════════════════════
          // ANA İÇERİK
          // ═══════════════════════════════════════════════════
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.aktifToplanti == null
                    ? _buildEmptyState(context, provider)
                    : _buildKararContent(context, provider),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // ÜST BAR
  // ─────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, YkKararProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Başlık
          const Icon(Icons.gavel, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 10),
          const Text(
            'YK Karar Merkezi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 24),

          // Toplantı Dropdown
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.aktifToplanti?.id,
                  hint: Text(
                    'Toplantı Seçin...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  items: provider.toplantilar.map((t) {
                    return DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(
                        '${t.toplantiNo} — ${t.toplantiTarihi} (${t.durum.displayName})',
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final toplanti = provider.toplantilar.firstWhere((t) => t.id == id);
                    provider.selectToplanti(toplanti);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Yeni Toplantı Butonu
          _buildCompactButton(
            icon: Icons.add,
            label: 'Yeni Toplantı',
            color: AppTheme.primaryColor,
            onPressed: () => _showYeniToplantiDialog(context, provider),
          ),
          const SizedBox(width: 8),

          // AI ile Parse Et Butonu
          _buildCompactButton(
            icon: Icons.auto_awesome,
            label: 'AI ile Oku',
            color: Colors.deepPurple,
            onPressed: provider.aktifToplanti == null
                ? null
                : () => _showAIParseDialog(context, provider),
            isLoading: provider.isParsing,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // BOŞ DURUM (Toplantı seçilmemiş)
  // ─────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, YkKararProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Yürütme Kurulu Karar Merkezi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.toplantilar.isEmpty
                ? 'Henüz toplantı oluşturulmamış. "Yeni Toplantı" butonuyla başlayın.'
                : 'Yukarıdaki açılır menüden bir toplantı seçin veya yeni toplantı oluşturun.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // KARAR İÇERİĞİ (Tam ekran form)
  // ─────────────────────────────────────────────────────

  Widget _buildKararContent(BuildContext context, YkKararProvider provider) {
    if (provider.kararlar.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Bu toplantıda henüz karar yok.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactButton(
                  icon: Icons.auto_awesome,
                  label: 'AI ile Belge Oku',
                  color: Colors.deepPurple,
                  onPressed: () => _showAIParseDialog(context, provider),
                ),
                const SizedBox(width: 12),
                _buildCompactButton(
                  icon: Icons.add,
                  label: 'Manuel Karar Ekle',
                  color: AppTheme.primaryColor,
                  onPressed: provider.addManuelKarar,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final karar = provider.aktifKarar!;

    return Column(
      children: [
        // Karar Navigasyonu (1/5 gibi)
        _buildKararNavigator(provider),

        // Ana Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Karar Başlık Alanı
                _buildSectionCard(
                  title: 'Karar Bilgileri',
                  icon: Icons.description,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildField('Karar No', karar.kararNo, readOnly: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildDropdown(
                            'Karar Türü',
                            karar.tur,
                            YkKararTuru.values,
                            (val) => provider.updateKararField('tur', val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildField('Birim Adı', karar.birimAd,
                              onChanged: (v) => provider.updateKararField('birimAd', v)),
                        ),
                      ],
                    ),
                    _buildField('Karar Başlığı', karar.baslik,
                        onChanged: (v) => provider.updateKararField('baslik', v)),
                  ],
                ),
                const SizedBox(height: 16),

                // Birim Evrak Bilgileri
                _buildSectionCard(
                  title: 'Birim Evrak Bilgileri',
                  icon: Icons.folder_open,
                  collapsible: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildField('Evrak Tarihi', karar.birimEvrakTarihi,
                              onChanged: (v) => provider.updateKararField('birimEvrakTarihi', v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField('Evrak Sayısı', karar.birimEvrakSayisi,
                              onChanged: (v) => provider.updateKararField('birimEvrakSayisi', v)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField('Kurul Tarihi', karar.birimKurulTarihi,
                              onChanged: (v) => provider.updateKararField('birimKurulTarihi', v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField('Toplantı Sayısı', karar.birimToplantiSayi,
                              onChanged: (v) => provider.updateKararField('birimToplantiSayi', v)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField('Karar No', karar.birimKararNo,
                              onChanged: (v) => provider.updateKararField('birimKararNo', v)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Karar Metni
                _buildSectionCard(
                  title: 'Karar Metni',
                  icon: Icons.edit_document,
                  children: [
                    TextFormField(
                      initialValue: karar.kararMetni,
                      onChanged: (v) => provider.updateKararField('kararMetni', v),
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Karar metnini buraya yazın veya AI ile otomatik oluşturun...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tablo Düzenleyici (eğer tablo verisi varsa)
                if (karar.tabloVerileri.isNotEmpty)
                  _buildTabloEditor(context, provider, karar),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Alt Aksiyon Bar
        _buildBottomActionBar(context, provider),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // KARAR NAVİGASYONU (Faturadaki batch navigator gibi)
  // ─────────────────────────────────────────────────────

  Widget _buildKararNavigator(YkKararProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.aktifKararIndex > 0
                ? () => provider.selectKarar(provider.aktifKararIndex - 1)
                : null,
            iconSize: 20,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Karar ${provider.aktifKararIndex + 1} / ${provider.kararlar.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.aktifKararIndex < provider.kararlar.length - 1
                ? () => provider.selectKarar(provider.aktifKararIndex + 1)
                : null,
            iconSize: 20,
          ),
          const Spacer(),
          _buildCompactButton(
            icon: Icons.add,
            label: 'Yeni Karar',
            color: AppTheme.primaryColor,
            onPressed: provider.addManuelKarar,
            isSecondary: true,
          ),
          const SizedBox(width: 8),
          _buildCompactButton(
            icon: Icons.delete_outline,
            label: 'Sil',
            color: Colors.red,
            onPressed: provider.aktifKarar != null && provider.aktifKarar!.id.isNotEmpty
                ? () => provider.deleteKarar(provider.aktifKarar!.id)
                : null,
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // TABLO DÜZENLEYİCİ (Yapısal veri tablosu)
  // ─────────────────────────────────────────────────────

  Widget _buildTabloEditor(
      BuildContext context, YkKararProvider provider, YkKararModel karar) {
    if (karar.tabloVerileri.isEmpty) return const SizedBox.shrink();

    // Tablo sütunlarını ilk satırdan al
    final columns = karar.tabloVerileri.first.keys.toList();

    return _buildSectionCard(
      title: 'Faaliyet Cetveli / Veri Tablosu',
      icon: Icons.table_chart,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 42,
            columnSpacing: 20,
            columns: [
              const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ...columns.map((col) => DataColumn(
                    label: Text(
                      _humanReadableColumn(col),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )),
              const DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: List.generate(karar.tabloVerileri.length, (index) {
              final row = karar.tabloVerileri[index];
              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                  ...columns.map((col) => DataCell(
                        IntrinsicWidth(
                          child: TextFormField(
                            initialValue: row[col]?.toString() ?? '',
                            onChanged: (v) {
                              // Sayısal alanları otomatik dönüştür
                              dynamic parsed = v;
                              final numVal = double.tryParse(v.replaceAll(',', '.'));
                              if (numVal != null) parsed = numVal;
                              provider.updateTabloSatiri(index, col, parsed);
                            },
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => provider.removeTabloSatiri(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Satır Ekle', style: TextStyle(fontSize: 13)),
            onPressed: () {
              final emptyRow = <String, dynamic>{};
              for (final col in columns) {
                emptyRow[col] = '';
              }
              provider.addTabloSatiri(emptyRow);
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // ALT AKSİYON BAR
  // ─────────────────────────────────────────────────────

  Widget _buildBottomActionBar(BuildContext context, YkKararProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol: İkincil butonlar
          Wrap(
            spacing: 12,
            children: [
              _buildCompactButton(
                icon: Icons.picture_as_pdf,
                label: 'PDF Önizle',
                color: Colors.orange.shade700,
                onPressed: provider.aktifKarar != null
                    ? () => _showPdfPreviewDialog(context, provider.aktifKarar!)
                    : null,
                isSecondary: true,
              ),
              _buildCompactButton(
                icon: Icons.description,
                label: 'Word İndir',
                color: Colors.blue.shade700,
                onPressed: provider.aktifKarar != null
                    ? () => BelgeUretimServisi.kararWordIndir(provider.aktifKarar!)
                    : null,
                isSecondary: true,
              ),
            ],
          ),
          // Sağ: Ana butonlar
          Wrap(
            spacing: 12,
            children: [
              _buildCompactButton(
                icon: Icons.save,
                label: 'Kaydet',
                color: AppTheme.primaryColor,
                onPressed: provider.saveKarar,
              ),
              _buildCompactButton(
                icon: Icons.done_all,
                label: 'Tümünü Kaydet',
                color: Colors.green.shade600,
                onPressed: provider.saveAllKararlar,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DİALOGLAR
  // ═══════════════════════════════════════════════════════

  void _showYeniToplantiDialog(BuildContext context, YkKararProvider provider) {
    final tarihController = TextEditingController();
    final noController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Toplantı Oluştur'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noController,
                decoration: InputDecoration(
                  labelText: 'Toplantı No',
                  hintText: 'Örn: 2024-15',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tarihController,
                decoration: InputDecoration(
                  labelText: 'Toplantı Tarihi',
                  hintText: 'Örn: 15.05.2026',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (noController.text.trim().isEmpty) return;
              provider.createToplanti(
                toplantiNo: noController.text.trim(),
                toplantiTarihi: tarihController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showAIParseDialog(BuildContext context, YkKararProvider provider) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.deepPurple.shade400),
                  const SizedBox(width: 8),
                  const Text('Belgeyi AI ile Analiz Et'),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Birimden gelen üst yazıyı veya karar belgesini seçin. \nYapay zeka tüm kararları ve tabloları yapısal olarak çıkaracaktır.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    // PDF Yükleme Butonu
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepPurple.shade200, width: 2, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.deepPurple.withOpacity(0.05),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: InkWell(
                        onTap: isLoading ? null : () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );
                          if (result != null && result.files.single.bytes != null) {
                            setState(() => isLoading = true);
                            try {
                              await provider.parsePdfWithAI(result.files.single.bytes!);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (context.mounted) setState(() => isLoading = false);
                            }
                          }
                        },
                        child: Column(
                          children: [
                            Icon(Icons.upload_file, size: 48, color: Colors.deepPurple.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'PDF Dosyası Seç',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('veya metni yapıştırın', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 6,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Belge metnini buraya yapıştırın...',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(isLoading ? 'Analiz Ediliyor...' : 'Metni Analiz Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) return;
                          setState(() => isLoading = true);
                          try {
                            await provider.parseWithAI(controller.text);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => isLoading = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPdfPreviewDialog(BuildContext context, YkKararModel karar) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(32),
          child: Container(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'A4 PDF Önizleme',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => BelgeUretimServisi.kararPdfUret(karar),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // YARDIMCI WIDGET'LAR
  // ═══════════════════════════════════════════════════════

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool collapsible = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    String initialValue, {
    Function(String)? onChanged,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          fillColor: readOnly ? Colors.grey[100] : Colors.white,
          filled: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildDropdown<T extends Enum>(
    String label,
    T currentValue,
    List<T> values,
    Function(T) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        items: values.map((v) {
          final displayName = (v as dynamic).displayName as String;
          return DropdownMenuItem<T>(
            value: v,
            child: Text(displayName, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    final textStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    if (isSecondary) {
      return OutlinedButton.icon(
        icon: Icon(icon, color: onPressed == null ? Colors.grey : color, size: 16),
        label: Text(label, style: textStyle.copyWith(color: onPressed == null ? Colors.grey : color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: (onPressed == null ? Colors.grey : color).withOpacity(0.4)),
          shape: shape,
          padding: padding,
        ),
        onPressed: onPressed,
      );
    }

    return ElevatedButton.icon(
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, color: Colors.white, size: 16),
      label: Text(label, style: textStyle.copyWith(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: shape,
        padding: padding,
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
    );
  }

  String _humanReadableColumn(String col) {
    const map = {
      'adiSoyadi': 'Adı Soyadı',
      'unvan': 'Unvan',
      'puani': 'Puanı',
      'katsayi': 'Katsayı',
      'brutHakedis': 'Brüt Hakediş',
      'kalemAdi': 'Kalem Adı',
      'mevcutButce': 'Mevcut Bütçe',
      'artirilacak': 'Artırılacak',
      'eksiltilecek': 'Eksiltilecek',
      'yeniButce': 'Yeni Bütçe',
      'gorev': 'Görev',
      'katkiPayi': 'Katkı Payı',
      'mesaiDisi': 'Mesai Dışı',
      'toplam': 'Toplam',
      'dersSaati': 'Ders Saati',
      'toplamPuan': 'Toplam Puan',
    };
    return map[col] ?? col;
  }
}
