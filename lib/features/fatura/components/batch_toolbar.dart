import 'package:flutter/material.dart';
import '../providers/batch_fatura_provider.dart';
import '../../../core/theme/app_theme.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
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
                  'Toplu Fatura Do rulama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Y klenen faturalar n do rulu unu kontrol edip onaylay n.',
                  style: TextStyle(
                    color: Colors.indigo.shade100,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Matbu mod',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Switch(
                    value: provider.matbuBaskiModu,
                    activeThumbColor: Colors.lightGreenAccent,
                    onChanged: (v) {
                      provider.setMatbuBaskiModu(v);
                      provider.saveMatbuAyarlari();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBar(BuildContext context) {
    final tiles = [
      _uploadTile(
        icon: Icons.upload_file_rounded,
        title: 'Evrak Y kle',
        subtitle: 'PDF, Excel, CSV veya TXT',
        color: Colors.indigo,
        onTap: onUploadDocument,
      ),
      _uploadTile(
        icon: Icons.table_view_rounded,
        title: 'Excel / Toplu Liste',
        subtitle: 'Sadece Excel veya CSV',
        color: Colors.green.shade700,
        onTap: onUploadExcel,
      ),
      _uploadTile(
        icon: Icons.edit_note,
        title: 'Manuel Fatura',
        subtitle: 'Bo  fatura ekle',
        color: Colors.blueGrey.shade700,
        onTap: onAddBlankInvoice,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                tiles[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _uploadTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Text(
          'Kuyruk: \$count fatura',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          key: const ValueKey('toplu_yazdir_btn'),
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Toplu Yazd r'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepOrange.shade700,
          ),
          onPressed: count > 0 ? onBatchPreview : null,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const ValueKey('fatura_arsiv_dialog_ac'),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Fatura Ar ivi'),
          onPressed: onSearchArchive,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Toplu Temizle'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: onClearQueue,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Evrak Y kle'),
          onPressed: onUploadDocument,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('Metin Yap t r'),
          onPressed: onRawText,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const ValueKey('fatura_tumunu_onayla'),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('T m n  Onayla'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
          onPressed: onApproveAll,
        ),
      ],
    );
  }
}
