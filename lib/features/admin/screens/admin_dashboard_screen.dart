import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/models/hizmet_model.dart';
import '../../../core/services/firma_service.dart';
import '../../../core/services/hizmet_service.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider(),
      child: const _AdminDashboardContent(),
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İstatistik Kartları
          Row(
            children: [
              _buildStatCard(
                title: 'Toplam Kurum',
                value: adminProvider.totalInstitutions.toString(),
                icon: Icons.business,
                color: Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                title: 'Aktif Lisans',
                value: adminProvider.activeInstitutions.toString(),
                icon: Icons.verified_user,
                color: Colors.green,
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                title: 'Toplam Kullanıcı',
                value: adminProvider.totalUsers.toString(),
                icon: Icons.people,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Tablo Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kayıtlı Kurumlar (Tenants)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text('Excel Verilerini Yükle (Migration)', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: () => _uploadMigrationData(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          // DataTable
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text('Kurum Adı', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Lisans Bitiş', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Kullanıcı', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: adminProvider.institutions.map((inst) {
                    return DataRow(
                      cells: [
                        DataCell(Text(inst.name)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: inst.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              inst.isActive ? 'Aktif' : 'Pasif',
                              style: TextStyle(
                                color: inst.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(inst.licenseEndDate)),
                        DataCell(Text(inst.userCount.toString())),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.grey),
                            onPressed: () {
                              // TODO: Ayarlar modali
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadMigrationData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Veri yüklemesi başlatıldı...')));
      
      final String firmalarString = await DefaultAssetBundle.of(context).loadString('assets/data/firmalar.json');
      final String hizmetlerString = await DefaultAssetBundle.of(context).loadString('assets/data/hizmetler.json');
      
      final List<dynamic> firmalarJson = jsonDecode(firmalarString);
      final List<dynamic> hizmetlerJson = jsonDecode(hizmetlerString);
      
      final firmaService = FirmaService();
      final hizmetService = HizmetService();

      for (var f in firmalarJson) {
        await firmaService.addFirma(FirmaModel(
          id: '',
          firmaAdi: f['firmaAdi'] ?? '',
          adres: f['adres'] ?? '',
          vergiDairesi: f['vergiDairesi'] ?? '',
          vergiNo: f['vergiNo'] ?? '',
        ));
      }

      for (var h in hizmetlerJson) {
        await hizmetService.addHizmet(HizmetModel(
          id: '',
          birimAdi: h['birimAdi'] ?? '',
          hizmetAdi: h['hizmetAdi'] ?? '',
          fiyat: (h['fiyat'] ?? 0.0).toDouble(),
        ));
      }

      messenger.showSnackBar(const SnackBar(content: Text('Veri yüklemesi BAŞARIYLA tamamlandı!'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }
}
