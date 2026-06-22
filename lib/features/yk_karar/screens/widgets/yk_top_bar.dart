import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/gundem_provider.dart';

class YkTopBar extends StatelessWidget {
  final VoidCallback onYeniToplanti;
  
  const YkTopBar({super.key, required this.onYeniToplanti});

  @override
  Widget build(BuildContext context) {
    final gundem = context.watch<GundemProvider>();
    final toplanti = gundem.seciliToplanti;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gavel, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yürütme Kurulu Kararı',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  toplanti != null 
                    ? 'Toplantı No: ${toplanti.toplantiNo} - ${toplanti.toplantiTarihi}'
                    : 'Henüz toplantı seçilmedi',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onYeniToplanti,
            icon: const Icon(Icons.add),
            label: const Text('Yeni Toplantı Başlat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
