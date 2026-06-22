import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/theme/app_theme.dart';
import '../../providers/yk_workspace_provider.dart';

class YkAnaKararWorkspace extends StatelessWidget {
  const YkAnaKararWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();
    final controller = workspace.quillControllers[YkWorkspaceProvider.anaKararEditorId];

    if (controller == null) {
      return const Center(
        child: Text(
          'Ana Karar metni birleştiriliyor veya henüz yüklenmedi...',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const Icon(Icons.description, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Text(
                'Birleştirilmiş Ana Yürütme Kurulu Kararı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Word Çıktısı Alınacak (Yapım Aşamasında)')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Word Olarak İndir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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
            ),
          ),
        ),
        
        Expanded(
          child: Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Container(
                width: 800,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(64.0),
                  child: quill.QuillEditor.basic(
                    controller: controller,
                    config: const quill.QuillEditorConfig(
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
