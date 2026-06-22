import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/theme/app_theme.dart';
import '../../providers/yk_workspace_provider.dart';
import '../../providers/gundem_provider.dart';

class YkBirimEditor extends StatelessWidget {
  final String birimId;
  
  const YkBirimEditor({super.key, required this.birimId});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();
    final isKararMode = workspace.viewMode == ViewMode.karar;
    final controller = isKararMode 
        ? workspace.quillControllers[birimId] 
        : workspace.gundemQuillControllers[birimId];

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _buildTab(context, 'Ana Karar', ViewMode.karar, isKararMode, workspace),
              const SizedBox(width: 16),
              _buildTab(context, 'Gündem Maddesi', ViewMode.gundem, !isKararMode, workspace),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final toplanti = context.read<GundemProvider>().seciliToplanti;
                  if (toplanti == null) return;
                  
                  final success = await workspace.persistKararTaslak(birimId, toplanti);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Başarıyla kaydedildi!'), backgroundColor: Colors.green)
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey.shade50,
          child: quill.QuillSimpleToolbar(
            controller: controller,
            config: const quill.QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: true,
              showClearFormat: false,
              showListNumbers: true,
              showListBullets: true,
            ),
          ),
        ),
        
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(32),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: const quill.QuillEditorConfig(
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(BuildContext context, String title, ViewMode mode, bool isSelected, YkWorkspaceProvider workspace) {
    return GestureDetector(
      onTap: () => workspace.setViewMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
