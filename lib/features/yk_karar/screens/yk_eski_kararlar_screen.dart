import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/gundem_model.dart';
import '../models/yk_karar_model.dart';
import '../providers/gundem_provider.dart';
import '../services/yk_karar_service.dart';
import '../services/belge_uretim_servisi.dart';

class YkEskiKararlarScreen extends StatefulWidget {
  const YkEskiKararlarScreen({super.key});

  @override
  State<YkEskiKararlarScreen> createState() => _YkEskiKararlarScreenState();
}

class _YkEskiKararlarScreenState extends State<YkEskiKararlarScreen> {
  String? _selectedYear;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GundemProvider>().toplantilariYukle();
    });
  }

  List<String> _getAvailableYears(List<ToplantiModel> toplantilar) {
    final years = toplantilar.map((t) {
      if (t.toplantiTarihi.length >= 4) {
        final parts = t.toplantiTarihi.split('.');
        if (parts.length == 3) return parts[2];
      }
      return DateTime.now().year.toString();
    }).toSet().toList();
    
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  void _showToplantiDetaylari(BuildContext context, ToplantiModel toplanti) {
    showDialog(
      context: context,
      builder: (ctx) => _ToplantiDetayDialog(toplanti: toplanti),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GundemProvider>();
    final toplantilar = provider.toplantilar;
    
    final availableYears = _getAvailableYears(toplantilar);
    if (_selectedYear == null && availableYears.isNotEmpty) {
      _selectedYear = availableYears.first;
    }

    final filteredToplantilar = toplantilar.where((t) {
      if (_selectedYear == null) return true;
      return t.toplantiTarihi.contains(_selectedYear!);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Eski Yürütme Kurulu Kararları', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text('Yıla Göre Filtrele:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedYear,
                    underline: const SizedBox(),
                    items: availableYears.map((year) => DropdownMenuItem(value: year, child: Text(year))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedYear = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: provider.isLoading 
                ? const Center(child: CircularProgressIndicator())
                : filteredToplantilar.isEmpty
                  ? const Center(child: Text('Bu yıla ait karar bulunamadı.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      itemCount: filteredToplantilar.length,
                      itemBuilder: (context, index) {
                        final toplanti = filteredToplantilar[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: const Icon(Icons.event_note, color: AppTheme.primaryColor),
                            ),
                            title: Text('Toplantı No: ${toplanti.toplantiNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('Tarih: ${toplanti.toplantiTarihi} • Durum: ${toplanti.durum.displayName}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _showToplantiDetaylari(context, toplanti),
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('Görüntüle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                elevation: 0,
                                side: const BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                            onTap: () => _showToplantiDetaylari(context, toplanti),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToplantiDetayDialog extends StatefulWidget {
  final ToplantiModel toplanti;
  
  const _ToplantiDetayDialog({required this.toplanti});

  @override
  State<_ToplantiDetayDialog> createState() => _ToplantiDetayDialogState();
}

class _ToplantiDetayDialogState extends State<_ToplantiDetayDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<YkKararModel> _kararlar = [];
  bool _isLoadingKararlar = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadKararlar();
  }

  Future<void> _loadKararlar() async {
    try {
      final kararlar = await YkKararService().kararGetByToplanti(widget.toplanti.id);
      if (mounted) {
        setState(() {
          _kararlar = kararlar;
          _isLoadingKararlar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingKararlar = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Toplantı No: ${widget.toplanti.toplantiNo}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Tarih: ${widget.toplanti.toplantiTarihi}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Gündem Maddeleri', icon: Icon(Icons.list_alt)),
                Tab(text: 'Alınan Kararlar', icon: Icon(Icons.gavel)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGundemTab(),
                  _buildKararTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGundemTab() {
    if (widget.toplanti.gundemMaddeleri.isEmpty) {
      return const Center(child: Text('Gündem maddesi bulunamadı.', style: TextStyle(color: Colors.grey)));
    }
    
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: widget.toplanti.gundemMaddeleri.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final madde = widget.toplanti.gundemMaddeleri[index];
              return ListTile(
                leading: CircleAvatar(child: Text(madde.siraNo.toString())),
                title: Text(madde.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Tür: ${madde.tur.displayName}', style: const TextStyle(color: Colors.blue)),
                    if (madde.birimAd != null && madde.birimAd!.isNotEmpty) Text('Birim: ${madde.birimAd}'),
                    if (madde.aciklama != null && madde.aciklama!.isNotEmpty) Text('Açıklama: ${madde.aciklama}'),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () async {
                await BelgeUretimServisi.toplantiGundemWordIndir(widget.toplanti);
              },
              icon: const Icon(Icons.download),
              label: const Text('Gündemi Word Olarak İndir'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKararTab() {
    if (_isLoadingKararlar) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_kararlar.isEmpty) {
      return const Center(child: Text('Bu toplantıya ait alınmış karar bulunamadı.', style: TextStyle(color: Colors.grey)));
    }
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _kararlar.length,
            itemBuilder: (context, index) {
              final karar = _kararlar[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(karar.baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      const SizedBox(height: 8),
                      Text('Birim: ${karar.birimAd}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(karar.kararMetni, maxLines: 4, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await BelgeUretimServisi.kararWordIndir(karar);
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Kararı Word Olarak İndir'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () async {
                await BelgeUretimServisi.topluKararWordIndir(_kararlar, widget.toplanti.toplantiNo);
              },
              icon: const Icon(Icons.download),
              label: const Text('Tüm Kararları Tek Belgede İndir'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
