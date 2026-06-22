import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/yk_workspace_provider.dart';
import 'yk_birim_sidebar.dart';
import 'yk_birim_editor.dart';
import 'yk_ana_karar_workspace.dart';

class YkBirimWorkspace extends StatelessWidget {
  const YkBirimWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();
    final birimId = workspace.seciliBirimId;

    if (birimId == null) {
      return const Center(
        child: Text('Lütfen üstteki sekmelerden bir birim seçin veya yeni toplantı başlatın.'),
      );
    }

    if (birimId == YkWorkspaceProvider.anaKararEditorId) {
      return const YkAnaKararWorkspace();
    }

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: workspace.sidebarDar ? 320 : 450,
          child: YkBirimSidebar(birimId: birimId),
        ),
        Expanded(
          child: YkBirimEditor(birimId: birimId),
        ),
      ],
    );
  }
}
