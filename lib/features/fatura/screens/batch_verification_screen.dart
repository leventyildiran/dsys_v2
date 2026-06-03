import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../providers/batch_fatura_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'calibration_dialog.dart';

class BatchVerificationScreen extends StatefulWidget {
  const BatchVerificationScreen({super.key});

  @override
  State<BatchVerificationScreen> createState() => _BatchVerificationScreenState();
}

class _BatchVerificationScreenState extends State<BatchVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();

    if (provider.pendingInvoices.isEmpty) {
      return const Center(
        child: Text('Onay bekleyen fatura bulunmamaktadır.', style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    final currentInvoice = provider.pendingInvoices[provider.currentIndex];

    Color badgeColor = Colors.grey;
    if (currentInvoice.parsedBy.contains('Tier 1')) badgeColor = Colors.blue;
    if (currentInvoice.parsedBy.contains('Tier 2')) badgeColor = Colors.green;
    if (currentInvoice.parsedBy.contains('Tier 3')) badgeColor = Colors.purple;

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL PANEL
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YZ Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt, color: AppTheme.white),
                label: const Text('⚡ Yapay Zeka ile Ham Veri Oku', style: TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _showRawTextDialog(context, provider);
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  provider.pendingInvoices.length > 1 || currentInvoice.parsedBy != 'Yeni Fatura' 
                    ? 'Fatura Kuyruğu: ${provider.currentIndex + 1} / ${provider.pendingInvoices.length}'
                    : 'Yeni Klasik Fatura',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    currentInvoice.parsedBy,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTextField('Firma Adı', currentInvoice.firmaAdi, (v) => provider.updateField('firmaAdi', v)),
                    _buildTextField('VKN', currentInvoice.vergiNo, (v) => provider.updateField('vergiNo', v)),
                    _buildTextField('MELBES No', currentInvoice.melbesNo, (v) => provider.updateField('melbesNo', v)),
                    _buildTextField('Numune No', currentInvoice.numuneNo, (v) => provider.updateField('numuneNo', v)),
                    _buildMultiLineTextField('Numune Açıklaması', currentInvoice.numuneAciklamasi, (v) => provider.updateField('numuneAciklamasi', v)),
                    SwitchListTile(
                      title: const Text('KDV Muafiyeti Uygula', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Açıldığında KDV sıfırlanır ve KDV kutusu kilitlenir.', style: TextStyle(fontSize: 12)),
                      value: currentInvoice.isKdvMuaf,
                      onChanged: provider.toggleKdvMuaf,
                      activeColor: AppTheme.primaryColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField('Matrah', currentInvoice.matrah.toString(), (v) => provider.updateField('matrah', v)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<int>(
                              value: currentInvoice.kdvOrani,
                              decoration: InputDecoration(
                                labelText: 'KDV %',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                fillColor: currentInvoice.isKdvMuaf ? Colors.grey[200] : Colors.white,
                                filled: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('%0')),
                                DropdownMenuItem(value: 1, child: Text('%1')),
                                DropdownMenuItem(value: 10, child: Text('%10')),
                                DropdownMenuItem(value: 20, child: Text('%20')),
                              ],
                              onChanged: currentInvoice.isKdvMuaf ? null : (val) {
                                if (val != null) provider.updateField('kdvOrani', val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      'KDV Tutarı', 
                      currentInvoice.kdvTutari.toStringAsFixed(2), 
                      (v) => provider.updateField('kdvTutari', v),
                      readOnly: currentInvoice.isKdvMuaf,
                    ),
                    _buildTextField('Genel Toplam', currentInvoice.genelToplam.toStringAsFixed(2), (v) => provider.updateField('genelToplam', v)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildActionButton(
                        icon: Icons.picture_as_pdf,
                        label: 'Önizle',
                        color: Colors.orange.shade700,
                        onPressed: () => _showPdfPreviewDialog(context, provider, currentInvoice),
                        isSecondary: true,
                      ),
                      _buildActionButton(
                        icon: Icons.settings,
                        label: 'Ayarlar',
                        color: Colors.blueGrey,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const FaturaCalibrationDialog(),
                          );
                        },
                        isSecondary: true,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildActionButton(
                        icon: Icons.check,
                        label: 'Onayla',
                        color: AppTheme.primaryColor,
                        onPressed: provider.approveCurrent,
                      ),
                      _buildActionButton(
                        icon: Icons.done_all,
                        label: 'Tümünü Onayla',
                        color: Colors.green.shade600,
                        onPressed: provider.approveAll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 24),
      // SAĞ PANEL (KALEMLER)
      Expanded(
        flex: 1,
        child: _buildKalemlerPanel(context, provider, currentInvoice),
      ),
    ],
  ),
);
  }

  void _showPdfPreviewDialog(BuildContext context, BatchFaturaProvider provider, FaturaModel invoice) {
    showDialog(
      context: context,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.95;
        final width = MediaQuery.of(context).size.width * 0.85;
        
        return Dialog(
          insetPadding: const EdgeInsets.all(16.0),
          child: Container(
            height: height,
            width: width,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    build: (format) => provider.generatePdf(invoice),
                    allowSharing: true,
                    allowPrinting: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kapat', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, color: AppTheme.white),
                      label: const Text('İndir', style: TextStyle(color: AppTheme.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        final pdfBytes = await provider.generatePdf(invoice);
                        await Printing.sharePdf(bytes: pdfBytes, filename: 'fatura_${invoice.numuneNo}.pdf');
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: AppTheme.white),
                      label: const Text('✔ Yazdır / Onayla', style: TextStyle(color: AppTheme.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        provider.approveCurrent();
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiLineTextField(String label, String initialValue, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: initialValue,
        minLines: 2,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppTheme.backgroundColor,
        ),
        onChanged: onChanged,
      ),
    );
  }

  void _showRawTextDialog(BuildContext context, BatchFaturaProvider provider) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Fatura Metnini Yapıştırın'),
              content: SizedBox(
                width: 600,
                child: TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'PDF içerisinden kopyaladığınız veya elinizdeki ham fatura metnini buraya yapıştırın...',
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (controller.text.trim().isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await provider.loadBatch(controller.text);
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
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Yapay Zeka ile Analiz Et'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildTextField(String label, String initialValue, Function(String) onChanged, {bool readOnly = false}) {
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
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
          filled: true,
        ),
      ),
    );
  }

  Widget _buildKalemlerPanel(BuildContext context, BatchFaturaProvider provider, FaturaModel invoice) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Fatura Kalemleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: provider.addKalem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: invoice.kalemler.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final kalem = invoice.kalemler[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          initialValue: kalem['cinsi']?.toString() ?? '',
                          decoration: const InputDecoration(labelText: 'Hizmet / Ürün', isDense: true),
                          onChanged: (val) => provider.updateKalem(index, 'cinsi', val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          initialValue: kalem['miktar']?.toString() ?? '1',
                          decoration: const InputDecoration(labelText: 'Adet', isDense: true),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final miktar = int.tryParse(val) ?? 0;
                            provider.updateKalem(index, 'miktar', miktar);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: kalem['fiyat']?.toString() ?? '0.0',
                          decoration: const InputDecoration(labelText: 'Fiyat', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final fiyat = double.tryParse(val) ?? 0.0;
                            provider.updateKalem(index, 'fiyat', fiyat);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 80,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${((kalem['miktar'] ?? 1) * (kalem['fiyat'] ?? 0)).toStringAsFixed(2)} ₺',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => provider.removeKalem(index),
                        tooltip: 'Kalemi Sil',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final textStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    if (isSecondary) {
      return OutlinedButton.icon(
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: textStyle.copyWith(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          shape: shape,
          padding: padding,
        ),
        onPressed: onPressed,
      );
    }

    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: textStyle.copyWith(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: shape,
        padding: padding,
        elevation: 0,
      ),
      onPressed: onPressed,
    );
  }
}
