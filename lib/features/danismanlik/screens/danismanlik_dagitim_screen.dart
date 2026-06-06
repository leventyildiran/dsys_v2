import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../models/dagitim_model.dart';
import '../services/danismanlik_hesaplama_servisi.dart';
import '../providers/danismanlik_detay_provider.dart';

class DanismanlikDagitimScreen extends StatefulWidget {
  final DanismanlikModel danismanlik;

  const DanismanlikDagitimScreen({super.key, required this.danismanlik});

  @override
  State<DanismanlikDagitimScreen> createState() => _DanismanlikDagitimScreenState();
}

class _DanismanlikDagitimScreenState extends State<DanismanlikDagitimScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Örnek Dummy Veri (Test İçin)
  List<DagitimModel> _personelListesi = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _personelListesi = _getOrnekVeri();
    _hesapla();
  }

  void _hesapla() {
    setState(() {
      _personelListesi = DanismanlikHesaplamaServisi.hesaplaDagitimListesi(
        _personelListesi,
        widget.danismanlik.toplamTutar,
      );
    });
  }

  List<DagitimModel> _getOrnekVeri() {
    return [
      DagitimModel(
        personelId: '1',
        adSoyad: 'Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL',
        unvan: 'Öğr.Gör.Dr.',
        unvanKatsayisi: 2.0,
        ekGosterge: 160,
        faaliyetTuru: 'Tasarım',
        faaliyetAdeti: 5,
        faaliyetTabanPuani: 20,
        mesaiIci: true,
        toplamPuan: 0,
        bireyselPuan: 0,
        brutHakedis: 0,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // EBYS Gri arkaplanı
      appBar: AppBar(
        title: Text('${widget.danismanlik.firmaUnvan ?? 'Firma'} - Kurum İçi Danışmanlık Gelir Dağıtımı'),
        backgroundColor: Colors.blue.shade800, // EBYS Mavi Kurumsal Renk
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Ana İçerik
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol Ana Panel (Sekmeler ve İçerik)
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Tab Bar (İçerik, Ekler, İlgili Evrak vs tarzı)
                        Container(
                          color: Colors.blue.shade50,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Colors.blue.shade800,
                            unselectedLabelColor: Colors.blueGrey,
                            indicatorColor: Colors.blue.shade800,
                            indicatorWeight: 3,
                            tabs: const [
                              Tab(text: 'Kesintiler ve Formüller'),
                              Tab(text: 'Personel Hakediş (Excel Tablosu)'),
                            ],
                          ),
                        ),
                        // Tab Content
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildKesintilerTab(),
                              _buildPersonelTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sağ Özet Paneli (Diğer)
                Container(
                  width: 320,
                  margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.blue.shade700,
                        width: double.infinity,
                        child: const Text('Diğer (Mali Özet)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildMaliOzetPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // YZ Entegrasyonu buraya gelecek
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Yapay Zeka ile Karar Oku (Otomatik Doldur)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Vazgeç'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Kaydet
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet ve Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKesintilerTab() {
    double matrah = widget.danismanlik.toplamTutar;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Döner Sermaye Yasal Kesintileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const Divider(),
        _buildInfoRow('KDV Hariç Fatura Tutarı (Matrah)', TurkceFormat.para(matrah), isBold: true),
        const SizedBox(height: 16),
        _buildInfoRow('Hazine Payı (%1)', TurkceFormat.para(matrah * 0.01)),
        _buildInfoRow('BAP Payı (%5)', TurkceFormat.para(matrah * 0.05)),
        _buildInfoRow('Araç Gereç Payı (%45)', TurkceFormat.para(matrah * 0.45)),
        const Divider(),
        _buildInfoRow('Dağıtılacak Maksimum Akademik Pay (%49)', TurkceFormat.para(matrah * 0.49), isBold: true, color: Colors.green.shade700),
        
        const SizedBox(height: 32),
        const Text('Sistem Parametreleri ve Katsayılar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const Divider(),
        _buildInfoRow('Memur Maaş Katsayısı', DanismanlikHesaplamaServisi.memurMaasKatsayisi.toString()),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: const Text('Tavan Ücret Limiti Kuralı: Mesai içi saatlik baz ücretin en fazla 2 katı, mesai dışı ise %60 artırımlı hali olan 3.2 katı ödenebilir. Sistemi aşan tutarlar döner sermayeye kalır.', style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }

  Widget _buildPersonelTab() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
            columns: const [
              DataColumn(label: Text('Adı Soyadı', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Unvanı', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Faaliyet', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Puanı', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Miktar (Saat/Adet)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Mesai Durumu', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Brüt Hakediş', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Limit Kontrolü', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Net Ödenecek', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _personelListesi.map((p) {
              return DataRow(
                cells: [
                  DataCell(Text(p.adSoyad)),
                  DataCell(Text(p.unvan)),
                  DataCell(Text(p.faaliyetTuru)),
                  DataCell(Text(p.faaliyetTabanPuani.toString())),
                  DataCell(Text(p.faaliyetAdeti.toString())),
                  DataCell(Text(p.mesaiIci ? 'Mesai İçi' : 'Mesai Dışı')),
                  DataCell(Text(TurkceFormat.para(p.brutHakedis))),
                  DataCell(
                    p.tavanKontrol
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('Aşıldı (Kalan: ${TurkceFormat.para(p.fazlalikHavuzTutari ?? 0)})', style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                          )
                        : const Text('Uygun', style: TextStyle(color: Colors.green)),
                  ),
                  DataCell(Text(TurkceFormat.para(p.odenebilirHakedis ?? p.brutHakedis), style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMaliOzetPanel() {
    double matrah = widget.danismanlik.toplamTutar;
    double maksPay = matrah * 0.49;
    
    double toplamDagitilanNet = 0;
    double toplamHavuzaKalanFazlalik = 0;

    for (var p in _personelListesi) {
      toplamDagitilanNet += (p.odenebilirHakedis ?? p.brutHakedis);
      toplamHavuzaKalanFazlalik += (p.fazlalikHavuzTutari ?? 0);
    }

    double kullanilmayanHavuz = maksPay - (toplamDagitilanNet + toplamHavuzaKalanFazlalik);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOzetRow('Fatura Matrahı', TurkceFormat.para(matrah)),
        const SizedBox(height: 16),
        _buildOzetRow('Döner Sermaye Payları', TurkceFormat.para(matrah * 0.51), color: Colors.blueGrey),
        _buildOzetRow('Dağıtılacak Maksimum Pay', TurkceFormat.para(maksPay), isBold: true),
        const Divider(height: 32),
        const Text('Havuz Kullanımı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        _buildOzetRow('Personele Net Ödenen', TurkceFormat.para(toplamDagitilanNet), color: Colors.green.shade700, isBold: true),
        _buildOzetRow('Limitten Havuza Aktarılan', TurkceFormat.para(toplamHavuzaKalanFazlalik), color: Colors.orange.shade700),
        const Divider(),
        _buildOzetRow('Kullanılmayan Bakiye', TurkceFormat.para(kullanilmayanHavuz), color: kullanilmayanHavuz < 0 ? Colors.red : Colors.blueGrey),
        
        const SizedBox(height: 32),
        const Text('Bilgi Notu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        const Text(
          'Hesaplamalar YÖK Döner Sermaye Mevzuatına ve ilgili EYDMA tablolarına göre otomatik yapılır.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.blueGrey.shade700)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87, fontSize: isBold ? 16 : 14)),
        ],
      ),
    );
  }

  Widget _buildOzetRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.blueGrey.shade800)),
        ],
      ),
    );
  }
}
