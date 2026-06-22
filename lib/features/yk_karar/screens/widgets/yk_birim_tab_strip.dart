import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/yk_workspace_provider.dart';
import '../../providers/gundem_provider.dart';

class YkBirimTabStrip extends StatelessWidget {
  final VoidCallback onAnaKararSelected;
  
  const YkBirimTabStrip({super.key, required this.onAnaKararSelected});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();
    final gundem = context.watch<GundemProvider>();
    final toplanti = gundem.seciliToplanti;
    
    if (toplanti == null || workspace.birimler.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: workspace.birimler.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAnaKarar = workspace.seciliBirimId == YkWorkspaceProvider.anaKararEditorId;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
              child: ElevatedButton.icon(
                onPressed: onAnaKararSelected,
                icon: const Icon(Icons.file_copy, size: 18),
                label: const Text('Ana Kararı Birleştir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAnaKarar ? AppTheme.primaryColor : Colors.white,
                  foregroundColor: isAnaKarar ? Colors.white : AppTheme.primaryColor,
                  elevation: 0,
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            );
          }
          
          final birim = workspace.birimler[index - 1];
          final isSelected = workspace.seciliBirimId == birim.id;
          final isCompleted = workspace.kayitliKararIdleri.containsKey(birim.id);
          
          return GestureDetector(
            onTap: () {
              workspace.seciliBirimId = birim.id;
              workspace.seciliKararId = workspace.kayitliKararIdleri[birim.id];
              // Hack to trigger UI update.
              workspace.setViewMode(workspace.viewMode);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    color: isCompleted ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    birim.ad,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
}
