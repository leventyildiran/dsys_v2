import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../birim/services/birim_service.dart';
import '../../birim/models/birim_model.dart';
import '../models/toplanti_model.dart';
import '../models/yk_karar_model.dart';
import '../providers/yk_karar_provider.dart';
import '../widgets/yk_karar_onizleme_panel.dart';
import '../../../core/theme/app_theme.dart';

class YkEskiKararlarScreen extends StatefulWidget {
  const YkEskiKararlarScreen({super.key});

  @override
  State<YkEskiKararlarScreen> createState() => _YkEskiKararlarScreenState();
}

class _YkEskiKararlarScreenState extends State<YkEskiKararlarScreen> {
  String _searchQuery = '';
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<YkKararProvider>();
      p.loadToplantilar();
      p.loadTumKararlar();
    });
  }

  int _toplantiSortKey(String no) {
    final parts = no.split(RegExp(r'[/\-]'));
    if (parts.length >= 2) {
      final y = int.tryParse(parts[0]) ?? 0;
      final n = int.tryParse(parts[1]) ?? 0;
      return y * 1000 + n;
    }
    return int.tryParse(no.replaceAll(RegExp(r'\D'), '')) ?? 0;
  }

  List<String> _getAvailableYears(List<ToplantiModel> toplantilar) {
    final years = toplantilar.map((t) {
      if (t.toplantiTarihi.length >= 4) {
        final parts = t.toplantiTarihi.split('.');
        if (parts.length == 3) return parts[2];
      }
      if (t.toplantiNo.contains('/')) return t.toplantiNo.split('/').first;
      if (t.olusturmaTarihi != null) return t.olusturmaTarihi!.year.toString();
      return DateTime.now().year.toString();
    }).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  int _kararSayisi(String toplantiId, List<YkKararModel> kararlar) =>
      kararlar.where((k) => k.toplantiId == toplantiId).length;

  List<YkKararModel> _bagimsizKararlar(List<YkKararModel> kararlar) =>
      kararlar.where((k) => k.toplantiId.isEmpty).toList();

  Future<void> _pickAndUploadExternalDecision() async {
    try {
      final birimService = BirimService();
      final birimler = await birimService.stream(onlyActive: false).first;
      if (birimler.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Birim listesi yüklenemedi.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      BirimModel? seciliBirim;
      if (!mounted) return;
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Birim Seçin'),
              content: DropdownButtonFormField<BirimModel>(
                decoration: const InputDecoration(
                  labelText: 'Bu karar hangi birime ait?',
                  border: OutlineInputBorder(),
                ),
                items: birimler
                    .map((b) => DropdownMenuItem(value: b, child: Text(b.ad)))
                    .toList(),
                onChanged: (b) => setDialogState(() => seciliBirim = b),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                ElevatedButton(
                  onPressed: seciliBirim == null ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Devam'),
                ),
              ],
            ),
          );
        },
      );

      if (onay != true || seciliBirim == null) return;

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dosya yükleniyor ve analiz ediliyor...')),
            );
            await context.read<YkKararProvider>().uploadExternalKarar(
                  file.bytes!,
                  file.name,
                  birimId: seciliBirim!.id,
                  birimAd: seciliBirim!.ad,
                );
            await context.read<YkKararProvider>().loadTumKararlar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Karar başarıyla arşive eklendi!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showKararPreview(BuildContext context, YkKararModel karar) {
    ykKararOnizlemeGoster(context, karar);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YkKararProvider>();
    final toplantilar = [...provider.toplantilar]
      ..sort((a, b) => _toplantiSortKey(b.toplantiNo).compareTo(_toplantiSortKey(a.toplantiNo)));
    final tumKararlar = provider.tumKararlar;
    final availableYears = _getAvailableYears(toplantilar);
    final bagimsiz = _bagimsizKararlar(tumKararlar);

    final filteredToplantilar = toplantilar.where((t) {
      if (_selectedYear != null && _selectedYear != 'Tümü') {
        final yilVar = t.toplantiTarihi.contains(_selectedYear!) ||
            t.toplantiNo.startsWith('$_selectedYear/') ||
            (t.olusturmaTarihi?.year.toString() == _selectedYear);
        if (!yilVar) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final kararlar = tumKararlar.where((k) => k.toplantiId == t.id);
        final eslesme = t.toplantiNo.toLowerCase().contains(q) ||
            t.toplantiTarihi.contains(q) ||
            kararlar.any((k) =>
                k.baslik.toLowerCase().contains(q) ||
                k.birimAd.toLowerCase().contains(q));
        if (!eslesme) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'YK Toplantı Arşivi',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: provider.isParsing ? null : _pickAndUploadExternalDecision,
              icon: provider.isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Dış Karar Yükle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Toplantı no, tarih veya birim ara...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Yıl',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      value: _selectedYear ?? 'Tümü',
                      items: ['Tümü', ...availableYears]
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedYear = val == 'Tümü' ? null : val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toplantı numarasına göre sıralı. Satıra tıklayarak gündem PDF\'leri ve toplu kararı görün.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredToplantilar.isEmpty && bagimsiz.isEmpty
                      ? const Center(
                          child: Text('Arşivde toplantı bulunamadı.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView(
                          children: [
                            if (filteredToplantilar.isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredToplantilar.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final t = filteredToplantilar[index];
                                      final kararSayisi = _kararSayisi(t.id, tumKararlar);
                                      return InkWell(
                                        onTap: () => context.push('/yk-karar/eski/${t.id}'),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.event_note, color: AppTheme.primaryColor),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Toplantı ${t.toplantiNo}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${t.toplantiTarihi.isNotEmpty ? t.toplantiTarihi : "Tarih yok"} • $kararSayisi birim kararı • ${t.pdfUrls.length} PDF',
                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Chip(
                                                label: Text(t.durum.displayName, style: const TextStyle(fontSize: 11)),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              const Icon(Icons.chevron_right, color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (bagimsiz.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                'Toplantısız / Dış Arşiv Kararları',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade100),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: bagimsiz.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final karar = bagimsiz[index];
                                    return ListTile(
                                      leading: Icon(Icons.api, color: Colors.orange.shade700),
                                      title: Text(karar.baslik.isEmpty ? karar.kararNo : karar.baslik),
                                      subtitle: Text('${karar.birimAd} • ${karar.kararTarihi}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.visibility),
                                        onPressed: () => _showKararPreview(context, karar),
                                      ),
                                      onTap: () => _showKararPreview(context, karar),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

