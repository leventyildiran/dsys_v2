import 'package:flutter/material.dart';
import '../providers/batch_fatura_provider.dart';

class BatchToolbar extends StatelessWidget {
  final BatchFaturaProvider provider;
  final int count;
  final VoidCallback onAddBlankInvoice;
  final VoidCallback onUploadDocument;
  final VoidCallback onUploadExcel;
  final VoidCallback onBatchPreview;
  final VoidCallback onSearchArchive;
  final VoidCallback onRawText;
  final VoidCallback onClearQueue;
  final VoidCallback onApproveAll;

  const BatchToolbar({
    super.key,
    required this.provider,
    required this.count,
    required this.onAddBlankInvoice,
    required this.onUploadDocument,
    required this.onUploadExcel,
    required this.onBatchPreview,
    required this.onSearchArchive,
    required this.onRawText,
    required this.onClearQueue,
    required this.onApproveAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMatbuBanner(),
        const SizedBox(height: 16),
        _buildUploadBar(context),
        const SizedBox(height: 16),
        _buildToolbar(context),
      ],
    );
  }

  Widget _buildMatbuBanner() {
    final isMatbu = provider.matbuBaskiModu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade900.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toplu Fatura Doğrulama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yüklenen faturaların doğruluğunu kontrol edip onaylayın.',
                  style: TextStyle(
                    color: Colors.indigo.shade100,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            message: isMatbu
                ? 'Hazır Matbu Kağıt: Resmi basılı matbu kağıda yazdırılır (çerçeve ve antet basılmaz).'
                : 'Beyaz A4 Kağıt: Boş A4 kağıda çerçeve, logo ve antetle birlikte tam fatura basılır.',
            preferBelow: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Baskı Şablonu Modu',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isMatbu ? 'Resmi Matbu Kağıt' : 'Beyaz A4 (Tam Şablon)',
                        style: TextStyle(
                          color: isMatbu
                              ? Colors.lightGreenAccent
                              : Colors.cyanAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: isMatbu,
                    activeThumbColor: Colors.lightGreenAccent,
                    activeTrackColor: Colors.lightGreen.withValues(alpha: 0.4),
                    onChanged: (v) {
                      provider.setMatbuBaskiModu(v);
                      provider.saveMatbuAyarlari();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        final primaryUploadCard = _buildPrimaryUploadCard();
        final manualInvoiceCard = _buildSecondaryCard(
          icon: Icons.add_circle_outline_rounded,
          title: 'Manuel Fatura',
          subtitle: 'Boş taslak oluştur',
          color: Colors.blueGrey.shade700,
          onTap: onAddBlankInvoice,
        );
        final pasteTextCard = _buildSecondaryCard(
          icon: Icons.content_paste_rounded,
          title: 'Metin / Pano Yapıştır',
          subtitle: 'Kopyalanan metni ayrıştır',
          color: Colors.teal.shade700,
          onTap: onRawText,
        );

        if (isNarrow) {
          return Column(
            children: [
              primaryUploadCard,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: manualInvoiceCard),
                  const SizedBox(width: 12),
                  Expanded(child: pasteTextCard),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: primaryUploadCard),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: manualInvoiceCard),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: pasteTextCard),
          ],
        );
      },
    );
  }

  Widget _buildPrimaryUploadCard() {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onUploadDocument,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200, width: 1.5),
            color: Colors.indigo.shade50.withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Akıllı Evrak & Belge Yükle',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Çoklu Seçim',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PDF, Excel (.xlsx, .xls), CSV veya TXT dosyalarını seçin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.indigo.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.indigo.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: count > 0 ? Colors.indigo.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: count > 0 ? Colors.indigo.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Kuyruk: $count fatura',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      count > 0 ? Colors.indigo.shade900 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          key: const ValueKey('toplu_yazdir_btn'),
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Toplu Yazdır'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepOrange.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: count > 0 ? onBatchPreview : null,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const ValueKey('fatura_arsiv_dialog_ac'),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Fatura Arşivi'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onPressed: onSearchArchive,
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            label: const Text('Kuyruğu Temizle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: onClearQueue,
          ),
        ],
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const ValueKey('fatura_tumunu_onayla'),
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Tümünü Onayla'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: count > 0 ? onApproveAll : null,
        ),
      ],
    );
  }
}
