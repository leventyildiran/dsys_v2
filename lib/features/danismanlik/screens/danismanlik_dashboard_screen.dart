import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../services/danismanlik_service.dart';

class DanismanlikDashboardScreen extends StatelessWidget {
  const DanismanlikDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200)),
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Döner Sermaye kapsamında yürütülen danışmanlık hizmetleri.',
                style: TextStyle(
                  fontSize: 14,
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
            label: const Text('Yeni Danışmanlık Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1), // Indigo 500
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      stream: service.streamAll(), // TODO: Replace with active user's birim
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata oluştu: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // Kanban Style Columns
        final bekliyor = items.where((e) => e.durum == DanismanlikDurum.bekliyor).toList();
        final aktif = items.where((e) => e.durum == DanismanlikDurum.aktif).toList();
        final tamamlandi = items.where((e) => e.durum == DanismanlikDurum.tamamlandi).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKanbanColumn('Bekliyor', bekliyor, Colors.amber),
              const SizedBox(width: 24),
              _buildKanbanColumn('Aktif (Sözleşmeli)', aktif, Colors.blue),
              const SizedBox(width: 24),
              _buildKanbanColumn('Tamamlandı', tamamlandi, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(String title, List<DanismanlikModel> items, MaterialColor color) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildKanbanCard(context, items[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(BuildContext context, DanismanlikModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.danismanlikTuru.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade600,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'aktif', child: Text('Aktife Al')),
                  const PopupMenuItem(value: 'tamamlandi', child: Text('Tamamlandı İşaretle')),
                  const PopupMenuItem(value: 'iptal', child: Text('İptal Et')),
                  const PopupMenuItem(value: 'sil', child: Text('Sil', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (value) async {
                  final service = DanismanlikService();
                  if (value == 'sil') {
                    await service.delete(model.id);
                  } else {
                    await service.updateDurum(model.id, DanismanlikDurum.fromString(value));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            model.firmaUnvan ?? 'Bilinmeyen Firma',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            model.konusu,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blueGrey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: Colors.blueGrey.shade400),
              const SizedBox(width: 4),
              Text(
                TurkceFormat.para(model.toplamTutar),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.blueGrey.shade400),
              const SizedBox(width: 4),
              Text(
                '${model.suresi} Ay',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_outlined, size: 64, color: Colors.blueGrey.shade300),
          const SizedBox(height: 16),
          Text(
            'Henüz Danışmanlık Kaydı Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir danışmanlık hizmeti başlatmak için sağ üstteki butonu kullanın.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
