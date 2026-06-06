import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../models/gundem_model.dart';
import '../providers/gundem_provider.dart';
import '../services/gundem_parser_service.dart';
import '../services/belge_uretim_servisi.dart';

/// Toplantı Gündem Derleyici ekranı.
class GundemScreen extends StatefulWidget {
  const GundemScreen({
    super.key,
    this.embedded = false,
    this.onToplantiSecildi,
  });

  /// Dashboard içine embed edildiğinde AppBar gösterilmez.
  final bool embedded;
  final VoidCallback? onToplantiSecildi;

  @override
  State<GundemScreen> createState() => _GundemScreenState();
}

class _GundemScreenState extends State<GundemScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GundemProvider>().toplantilariYukle();
    });
  }

  Future<void> _pdfGundemMaddeleriEkle(
    BuildContext context,
    String toplantiId,
    GundemProvider provider,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    try {
      final parser = GundemParserService();
      // PDF'ten metni çıkar ve gündem maddelerine dönüştür
      final pdfDoc = parser.pdfMetniCikar(bytes);
      final maddeler = parser.metniGundemMaddelerineAyristir(pdfDoc);

      // Ayrıştırılan her maddeyi bu toplantıya ekle
      for (final madde in maddeler) {
        await provider.gundemMaddesiEkle(toplantiId, madde);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${maddeler.length} gündem maddesi PDF\'ten eklendi.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF okuma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<GundemProvider>();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Toplantı Gündem Derleyici'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _yeniToplantiDialog(context),
                  tooltip: 'Yeni Toplantı',
                ),
              ],
            ),
      body: Column(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text('Toplantı Gündem Derleyici',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _yeniToplantiDialog(context),
                    tooltip: 'Yeni Toplantı',
                  ),
                ],
              ),
            ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.toplantilar.isEmpty
                    ? _buildBosEkran(theme)
                    : _buildListe(provider, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBosEkran(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text('Toplantı kaydı bulunamadı.', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildListe(GundemProvider provider, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.toplantilar.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.toplantilar.length) {
          return _buildPaginationFooter(
            onPressed: provider.dahaFazlaYukle,
            isLoading: provider.isLoadingMore,
          );
        }
        final toplanti = provider.toplantilar[index];
        return _buildToplantiKart(toplanti, provider, theme);
      },
    );
  }

  Widget _buildPaginationFooter({
    required Future<void> Function() onPressed,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: () {
                  onPressed();
                },
                icon: const Icon(Icons.expand_more),
                label: const Text('20 kayıt daha yükle'),
              ),
      ),
    );
  }

  Widget _buildToplantiKart(
    ToplantiModel toplanti,
    GundemProvider provider,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          provider.toplantiYukle(toplanti.id);
          if (widget.onToplantiSecildi != null) {
            widget.onToplantiSecildi!();
          } else {
            _gundemDetayDialog(context, toplanti, provider);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toplantı No: ${toplanti.toplantiNo}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(
                      toplanti.durum.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tarih: ${toplanti.toplantiTarihi}',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(),
              Text(
                '${toplanti.gundemMaddeleri.length} gündem maddesi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (toplanti.gundemMaddeleri.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...toplanti.gundemMaddeleri.take(3).map((madde) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '${madde.siraNo}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              madde.baslik,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (toplanti.gundemMaddeleri.length > 3)
                  Text(
                    '... ve ${toplanti.gundemMaddeleri.length - 3} madde daha',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _gundemDetayDialog(
    BuildContext context,
    ToplantiModel toplanti,
    GundemProvider provider,
  ) {
    provider.toplantiYukle(toplanti.id);

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<GundemProvider>(
          builder: (context, gundemProv, child) {
            final guncelToplanti = gundemProv.seciliToplanti ?? toplanti;
            return AlertDialog(
              title: Text('Toplantı ${guncelToplanti.toplantiNo}'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: guncelToplanti.gundemMaddeleri.isEmpty
                    ? const Text('Henüz gündem maddesi eklenmemiş.')
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: guncelToplanti.gundemMaddeleri.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          gundemProv.siraDegistir(guncelToplanti.id, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final madde = guncelToplanti.gundemMaddeleri[index];
                          return ListTile(
                            key: ValueKey('${madde.siraNo}_${madde.baslik}'),
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text(
                                '${madde.siraNo}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(madde.baslik),
                            subtitle: Text(madde.tur.displayName),
                            trailing: const Icon(Icons.drag_handle),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => _pdfGundemMaddeleriEkle(context, guncelToplanti.id, gundemProv),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('PDF\'ten Ekle'),
                ),
                 TextButton(
                  onPressed: () => _yeniMaddeDialog(context, guncelToplanti.id, gundemProv),
                  child: const Text('Madde Ekle'),
                ),
                TextButton(
                  onPressed: () async {
                    await BelgeUretimServisi.toplantiGundemWordIndir(guncelToplanti);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gündem belgesi (Word) indirildi.')),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Word İndir'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _yeniMaddeDialog(
    BuildContext context,
    String toplantiId,
    GundemProvider provider,
  ) {
    final baslikController = TextEditingController();
    final aciklamaController = TextEditingController();
    final birimAdController = TextEditingController();
    GundemTuru seciliTur = GundemTuru.diger;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yeni Gündem Maddesi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baslikController,
                  decoration: const InputDecoration(labelText: 'Gündem Başlığı'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GundemTuru>(
                  value: seciliTur,
                  decoration: const InputDecoration(labelText: 'Gündem Türü'),
                  items: GundemTuru.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => seciliTur = val);
                    }
                  },
                ),
                TextField(
                  controller: birimAdController,
                  decoration: const InputDecoration(labelText: 'Birim Adı (Opsiyonel)', prefixIcon: Icon(Icons.business_rounded)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: aciklamaController,
                  decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (baslikController.text.isEmpty) return;
                final yeniMadde = GundemMaddesi(
                  siraNo: 0,
                  baslik: baslikController.text,
                  tur: seciliTur,
                  aciklama: aciklamaController.text,
                  birimAd: birimAdController.text,
                );
                await provider.gundemMaddesiEkle(toplantiId, yeniMadde);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniToplantiDialog(BuildContext context) {
    final toplantiNoController = TextEditingController();
    final tarihController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Toplantı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toplantiNoController,
              decoration: const InputDecoration(labelText: 'Toplantı No'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tarihController,
              decoration:
                  const InputDecoration(labelText: 'Tarih (dd.MM.yyyy)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final model = ToplantiModel(
                id: '',
                toplantiTarihi: tarihController.text,
                toplantiNo: toplantiNoController.text,
              );
              context.read<GundemProvider>().toplantiOlustur(model);
              Navigator.pop(ctx);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }


}
