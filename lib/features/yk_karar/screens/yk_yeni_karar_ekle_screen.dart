import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/yk_workspace_provider.dart';
import '../providers/gundem_provider.dart';
import '../services/belge_uretim_servisi.dart';
import 'widgets/yk_top_bar.dart';
import 'widgets/yk_birim_tab_strip.dart';
import 'widgets/yk_birim_workspace.dart';

class YkYeniKararEkleScreen extends StatelessWidget {
  const YkYeniKararEkleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => YkWorkspaceProvider(),
      child: const _YkYeniKararEkleScreenContent(),
    );
  }
}

class _YkYeniKararEkleScreenContent extends StatefulWidget {
  const _YkYeniKararEkleScreenContent();

  @override
  State<_YkYeniKararEkleScreenContent> createState() => _YkYeniKararEkleScreenContentState();
}

class _YkYeniKararEkleScreenContentState extends State<_YkYeniKararEkleScreenContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gundem = context.read<GundemProvider>();
      await gundem.toplantilariYukle();
      await gundem.aktifToplantiyiYukle();
    });
  }

  void _onAnaKararSelected(BuildContext context) {
    final workspace = context.read<YkWorkspaceProvider>();
    final gundem = context.read<GundemProvider>();
    final toplanti = gundem.seciliToplanti;
    
    if (toplanti == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce toplantı seçin')),
      );
      return;
    }

    final metin = BelgeUretimServisi.anaKararBirlesikMetin(workspace.toplantiKararlari);
    workspace.quillControllers[YkWorkspaceProvider.anaKararEditorId]?.dispose();
    workspace.quillControllers[YkWorkspaceProvider.anaKararEditorId] = workspace.quillFromMetin(metin);
    
    workspace.seciliBirimId = YkWorkspaceProvider.anaKararEditorId;
    workspace.seciliKararId = null;
    workspace.setViewMode(ViewMode.karar);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<YkWorkspaceProvider>();

    if (workspace.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          YkTopBar(
            onYeniToplanti: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yeni Toplantı dialog eklenecek')),
              );
            },
          ),
          YkBirimTabStrip(
            onAnaKararSelected: () => _onAnaKararSelected(context),
          ),
          const Expanded(
            child: YkBirimWorkspace(),
          ),
        ],
      ),
    );
  }
}
