import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/danismanlik_layout.dart';
import '../widgets/hesaplama_masalari_kolon_grubu.dart';
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
  String? _selectedBirim;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DanismanlikLayout.kompaktBaslik(
            baslik: 'Danışmanlık & Gelir Dağıtım Merkezi',
            altBaslik: 'Resmi Excel Dağıtım Masaları · Sözleşme ve Taksit Takibi',
            aksiyon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/danismanlik/takip'),
                  icon: const Icon(Icons.timeline, size: 16),
                  label: const Text('Ödeme Takibi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.go('/danismanlik/yeni'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Sözleşme'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
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

        // Collect all distinct birim names for filter
        final distinctBirimler = items
            .map((e) => e.birimKisaAd?.trim())
            .where((b) => b != null && b.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()..sort();

        // Filter & Search
        var filteredItems = items.where((e) {
          final query = _searchQuery.toLowerCase().trim();
          final matchesSearch = query.isEmpty ||
              (e.firmaUnvan?.toLowerCase().contains(query) ?? false) ||
              (e.konusu.toLowerCase().contains(query)) ||
              (e.birimKisaAd?.toLowerCase().contains(query) ?? false) ||
              (e.birimEvrakSayisi?.toLowerCase().contains(query) ?? false) ||
              (e.birimKararNo?.toLowerCase().contains(query) ?? false) ||
              (e.ykKararNo?.toLowerCase().contains(query) ?? false) ||
              e.personeller.any((p) => p.personel.adSoyad.toLowerCase().contains(query));
          final matchesDurum = _selectedDurum == null || e.durum == _selectedDurum;
          final matchesBirim = _selectedBirim == null || e.birimKisaAd?.trim() == _selectedBirim;
          return matchesSearch && matchesDurum && matchesBirim;
        }).toList();

        // Sort: newest first
        filteredItems = filteredItems.reversed.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(DanismanlikLayout.sayfaPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. RESMİ EXCEL GELİR DAĞITIM MASALARI (KOLON GRUBU)
              const HesaplamaMasalariKolonGrubu(),
              const SizedBox(height: 28),

              // 2. SÖZLEŞMELİ DANIŞMANLIK & TAKSİT TAKİBİ BÖLÜMÜ
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sözleşmeli Danışmanlık ve Taksit Takibi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Kayıtlı sözleşmeler, bağlı birim kararları, tahsilat vadeleri ve faturalama süreçleri',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI CARDS
              Row(
                children: [
                  Expanded(child: _buildKpiCard('Toplam', '${items.length}', TurkceFormat.para(totalTutar), Icons.business_center, Colors.indigo)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Bekleyen', '$countBekliyor', 'Onay bekliyor', Icons.pending_actions, Colors.amber.shade700)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Aktif', '$countAktif', 'Devam ediyor', Icons.autorenew, Colors.blue.shade600)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Tamamlandı', '$countTamamlandi', 'Kapandı', Icons.task_alt, Colors.green.shade600)),
                ],
              ),
              
              const SizedBox(height: 32),

              // FILTER BAR (Pill Design)
              Row(
                children: [
                  // Arama Çubuğu
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: Colors.blueGrey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Firma, Konu, Birim, Evrak No veya Karar No Ara...',
                          hintStyle: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade300),
                          prefixIcon: Icon(Icons.search, color: Colors.blueGrey.shade400, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Bağlı Birim Seçici
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: _selectedBirim != null ? Colors.indigo.shade400 : Colors.blueGrey.shade100,
                        width: _selectedBirim != null ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedBirim,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_outlined, size: 15, color: Colors.blueGrey),
                                SizedBox(width: 6),
                                Text('Tüm Bağlı Birimler'),
                              ],
                            ),
                          ),
                          ...distinctBirimler.map((b) => DropdownMenuItem<String?>(
                            value: b,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_outlined, size: 15, color: Colors.indigo),
                                const SizedBox(width: 6),
                                Text(b),
                              ],
                            ),
                          )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedBirim = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Durum Sekmeleri
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill('Tümü', null, _selectedDurum == null),
                          const SizedBox(width: 8),
                          _buildFilterPill('Bekleyenler', DanismanlikDurum.bekliyor, _selectedDurum == DanismanlikDurum.bekliyor),
                          const SizedBox(width: 8),
                          _buildFilterPill('Aktif', DanismanlikDurum.aktif, _selectedDurum == DanismanlikDurum.aktif),
                          const SizedBox(width: 8),
                          _buildFilterPill('Tamamlanan', DanismanlikDurum.tamamlandi, _selectedDurum == DanismanlikDurum.tamamlandi),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      color: Colors.black.withValues(alpha: 0.02),
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
                          Expanded(flex: 3, child: Text('Firma / Konu & Birim', style: _headerStyle())),
                          Expanded(flex: 3, child: Text('Kurul Kararları & Evrak (BYK / YKK)', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Akademisyenler', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Bütçe (+KDV)', style: _headerStyle())),
                          Expanded(flex: 2, child: Text('Süre & Durum', style: _headerStyle())),
                          SizedBox(width: 90, child: Text('İşlemler', style: _headerStyle(), textAlign: TextAlign.center)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade500, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade900, height: 1.1)),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        onTap: () => context.push('/danismanlik/detay/${model.id}'),
        hoverColor: Colors.blueGrey.shade50.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Firma / Konu & Bağlı Birim
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.firmaUnvan?.isNotEmpty == true ? model.firmaUnvan! : 'Belirtilmemiş Firma',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      model.konusu,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (model.birimKisaAd?.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_outlined, size: 11, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  model.birimKisaAd!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text(
                            model.tur.displayName,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Kurul Kararları & Evrak (BYK / YKK)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BYK (Bağlı Birim Yönetim Kurulu Kararı)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Icon(Icons.description_outlined, size: 12, color: Color(0xFFB45309)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (model.birimKararNo != null && model.birimKararNo!.isNotEmpty)
                                ? 'BYK: ${model.birimKararTarihi?.isNotEmpty == true ? "${model.birimKararTarihi} / " : ""}No: ${model.birimKararNo}'
                                : 'BYK: Karar Bekliyor',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: (model.birimKararNo != null && model.birimKararNo!.isNotEmpty) ? FontWeight.w700 : FontWeight.w500,
                              color: (model.birimKararNo != null && model.birimKararNo!.isNotEmpty)
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (model.birimEvrakSayisi != null && model.birimEvrakSayisi!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          'Evrak: ${model.birimEvrakSayisi}',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    // YKK (Döner Sermaye Yürütme Kurulu Kararı)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: model.ykKararNo?.isNotEmpty == true ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: model.ykKararNo?.isNotEmpty == true ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA),
                            ),
                          ),
                          child: Icon(
                            model.ykKararNo?.isNotEmpty == true ? Icons.gavel : Icons.pending_actions,
                            size: 12,
                            color: model.ykKararNo?.isNotEmpty == true ? const Color(0xFF047857) : const Color(0xFFC2410C),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            model.ykKararNo?.isNotEmpty == true
                                ? 'YKK: ${model.ykKararTarihi?.isNotEmpty == true ? "${model.ykKararTarihi} / " : ""}No: ${model.ykKararNo}'
                                : 'YKK: Onay Bekliyor',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: model.ykKararNo?.isNotEmpty == true
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFC2410C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Akademisyenler
              Expanded(
                flex: 2,
                child: model.personeller.isEmpty
                    ? const Text('Atanmadı', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: model.personeller.take(2).map((p) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: Text(
                                    p.personel.adSoyad.isNotEmpty ? p.personel.adSoyad.substring(0, 1).toUpperCase() : '',
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '${p.personel.unvan} ${p.personel.adSoyad}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ).toList().cast<Widget>()
                        ..addAll(model.personeller.length > 2 
                          ? [Text('+ ${model.personeller.length - 2} kişi daha', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))]
                          : []),
                      ),
              ),

              // 4. Bütçe
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TurkceFormat.para(model.toplamTutar),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+ %${model.kdvOrani} KDV',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // 5. Süre & Durum
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${model.suresi} Ay', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B))),
                        const Spacer(),
                        _buildStatusBadge(model.durum),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _buildProgressBar(model),
                  ],
                ),
              ),

              // 6. İşlemler
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calculate_outlined, color: Color(0xFF107C41), size: 20),
                      tooltip: 'Hesaplama & Dağıtım Masası',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        context.push(
                          '/danismanlik/dagitim',
                          extra: DanismanlikRouteExtra(model: model),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      tooltip: 'Detay Sayfası',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => context.push('/danismanlik/detay/${model.id}'),
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

  Widget _buildFilterPill(String label, DanismanlikDurum? durum, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDurum = durum;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.indigo.shade600 : Colors.blueGrey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.blueGrey.shade600,
          ),
        ),
      ),
    );
  }
}
