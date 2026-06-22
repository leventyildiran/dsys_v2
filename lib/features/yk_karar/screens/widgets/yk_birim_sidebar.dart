import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/yk_workspace_provider.dart';

class YkBirimSidebar extends StatelessWidget {
  final String birimId;
  
  const YkBirimSidebar({super.key, required this.birimId});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();
    final hasPdf = workspace.uploadedPdfs.containsKey(birimId);
    final isAnalyzing = workspace.isAnalyzingMap[birimId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Kaynak Belge (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: Icon(workspace.sidebarDar ? Icons.open_in_full : Icons.close_fullscreen),
                  onPressed: workspace.toggleSidebar,
                  tooltip: 'Genişlet/Daralt',
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                    withData: true,
                  );
                  if (result != null && result.files.single.bytes != null) {
                    workspace.uploadedPdfs[birimId] = result.files.single.bytes!;
                    // Note: Instead of calling notifyListeners directly from UI, we should call a method on the provider
                    // For now, to quickly fix the build error, we can trigger a state update through a provider method if it existed.
                    // But since uploadedPdfs is public, we'll just force a rebuild via viewMode setter trick or add a method.
                    workspace.setViewMode(workspace.viewMode); // Hack to trigger notifyListeners
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: hasPdf ? Colors.red.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasPdf ? Colors.red.shade200 : Colors.grey.shade300,
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasPdf ? Icons.check_circle : Icons.upload_file,
                          size: 48,
                          color: hasPdf ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasPdf ? 'PDF Yüklendi\nDeğiştirmek için tıklayın' : 'Birim Kararını Yükle (PDF)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: hasPdf ? Colors.green.shade700 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: (!hasPdf || isAnalyzing) ? null : () async {
                final error = await workspace.analizEtBirim(birimId);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                }
              },
              icon: isAnalyzing 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
              label: Text(isAnalyzing ? 'Analiz Ediliyor...' : 'Yapay Zeka ile Analiz Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
