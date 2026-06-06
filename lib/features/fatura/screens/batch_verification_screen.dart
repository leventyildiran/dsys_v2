import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/batch_fatura_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'calibration_dialog.dart';
import '../components/firma_secici_dialog.dart';
import '../components/hizmet_secici_dialog.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/models/hizmet_model.dart';

class BatchVerificationScreen extends StatefulWidget {
  const BatchVerificationScreen({super.key});

  @override
  State<BatchVerificationScreen> createState() => _BatchVerificationScreenState();
}

class _BatchVerificationScreenState extends State<BatchVerificationScreen> {
  // Map to keep selected birim (short name) per invoice
  final Map<int, String> _selectedBirim = {};
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Butonlar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_view_rounded, color: AppTheme.white),
                    label: const Text('Excel / Toplu Liste Yükle', style: TextStyle(color: AppTheme.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _uploadExcel(context, provider),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bolt, color: AppTheme.white),
                    label: const Text('Yapay Zeka (Metin) Oku', style: TextStyle(color: AppTheme.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
              ],
            ),
            const SizedBox(height: 24),
            
            if (provider.pendingInvoices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Onay bekleyen fatura bulunmamaktadır.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fatura Kuyruğu (${provider.pendingInvoices.length} Adet)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all, color: Colors.white),
                    label: const Text('Tümünü Onayla / Temizle', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: provider.approveAll,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              ...provider.pendingInvoices.asMap().entries.map((entry) {
                return _buildInvoiceCard(context, provider, entry.value, entry.key);
              }).toList(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, BatchFaturaProvider provider, FaturaModel currentInvoice, int invoiceIndex) {
    Color badgeColor = Colors.grey;
    if (currentInvoice.parsedBy.contains('Tier 1')) badgeColor = Colors.blue;
    if (currentInvoice.parsedBy.contains('Tier 2')) badgeColor = Colors.green;
    if (currentInvoice.parsedBy.contains('Tier 3')) badgeColor = Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ÜST PANEL (FATURA BİLGİLERİ)
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fatura #${invoiceIndex + 1}',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                  onPressed: () => _showFirmaSecici(context, provider, invoiceIndex),
                  icon: const Icon(Icons.business),
                  label: const Text('🏢 Kayıtlı Firmalar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade700,
                    elevation: 0,
                  ),
                ),
                ),
                const SizedBox(height: 12),
                // Birim dropdown (short name)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Birim (Kısa Ad)',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedBirim[invoiceIndex],
                  items: provider.birimlerCache.entries.map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text('${e.value.kisaAd} – ${e.value.ad}'),
                  )).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedBirim[invoiceIndex] = val);
                    provider.applyBirimToInvoice(invoiceIndex, val);
                  },
                ),
                const SizedBox(height: 16),
                // ŞABLON GÖRÜNÜMÜNDE DİZİLİM
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fatura Başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business_center, size: 48, color: Colors.blueGrey.shade300),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FATURA BİLGİLERİ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade800, letterSpacing: 1.5)),
                                  const Text('Lütfen bilgilerin doğruluğunu kontrol ediniz', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(4)),
                            child: const Text('ASIL SURET', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Üst Bölüm: Müşteri Bilgileri ve Tarih/İrsaliye
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sol Taraf: Firma Bilgileri
                          Expanded(
                            flex: 3,
                            child: KeyedSubtree(
                              key: ValueKey('firma_${invoiceIndex}_${provider.dialogUpdateCounter}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField('Firma Adı', currentInvoice.firmaAdi, (v) => provider.updateField(invoiceIndex, 'firmaAdi', v)),
                                  _buildMultiLineTextField('Adres', currentInvoice.adres, (v) => provider.updateField(invoiceIndex, 'adres', v)),
                                  Row(
                                  children: [
                                    Expanded(child: _buildTextField('Vergi Dairesi', currentInvoice.vergiDairesi, (v) => provider.updateField(invoiceIndex, 'vergiDairesi', v))),
                                    const SizedBox(width: 8),
                                    Expanded(child: _buildTextField('VKN', currentInvoice.vergiNo, (v) => provider.updateField(invoiceIndex, 'vergiNo', v))),
                                  ],
                                ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Sağ Taraf: Tarih ve İrsaliye
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildTextField('Tarih', currentInvoice.tarih, (v) => provider.updateField(invoiceIndex, 'tarih', v)),
                                _buildTextField('İrsaliye No', currentInvoice.irsaliyeNo, (v) => provider.updateField(invoiceIndex, 'irsaliyeNo', v)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(thickness: 1),
                      ),
                      
                      // Orta Bölüm: Numune Bilgileri
                      Row(
                        children: [
                          Expanded(child: _buildTextField('MELBES No', currentInvoice.melbesNo, (v) => provider.updateField(invoiceIndex, 'melbesNo', v))),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Numune No', currentInvoice.numuneNo, (v) => provider.updateField(invoiceIndex, 'numuneNo', v))),
                        ],
                      ),
                      // IBAN and Hesap Adı fields (mandatory)
                      _buildTextField('IBAN', currentInvoice.iban ?? '', (v) => provider.updateField(invoiceIndex, 'iban', v)),
                      _buildTextField('Hesap Adı', currentInvoice.hesapAdi ?? '', (v) => provider.updateField(invoiceIndex, 'hesapAdi', v)),
                      _buildMultiLineTextField('Numune Açıklaması', currentInvoice.numuneAciklamasi, (v) => provider.updateField(invoiceIndex, 'numuneAciklamasi', v)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Ayarlar ve Toplamlar Bölümü
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sol Taraf: Ayarlar (Switches)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('KDV Muafiyeti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('KDV sıfırlanır.', style: TextStyle(fontSize: 11)),
                            value: currentInvoice.isKdvMuaf,
                            onChanged: (val) => provider.toggleKdvMuaf(invoiceIndex, val),
                            activeColor: AppTheme.primaryColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          SwitchListTile(
                            title: const Text('Nakli Yekün', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text('Devir yapar.', style: TextStyle(fontSize: 11)),
                            value: provider.isNakliYekunAktif,
                            onChanged: provider.toggleNakliYekunGlobal,
                            activeColor: Colors.deepPurple,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Sağ Taraf: Toplamlar
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField('Matrah', currentInvoice.matrah.toString(), (v) => provider.updateField(invoiceIndex, 'matrah', v)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: DropdownButtonFormField<double>(
                                      value: currentInvoice.kdvOrani.toDouble(),
                                      decoration: InputDecoration(
                                        labelText: 'KDV %',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        fillColor: currentInvoice.isKdvMuaf ? Colors.grey[200] : Colors.white,
                                        filled: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 0.0, child: Text('%0')),
                                        DropdownMenuItem(value: 1.0, child: Text('%1')),
                                        DropdownMenuItem(value: 10.0, child: Text('%10')),
                                        DropdownMenuItem(value: 20.0, child: Text('%20')),
                                      ],
                                      onChanged: currentInvoice.isKdvMuaf ? null : (val) {
                                        if (val != null) provider.updateField(invoiceIndex, 'kdvOrani', val.toInt());
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    'KDV Tutarı', 
                                    currentInvoice.kdvTutari.toStringAsFixed(2), 
                                    (v) => provider.updateField(invoiceIndex, 'kdvTutari', v),
                                    readOnly: currentInvoice.isKdvMuaf,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextField(
                                    'Genel Toplam', 
                                    currentInvoice.genelToplam.toStringAsFixed(2), 
                                    (v) => provider.updateField(invoiceIndex, 'genelToplam', v),
                                    readOnly: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ALT PANEL (KALEMLER)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildKalemlerPanel(context, provider, currentInvoice, invoiceIndex),
          ),
          
          // AKSİYON BUTONLARI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
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
                      icon: Icons.delete_outline,
                      label: 'Sil / İptal Et',
                      color: Colors.red.shade400,
                      onPressed: () => provider.removeInvoice(invoiceIndex),
                      isSecondary: true,
                    ),
                    _buildActionButton(
                      icon: Icons.save_alt,
                      label: 'Kaydet ve Onayla',
                      color: Colors.green.shade600,
                      onPressed: () async {
                        try {
                          await provider.approveInvoice(invoiceIndex);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fatura başarıyla kaydedildi!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
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
    final bool isEmpty = initialValue.trim().isEmpty;
    final Color bgColor = isEmpty ? Colors.red.shade50 : Colors.green.shade50;
    final Color borderColor = isEmpty ? Colors.red.shade200 : Colors.green.shade200;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: initialValue,
        minLines: 2,
        maxLines: 3,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isEmpty ? Colors.red.shade700 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.normal),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isEmpty ? Colors.red : Colors.green, width: 1.5)),
          filled: true,
          fillColor: bgColor,
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
    final bool isEmpty = initialValue.trim().isEmpty;
    final Color bgColor = isEmpty ? Colors.red.shade50 : Colors.green.shade50;
    final Color borderColor = isEmpty ? Colors.red.shade200 : Colors.green.shade200;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        readOnly: readOnly,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isEmpty ? Colors.red.shade700 : Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.normal),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isEmpty ? Colors.red : Colors.green, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          fillColor: readOnly ? Colors.grey[100] : bgColor,
          filled: true,
        ),
      ),
    );
  }

  Widget _buildKalemField(String label, String initialValue, Function(String) onChanged, {bool isNumber = false, bool isDecimal = false}) {
    final bool isEmpty = initialValue.trim().isEmpty || (isNumber && initialValue == '0') || (isDecimal && initialValue == '0.0');
    final Color bgColor = isEmpty ? Colors.red.shade50 : Colors.green.shade50;
    final Color borderColor = isEmpty ? Colors.red.shade200 : Colors.green.shade200;
    
    TextInputType type = TextInputType.text;
    if (isNumber) type = TextInputType.number;
    if (isDecimal) type = const TextInputType.numberWithOptions(decimal: true);

    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: type,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isEmpty ? Colors.red.shade700 : Colors.green.shade700, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isEmpty ? Colors.red : Colors.green, width: 1.5)),
        filled: true,
        fillColor: bgColor,
      ),
    );
  }

  Widget _buildKalemlerPanel(BuildContext context, BatchFaturaProvider provider, FaturaModel invoice, int invoiceIndex) {
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
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showHizmetSecici(context, provider, invoiceIndex),
                      icon: const Icon(Icons.post_add, size: 18),
                      label: const Text('📋 Birim Fiyat Listesi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade50,
                        foregroundColor: Colors.teal.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => provider.addKalem(invoiceIndex),
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
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoice.kalemler.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final kalem = invoice.kalemler[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: KeyedSubtree(
                  key: ValueKey('kalem_${invoiceIndex}_${index}_${provider.dialogUpdateCounter}'),
                  child: Row(
                    children: [
                      Expanded(
                      flex: 4,
                      child: _buildKalemField('Hizmet / Ürün', kalem['cinsi']?.toString() ?? '', (val) => provider.updateKalem(invoiceIndex, index, 'cinsi', val)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildKalemField('Adet', kalem['miktar']?.toString() ?? '1', (val) {
                          final miktar = int.tryParse(val) ?? 0;
                          provider.updateKalem(invoiceIndex, index, 'miktar', miktar);
                        }, isNumber: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildKalemField('Fiyat', kalem['fiyat']?.toString() ?? '0.0', (val) {
                          final fiyat = double.tryParse(val) ?? 0.0;
                          provider.updateKalem(invoiceIndex, index, 'fiyat', fiyat);
                        }, isDecimal: true),
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
                      onPressed: () => provider.removeKalem(invoiceIndex, index),
                      tooltip: 'Kalemi Sil',
                    ),
                  ],
                ),
                ),
              );
            },
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

  Future<void> _showFirmaSecici(BuildContext context, BatchFaturaProvider provider, int invoiceIndex) async {
    final secilenFirma = await showDialog<FirmaModel>(
      context: context,
      builder: (context) => const FirmaSeciciDialog(),
    );

    if (secilenFirma != null) {
      provider.updateField(invoiceIndex, 'firmaAdi', secilenFirma.firmaAdi);
      provider.updateField(invoiceIndex, 'adres', secilenFirma.adres);
      provider.updateField(invoiceIndex, 'vergiDairesi', secilenFirma.vergiDairesi);
      provider.updateField(invoiceIndex, 'vergiNo', secilenFirma.vergiNo);
      provider.notifyDialogReturn();
    }
  }

  Future<void> _showHizmetSecici(BuildContext context, BatchFaturaProvider provider, int invoiceIndex) async {
    final secilenHizmet = await showDialog<HizmetModel>(
      context: context,
      builder: (context) => const HizmetSeciciDialog(),
    );

    if (secilenHizmet != null) {
      // Find an empty or placeholder kalem, or just add a new one
      final currentInvoice = provider.pendingInvoices[invoiceIndex];
      // Check if there's an empty kalem
      final emptyIndex = currentInvoice.kalemler.indexWhere((k) => k['cinsi'] == null || k['cinsi'].toString().isEmpty);
      
      if (emptyIndex != -1) {
        provider.updateKalem(invoiceIndex, emptyIndex, 'cinsi', secilenHizmet.hizmetAdi);
        provider.updateKalem(invoiceIndex, emptyIndex, 'miktar', 1);
        provider.updateKalem(invoiceIndex, emptyIndex, 'fiyat', secilenHizmet.fiyat);
      } else {
        provider.addKalem(invoiceIndex);
        final newIndex = currentInvoice.kalemler.length - 1;
        provider.updateKalem(invoiceIndex, newIndex, 'cinsi', secilenHizmet.hizmetAdi);
        provider.updateKalem(invoiceIndex, newIndex, 'miktar', 1);
        provider.updateKalem(invoiceIndex, newIndex, 'fiyat', secilenHizmet.fiyat);
      }
      provider.notifyDialogReturn();
    }
  }

  Future<void> _uploadExcel(BuildContext context, BatchFaturaProvider provider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('Excel analiz ediliyor ve faturalar oluşturuluyor... Lütfen bekleyin.')),
                ],
              ),
            ),
          );

          await provider.loadExcelFile(file.bytes!, file.name);

          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Excel başarıyla işlendi: \${provider.pendingInvoices.length} fatura bulundu.'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: \$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
