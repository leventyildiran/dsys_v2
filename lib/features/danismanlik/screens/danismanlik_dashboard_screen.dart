import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../services/danismanlik_service.dart';

class DanismanlikDashboardScreen extends StatefulWidget {
  const DanismanlikDashboardScreen({super.key});

  @override
  State<DanismanlikDashboardScreen> createState() => _DanismanlikDashboardScreenState();
}

class _DanismanlikDashboardScreenState extends State<DanismanlikDashboardScreen> {
  String _searchQuery = '';
  DanismanlikDurum? _selectedDurum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 4),
            blurRadius: 12,
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danışmanlık Takibi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey.shade900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Döner Sermaye kapsamında yürütülen hizmetlerin zengin veri görünümü.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/danismanlik/yeni');
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Yeni Danışmanlık Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), // Indigo 500
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final service = DanismanlikService();

    return StreamBuilder<List<DanismanlikModel>>(
      stream: service.streamAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final items = snapshot.data ?? [];
        
        // Stats
        final totalTutar = items.fold<double>(0, (sum, item) => sum + item.toplamTutar);
        final countBekliyor = items.where((e) => e.durum == DanismanlikDurum.bekliyor).length;
        final countAktif = items.where((e) => e.durum == DanismanlikDurum.aktif).length;
        final countTamamlandi = items.where((e) => e.durum == DanismanlikDurum.tamamlandi).length;

        // Filter & Search
        var filteredItems = items.where((e) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = (e.firmaUnvan?.toLowerCase().contains(query) ?? false) ||
                                (e.konusu.toLowerCase().contains(query));
          final matchesDurum = _selectedDurum == null || e.durum == _selectedDurum;
          return matchesSearch && matchesDurum;
        }).toList();

        // Sort: newest first
        filteredItems = filteredItems.reversed.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // KPI CARDS
              Row(
                children: [
                  Expanded(child: _buildKpiCard('Toplam Danışmanlık', '${items.length}', TurkceFormat.para(totalTutar), Icons.business_center, Colors.indigo)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildKpiCard('Bekleyen', '$countBekliyor', 'İşlem bekleyen sözleşmeler', Icons.pending_actions, Colors.amber.shade700)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildKpiCard('Aktif (Sözleşmeli)', '$countAktif', 'Devam eden hizmetler', Icons.autorenew, Colors.blue.shade600)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildKpiCard('Tamamlandı', '$countTamamlandi', 'Başarıyla bitenler', Icons.task_alt, Colors.green.shade600)),
                ],
              ),
              
              const SizedBox(height: 32),

              // FILTER BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Firma Adı veya Konu Ara...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<DanismanlikDurum?>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        value: _selectedDurum,
                        hint: const Text('Tüm Durumlar'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tüm Durumlar')),
                          ...DanismanlikDurum.values.map((d) => DropdownMenuItem(value: d, child: Text(d.displayName))),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedDurum = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // DATA GRID (Rich List)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('Firma & Proje Özeti', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Akademisyenler', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Bütçe', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Süre & İlerleme', style: _headerStyle())),
                          Expanded(flex: 1, child: Text('Durum', style: _headerStyle())),
                          SizedBox(width: 100, child: Text('İşlemler', style: _headerStyle(), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    
                    // Table Body
                    if (filteredItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Center(
                          child: Text('Aradığınız kriterlere uygun danışmanlık bulunamadı.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildDataRow(context, item);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.blueGrey.shade700,
      letterSpacing: 0.5,
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, DanismanlikModel model) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.go('/danismanlik/detay/${model.id}');
        },
        hoverColor: Colors.blueGrey.shade50.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Firma & Proje
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.firmaUnvan?.isNotEmpty == true ? model.firmaUnvan! : 'Belirtilmemiş Firma',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.konusu,
                      style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        model.tur.displayName,
                        style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Akademisyenler
              Expanded(
                flex: 2,
                child: model.personeller.isEmpty
                    ? Text('Atanmadı', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: model.personeller.take(2).map((p) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(p.personel.adSoyad.isNotEmpty ? p.personel.adSoyad.substring(0, 1).toUpperCase() : '', style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${p.personel.unvan} ${p.personel.adSoyad}',
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ).toList().cast<Widget>()
                        ..addAll(model.personeller.length > 2 
                          ? [Text('+ ${model.personeller.length - 2} kişi daha', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))]
                          : []),
                      ),
              ),
              
              // Bütçe
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TurkceFormat.para(model.toplamTutar),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+ %${model.kdvOrani} KDV',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              
              // Süre & İlerleme
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${model.suresi} Ay', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    _buildProgressBar(model),
                  ],
                ),
              ),
              
              // Durum
              Expanded(
                flex: 1,
                child: _buildStatusBadge(model.durum),
              ),
              
              // İşlemler
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.table_view, color: Colors.green),
                      tooltip: 'Excel Görünümü',
                      onPressed: () {
                        context.push('/danismanlik/dagitim', extra: model);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onPressed: () {
                        context.go('/danismanlik/detay/${model.id}');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DanismanlikDurum durum) {
    Color bgColor;
    Color textColor;
    
    switch (durum) {
      case DanismanlikDurum.bekliyor:
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        break;
      case DanismanlikDurum.aktif:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      case DanismanlikDurum.tamamlandi:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case DanismanlikDurum.iptal:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        durum.displayName,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProgressBar(DanismanlikModel model) {
    if (model.baslangicTarihi == null) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    final start = model.baslangicTarihi!;
    final end = model.bitisTarihi ?? start.add(Duration(days: model.suresi * 30));
    final now = DateTime.now();
    
    final totalDuration = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays;
    
    double progress = 0;
    if (totalDuration > 0) {
      progress = elapsed / totalDuration;
      progress = progress.clamp(0.0, 1.0);
    }

    Color progressColor = Colors.blue;
    if (progress > 0.8) progressColor = Colors.orange;
    if (progress >= 1.0) progressColor = Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          progress >= 1.0 ? 'Süre Doldu' : '%${(progress * 100).toInt()} Tamamlandı',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
